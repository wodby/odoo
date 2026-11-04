ARG BASE_IMAGE

# Odoo's official image: Odoo installed from Odoo's own Debian package on Ubuntu, with the patched wkhtmltopdf that
# Odoo needs for PDF headers and footers. Its version and release date come from the pinned base image.
FROM ${BASE_IMAGE}

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ARG TARGETPLATFORM

# The official image sets en_US.UTF-8 without generating it, so Ubuntu's psql wrapper warns on every call.
ENV LANG="C.UTF-8" \
    APP_ROOT="/usr/src/app" \
    FILES_DIR="/mnt/files" \
    ODOO_RC="/etc/odoo/odoo.conf" \
    \
    PYTHONUNBUFFERED=1 \
    PIP_USER=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/home/wodby/.local/bin:${PATH}"

USER root

RUN set -eux; \
    \
    # Upgrade inherited packages even when their existing versions satisfy dependencies.
    apt-get update; \
    apt-get upgrade -y; \
    # git lets requirements.txt install packages from Git repositories.
    apt-get install -y --no-install-recommends git; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # Ubuntu's own user takes uid 1000.
    if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi; \
    if getent group ubuntu >/dev/null; then groupdel ubuntu; fi; \
    groupadd -g "${WODBY_GROUP_ID}" wodby; \
    useradd -u "${WODBY_USER_ID}" -g wodby -m -s /bin/bash wodby; \
    \
    dockerplatform="${TARGETPLATFORM:-linux/$(dpkg --print-architecture)}"; \
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-${dockerplatform/\//-}.tar.gz"; \
    curl -fsSL "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    command -v gotpl; \
    \
    # The configuration is rendered from the environment on every start.
    rm -f /etc/odoo/odoo.conf; \
    mkdir -p "${APP_ROOT}" "${FILES_DIR}" /var/lib/odoo /mnt/extra-addons; \
    chown wodby:wodby "${APP_ROOT}" "${FILES_DIR}" /var/lib/odoo /mnt/extra-addons /etc/odoo; \
    \
    { \
        echo 'export PS1="\u@$(hostname):\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee -a /home/wodby/.bashrc /home/wodby/.profile >/dev/null

COPY templates /etc/gotpl/
COPY bin /usr/local/bin/
COPY share /usr/local/share/wodby/
COPY docker-entrypoint.sh /

USER wodby

WORKDIR ${APP_ROOT}

# 8069: web interface and RPC. 8072: live updates (/websocket) when Odoo runs with workers.
EXPOSE 8069 8072

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["odoo"]
