# Odoo Docker Container Image

[![Build Status](https://github.com/wodby/odoo/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/odoo/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/odoo.svg)](https://hub.docker.com/r/wodby/odoo)

[Odoo](https://www.odoo.com) Community Edition, based on Odoo's [official image](https://hub.docker.com/_/odoo), with
its configuration taken from environment variables, a command that installs Odoo into an empty database or updates the
modules that changed, and a regular `wodby` user (uid 1000).

## Docker Images

❗For better reliability we release images with stability tags (`wodby/odoo:20-rN`) which correspond to
[git tags](https://github.com/wodby/odoo/releases). We strongly recommend using images only with stability tags.

- Base image: [odoo](https://hub.docker.com/_/odoo), pinned by digest: Ubuntu with Odoo's Debian package and the
  patched wkhtmltopdf that Odoo needs for PDF reports
- [GitHub actions builds](https://github.com/wodby/odoo/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/odoo)

Supported tags:

| Tag              | Odoo |
|------------------|------|
| `20`, `latest`   | 20.0 |
| `19`             | 19.0 |
| `18`             | 18.0 |

`20.0`, `19.0` and `18.0` tag the same images. All images are built for `linux/amd64` and `linux/arm64`.

## Your modules

Put your modules (addons) in `/usr/src/app`. Every directory there, up to three levels deep, that holds modules is
added to Odoo's `addons_path`: modules at the root, in `addons/`, or one directory per collection, such as Git
submodules of community repositories. `/mnt/extra-addons` is searched too. Set `ODOO_ADDONS_PATH` to choose the
directories yourself.

Python packages your modules need go in a `requirements.txt` and are installed with `pip install -r requirements.txt`
as the `wodby` user.

## Installing and updating

`odoo-update` prepares the database before or after a new version of your code starts:

- On an empty database it installs `base` and the modules in `ODOO_INIT_MODULES`, without demo data, and sets up the
  administrator from `ODOO_ADMIN_LOGIN`, `ODOO_ADMIN_PASSWORD` and `ODOO_ADMIN_EMAIL`. It stops with an error when no
  administrator password is set.
- On an installed database it updates the installed modules whose manifest version went up, and the installed modules
  in `/usr/src/app` or `/mnt/extra-addons` whose files changed since its last run (changes in `static/` and `tests/`
  don't count). It also refreshes the list of modules, so new ones can be installed from the Apps menu.
- `odoo-update all` updates every installed module.

The administrator settings are used only for the installation; change the password in Odoo afterwards.

## Environment Variables

| Variable                    | Default          | Description                                                                 |
|-----------------------------|------------------|-----------------------------------------------------------------------------|
| `DB_HOST`                   | `postgres`       |                                                                             |
| `DB_PORT`                   | `5432`           |                                                                             |
| `DB_USER`                   | `odoo`           |                                                                             |
| `DB_PASSWORD`               | `odoo`           |                                                                             |
| `DB_NAME`                   |                  | The only database Odoo serves                                               |
| `DB_SSL_CA`                 |                  | CA certificate file of the database server: connect over verified TLS       |
| `ODOO_DB_SSLMODE`           | `prefer`         | `verify-full` when `DB_SSL_CA` is set                                       |
| `ODOO_DBFILTER`             |                  | Unset: Odoo serves only `DB_NAME`. A filter makes Odoo list the databases its login role owns |
| `ODOO_LIST_DB`              | `False`          | `True` turns on the database manager                                        |
| `ODOO_MASTER_PASSWORD`      | random           | Password of the database manager (`admin_passwd`)                           |
| `ODOO_DATA_DIR`             | `/var/lib/odoo`  | Filestore and sessions. Every replica must share it                         |
| `ODOO_ADDONS_PATH`          | found            | Comma-separated directories with modules                                    |
| `ODOO_WORKERS`              | `2`              | HTTP worker processes. `0` serves everything from one process on port 8069  |
| `ODOO_MAX_CRON_THREADS`     | `1`              | Scheduled action workers                                                    |
| `ODOO_LIMIT_MEMORY_SOFT`    | `2147483648`     | Bytes                                                                       |
| `ODOO_LIMIT_MEMORY_HARD`    | `2684354560`     | Bytes                                                                       |
| `ODOO_LIMIT_TIME_CPU`       | `60`             | Seconds                                                                     |
| `ODOO_LIMIT_TIME_REAL`      | `120`            | Seconds                                                                     |
| `ODOO_LIMIT_TIME_REAL_CRON` | `-1`             | Seconds; `-1` uses `ODOO_LIMIT_TIME_REAL`                                   |
| `ODOO_LIMIT_REQUEST`        | `65536`          |                                                                             |
| `ODOO_DB_MAXCONN`           | `64`             |                                                                             |
| `ODOO_PROXY_MODE`           | `True`           | Trust `X-Forwarded-*` headers. Keep it on behind a proxy only               |
| `ODOO_HTTP_PORT`            | `8069`           |                                                                             |
| `ODOO_GEVENT_PORT`          | `8072`           |                                                                             |
| `ODOO_SERVER_WIDE_MODULES`  |                  |                                                                             |
| `ODOO_UNACCENT`             |                  |                                                                             |
| `ODOO_EMAIL_FROM`           |                  |                                                                             |
| `ODOO_LOG_LEVEL`            | `info`           |                                                                             |
| `ODOO_LOG_HANDLER`          |                  |                                                                             |
| `SMTP_HOST`                 |                  | Outgoing mail server                                                        |
| `SMTP_PORT`                 | `25`             |                                                                             |
| `SMTP_USER`                 |                  |                                                                             |
| `SMTP_PASSWORD`             |                  |                                                                             |
| `SMTP_SSL`                  |                  |                                                                             |
| `ODOO_ADMIN_LOGIN`          | `admin`          | Installation only                                                           |
| `ODOO_ADMIN_PASSWORD`       |                  | Installation only; required to install                                      |
| `ODOO_ADMIN_EMAIL`          |                  | Installation only                                                           |
| `ODOO_COMPANY_NAME`         |                  | Installation only                                                           |
| `ODOO_LANGUAGE`             |                  | Installation only: language to load and give the administrator, as `fr_FR`  |
| `ODOO_INIT_MODULES`         |                  | Installation only: comma-separated modules to install with `base`           |
| `ODOO_WITH_DEMO`            |                  | Installation only: load demo data                                           |
| `WODBY_PRIMARY_URL`         |                  | Installation only: Odoo's `web.base.url`                                    |
| `ODOO_REPORT_URL`           | `http://localhost:8069` | Installation only: Odoo's `report.url`, where wkhtmltopdf loads report styles |

The configuration file is rendered from `/etc/gotpl/odoo.conf.tmpl` to `/etc/odoo/odoo.conf` on every start; mount
your own template there to change anything else.

## Ports

| Port | Used for                                                                    |
|------|-----------------------------------------------------------------------------|
| 8069 | Web interface and RPC                                                       |
| 8072 | Live updates (`/websocket`) when `ODOO_WORKERS` is above 0; route it there  |

## Orchestration Actions

```bash
docker exec CONTAINER odoo-update      # install or update
docker exec CONTAINER odoo-update all  # update every installed module
```
