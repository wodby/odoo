#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

network="${NAME}-net"
postgres="${NAME}-postgres"
data="${NAME}-data"
cid=""
addons="$(mktemp -d)"
cp -R addons/. "${addons}/"
chmod -R a+rX "${addons}"

cleanup() {
    docker rm -vf "${NAME}" "${postgres}" > /dev/null 2>&1 || true
    docker volume rm -f "${data}" > /dev/null 2>&1 || true
    docker network rm "${network}" > /dev/null 2>&1 || true
    rm -rf "${addons}"
}
trap cleanup EXIT

env_args=(
    -e DB_HOST="${postgres}"
    -e DB_USER=odoo
    -e DB_PASSWORD='odoo pass%'
    -e DB_NAME=odoo
    -e ODOO_DATA_DIR=/mnt/files
    -e ODOO_ADMIN_LOGIN=admin@example.com
    -e ODOO_ADMIN_EMAIL=admin@example.com
    -e ODOO_COMPANY_NAME='Example Inc.'
    -e WODBY_PRIMARY_URL=https://odoo.example.com
)

# A one-off container, as Wodby runs actions.
odoo_run() {
    docker run --rm --network "${network}" "${env_args[@]}" -v "${data}:/mnt/files" \
        -v "${addons}:/usr/src/app/addons:ro" "${IMAGE}" "${@}"
}

psql_run() {
    docker exec -e PGPASSWORD=postgres "${postgres}" psql -U postgres -d odoo -tAX -c "${1}"
}

docker network create "${network}" > /dev/null
docker volume create "${data}" > /dev/null

# Wodby gives Odoo a database owned by a role that can't create databases.
docker run -d --name "${postgres}" --network "${network}" -e POSTGRES_PASSWORD=postgres postgres:17-alpine > /dev/null
for _ in $(seq 1 60); do
    if docker exec "${postgres}" pg_isready -U postgres -h localhost > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
sleep 2
docker exec -e PGPASSWORD=postgres "${postgres}" psql -U postgres -q \
    -c "CREATE ROLE odoo LOGIN PASSWORD 'odoo pass%' NOSUPERUSER NOCREATEDB NOCREATEROLE" \
    -c "CREATE DATABASE odoo OWNER odoo"

echo -n "Checking the user and Odoo version... "
odoo_run id -u | grep -qx 1000
odoo_run odoo --version | grep -q "${ODOO_VER}"
odoo_run wkhtmltopdf --version | grep -q "with patched qt"
echo "OK"

echo -n "Checking the rendered configuration... "
conf="$(odoo_run cat /etc/odoo/odoo.conf)"
grep -qxF "db_name = odoo" <<<"${conf}"
grep -qxF 'dbfilter = ^odoo$' <<<"${conf}"
grep -qxF "list_db = False" <<<"${conf}"
grep -qxF "proxy_mode = True" <<<"${conf}"
grep -qxF "workers = 2" <<<"${conf}"
grep -qxF "addons_path = /usr/src/app/addons" <<<"${conf}"
! grep -q "^admin_passwd = admin$" <<<"${conf}"
echo "OK"

echo -n "Checking that installing needs the administrator password... "
if odoo_run odoo-update > /tmp/odoo-test.log 2>&1; then
    cat /tmp/odoo-test.log
    exit 1
fi
grep -q "set the administrator password" /tmp/odoo-test.log
echo "OK"

echo "Installing Odoo... "
env_args+=(-e ODOO_ADMIN_PASSWORD='Admin pass 1!')
odoo_run odoo-update
echo "OK"

echo -n "Checking the installation... "
[[ "$(psql_run "SELECT state FROM ir_module_module WHERE name = 'base'")" == "installed" ]]
[[ "$(psql_run "SELECT login FROM res_users WHERE id = 2")" == "admin@example.com" ]]
[[ "$(psql_run "SELECT value FROM ir_config_parameter WHERE key = 'web.base.url'")" == "https://odoo.example.com" ]]
[[ "$(psql_run "SELECT name FROM res_company WHERE id = 1")" == "Example Inc." ]]
[[ "$(psql_run "SELECT value FROM ir_config_parameter WHERE key = 'report.url'")" == "http://localhost:8069" ]]
# The test module is listed, not installed.
[[ "$(psql_run "SELECT state FROM ir_module_module WHERE name = 'wodby_test'")" == "uninstalled" ]]
echo "OK"

echo -n "Checking that a second run updates nothing... "
odoo_run odoo-update | grep -q "No module needs an update"
echo "OK"

echo -n "Starting Odoo with workers... "
docker run -d --name "${NAME}" --network "${network}" "${env_args[@]}" -v "${data}:/mnt/files" \
    -v "${addons}:/usr/src/app/addons:ro" "${IMAGE}" > /dev/null
for _ in $(seq 1 60); do
    if docker exec "${NAME}" curl -fsS http://localhost:8069/web/health 2>/dev/null | grep -q pass; then
        break
    fi
    sleep 1
done
docker exec "${NAME}" curl -fsS http://localhost:8069/web/health | grep -q pass || { docker logs "${NAME}"; exit 1; }
echo "OK"

echo -n "Signing in as the administrator... "
docker exec "${NAME}" python3 - <<'EOF'
import json, urllib.request
req = urllib.request.Request(
    "http://localhost:8069/web/session/authenticate",
    data=json.dumps({"jsonrpc": "2.0", "params": {"db": "odoo", "login": "admin@example.com", "password": "Admin pass 1!"}}).encode(),
    headers={"Content-Type": "application/json"},
)
result = json.load(urllib.request.urlopen(req))
assert result.get("result", {}).get("uid") == 2, result
EOF
echo "OK"

echo -n "Checking that the database manager is off... "
body="$(docker exec "${NAME}" curl -s http://localhost:8069/web/database/manager)"
grep -q "database manager has been disabled" <<<"${body}" || { echo "${body}" | head -c 2000; exit 1; }
echo "OK"

echo -n "Checking live updates on the gevent port... "
# The gevent process starts after the HTTP workers.
for _ in $(seq 1 30); do
    status="$(docker exec "${NAME}" curl -sS -i --http1.1 --max-time 3 \
        -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
        -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' -H 'Origin: http://localhost:8072' \
        http://localhost:8072/websocket 2>/dev/null | head -n 1 || true)"
    if grep -q " 101 " <<<"${status}"; then
        break
    fi
    sleep 1
done
grep -q " 101 " <<<"${status}" || { echo "${status}"; docker logs --tail 20 "${NAME}"; exit 1; }
echo "OK"

echo -n "Rendering a PDF report... "
# A report of the base module, rendered by Odoo's default engine with the image's wkhtmltopdf.
docker exec -i "${NAME}" odoo shell -d odoo --no-http --log-level=warn <<'EOF' 2>&1 | tee /tmp/odoo-test.log | grep -q "PDF OK"
module = env.ref("base.module_base")
pdf, kind = env["ir.actions.report"]._render_qweb_pdf("base.ir_module_reference_print", module.ids)
print("PDF OK" if kind == "pdf" and pdf.startswith(b"%PDF") else f"PDF FAILED {kind}")
EOF
# The report's styles were loaded from the container itself.
! grep -q "network error" /tmp/odoo-test.log
echo "OK"

echo -n "Checking the filestore on the data volume... "
docker exec "${NAME}" test -d /mnt/files/filestore/odoo
docker exec "${NAME}" test -d /mnt/files/sessions
echo "OK"

echo -n "Installing the test module and updating it after a change... "
docker exec "${NAME}" odoo -d odoo -i wodby_test --stop-after-init --no-http --log-level=warn
[[ "$(psql_run "SELECT value FROM ir_config_parameter WHERE key = 'wodby_test.value'")" == "one" ]]
sed -i.bak 's/>one</>two</' "${addons}/wodby_test/data/params.xml" && rm "${addons}/wodby_test/data/params.xml.bak"
odoo_run odoo-update | tee /tmp/odoo-test.log | grep -q "Updating modules: wodby_test"
[[ "$(psql_run "SELECT value FROM ir_config_parameter WHERE key = 'wodby_test.value'")" == "two" ]]
odoo_run odoo-update | grep -q "No module needs an update"
echo "OK"
