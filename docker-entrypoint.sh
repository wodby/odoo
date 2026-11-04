#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

# Odoo's data directory holds uploaded files (the filestore) and sessions.
data_dir="${ODOO_DATA_DIR:-/var/lib/odoo}"
mkdir -p "${data_dir}"

if [[ -z "${ODOO_ADDONS_PATH}" ]]; then
    ODOO_ADDONS_PATH="$(odoo-addons-path)"
    export ODOO_ADDONS_PATH
fi

# Without a master password Odoo falls back to "admin". The database manager is off by default, so a random one per
# start is enough when none is given.
if [[ -z "${ODOO_MASTER_PASSWORD}" ]]; then
    ODOO_MASTER_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -d '/+=')"
    export ODOO_MASTER_PASSWORD
fi

# A managed database server's CA certificate: connect over TLS and verify the server.
if [[ -n "${DB_SSL_CA}" && -f "${DB_SSL_CA}" ]]; then
    export PGSSLROOTCERT="${DB_SSL_CA}"
    export DB_SSL_MODE="${DB_SSL_MODE:-verify-full}"
fi

gotpl /etc/gotpl/odoo.conf.tmpl > "${ODOO_RC}"
unset ODOO_MASTER_PASSWORD

# The same connection for psql in helper scripts and shells.
export PGHOST="${DB_HOST:-postgres}" PGPORT="${DB_PORT:-5432}" PGUSER="${DB_USER:-odoo}"
export PGPASSWORD="${DB_PASSWORD:-odoo}"
if [[ -n "${DB_NAME}" ]]; then
    export PGDATABASE="${DB_NAME}"
fi

# Odoo reads its configuration file from ODOO_RC.
case "${1}" in
    -*)
        exec odoo "${@}"
        ;;
    *)
        exec "${@}"
        ;;
esac
