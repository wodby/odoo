# Runs inside "odoo shell" for odoo-update. WODBY_ODOO_STEP selects the step:
#   install: set up the administrator after the first installation and record the module checksums;
#   plan:    refresh the module list and print the modules to update as WODBY_UPDATE_MODULES=...;
#   save:    record the module checksums after an update.
# `env` is provided by odoo shell.

import hashlib
import json
import os

from odoo.tools import parse_version

CHECKSUMS_KEY = "wodby.module_checksums"
# Assets are rebuilt by Odoo without a module update, and tests don't affect a running database.
SKIP_DIRS = {"__pycache__", "static", "tests", "node_modules"}


def code_module_dirs():
    """Modules of the application code: those found in addons_path directories outside Odoo's own."""
    app_roots = [os.path.realpath(p) for p in (os.environ.get("APP_ROOT", "/usr/src/app"), "/mnt/extra-addons")]
    modules = {}
    for path in filter(None, os.environ.get("ODOO_ADDONS_PATH", "").split(",")):
        path = os.path.realpath(path)
        if not any(path == root or path.startswith(root + os.sep) for root in app_roots):
            continue
        for name in sorted(os.listdir(path)):
            module_dir = os.path.join(path, name)
            # The first directory in addons_path wins, as in Odoo.
            if name not in modules and os.path.isfile(os.path.join(module_dir, "__manifest__.py")):
                modules[name] = module_dir
    return modules


def checksum(module_dir):
    digest = hashlib.sha256()
    for root, dirs, files in os.walk(module_dir):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(files):
            if name.startswith(".") or name.endswith((".pyc", ".pyo")):
                continue
            path = os.path.join(root, name)
            digest.update(os.path.relpath(path, module_dir).encode() + b"\0")
            with open(path, "rb") as f:
                for chunk in iter(lambda: f.read(1 << 16), b""):
                    digest.update(chunk)
            digest.update(b"\0")
    return digest.hexdigest()


def current_checksums():
    return {name: checksum(path) for name, path in code_module_dirs().items()}


def set_param(key, value):
    params = env["ir.config_parameter"].sudo()
    # Odoo 20 replaced set_param with typed setters.
    (params.set_str if hasattr(params, "set_str") else params.set_param)(key, value)


def get_param(key):
    params = env["ir.config_parameter"].sudo()
    return params.get_str(key) if hasattr(params, "get_str") else params.get_param(key)


def save_checksums(checksums):
    set_param(CHECKSUMS_KEY, json.dumps(checksums, sort_keys=True))


def install():
    admin = env.ref("base.user_admin")
    values = {"password": os.environ["ODOO_ADMIN_PASSWORD"]}
    if os.environ.get("ODOO_ADMIN_LOGIN"):
        values["login"] = os.environ["ODOO_ADMIN_LOGIN"]
    if os.environ.get("ODOO_LANGUAGE"):
        values["lang"] = os.environ["ODOO_LANGUAGE"]
    admin.write(values)
    if os.environ.get("ODOO_ADMIN_EMAIL"):
        admin.partner_id.email = os.environ["ODOO_ADMIN_EMAIL"]
    if os.environ.get("ODOO_COMPANY_NAME"):
        env.ref("base.main_company").name = os.environ["ODOO_COMPANY_NAME"]
    # Links in emails and reports. Odoo changes it when the administrator signs in from another address.
    if os.environ.get("WODBY_PRIMARY_URL"):
        set_param("web.base.url", os.environ["WODBY_PRIMARY_URL"].rstrip("/"))
    # wkhtmltopdf loads a report's styles from this address. The container's own HTTP port avoids a
    # round trip through the public route, which may not be reachable from inside the cluster.
    set_param("report.url", os.environ.get("ODOO_REPORT_URL") or f"http://localhost:{os.environ.get('ODOO_HTTP_PORT', '8069')}")
    save_checksums(current_checksums())
    print(f"Administrator: {admin.login}")


def plan():
    modules = env["ir.module.module"]
    # New modules of the application code become installable from the Apps menu.
    modules.update_list()
    installed = modules.search([("state", "=", "installed")])

    updates = set()
    for module in installed:
        # An installed module whose code is gone can't be updated; Odoo reports it at startup.
        if not modules.get_module_info(module.name):
            continue
        if parse_version(module.installed_version or "0") > parse_version(module.latest_version or "0"):
            print(f"{module.name}: version {module.latest_version} -> {module.installed_version}")
            updates.add(module.name)

    checksums = current_checksums()
    try:
        previous = json.loads(get_param(CHECKSUMS_KEY) or "{}")
    except ValueError:
        previous = {}
    installed_names = set(installed.mapped("name"))
    for name, value in checksums.items():
        # A module without a recorded checksum was added or first seen now; an installed one is updated to be safe.
        if name in installed_names and previous.get(name) != value:
            print(f"{name}: files changed")
            updates.add(name)

    if not updates:
        # Uninstalled modules may have changed too; nothing to update for them.
        save_checksums(checksums)
    print("WODBY_UPDATE_MODULES=" + ",".join(sorted(updates)))


step = os.environ.get("WODBY_ODOO_STEP")
if step == "install":
    install()
elif step == "plan":
    plan()
elif step == "save":
    save_checksums(current_checksums())
else:
    raise SystemExit(f"Unknown step {step!r}")
env.cr.commit()
