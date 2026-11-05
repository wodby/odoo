# Runs a command while holding a PostgreSQL advisory lock on Odoo's database, so replicas that start together and the
# deployment's update action install or update Odoo one at a time. The connection comes from the PG* variables that
# docker-entrypoint.sh exports; the lock is released when this process exits.
#
# Usage: python3 odoo-lock.py <database> <command> [args...]

import subprocess
import sys

import psycopg2

LOCK_KEY = "wodby:odoo-update"

db, command = sys.argv[1], sys.argv[2:]
conn = psycopg2.connect(dbname=db)
conn.autocommit = True
with conn.cursor() as cur:
    cur.execute("SELECT pg_try_advisory_lock(hashtext(%s))", (LOCK_KEY,))
    if not cur.fetchone()[0]:
        print("Waiting for another installation or update of Odoo to finish", flush=True)
        cur.execute("SELECT pg_advisory_lock(hashtext(%s))", (LOCK_KEY,))

sys.exit(subprocess.call(command))
