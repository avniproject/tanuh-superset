# Tanuh-branded Apache Superset image.
# Adapted from Avni's existing Superset build (avni-infra/reportingSystem/superset).
#
# TAG = the upstream apache/superset version to brand. Pin it deliberately and re-test
# on bump (Avni's existing Superset runs 4.0.1). Override with: make build-image TAG=<ver>
ARG TAG=4.0.1

FROM --platform=linux/amd64 apache/superset:${TAG}

# Root to install OS + python deps
USER root

# chromium/-driver: dashboard screenshots & alerts; libpq/build-essential: psycopg2
RUN apt-get update && \
    apt-get install -y \
        chromium \
        chromium-driver \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# pip (not `uv`) so this builds across Superset image versions
RUN pip install --no-cache-dir psycopg2-binary Pillow

USER superset

# --- Tanuh branding (bundled in this repo) ---
# logo.png backs the header/login brand and (for now) the favicon. See README TODO
# about adding a dedicated .ico favicon.
COPY --chown=superset ./assets/logo.png /app/superset/static/assets/images/tanuh.png

# --- Superset config (branding + DB wiring via env) ---
COPY --chown=superset ./superset_config.py /app/superset_config.py
ENV SUPERSET_CONFIG_PATH=/app/superset_config.py

# DB + secret are injected at runtime by the deployment (avni-infra). Dummy defaults
# keep a local `docker build` / smoke run sane; never bake real values here.
ENV SUPERSET_SECRET_KEY=dummy \
    SUPERSET_DB_NAME=dummy \
    SUPERSET_DB_USER=dummy \
    SUPERSET_DB_PASSWORD=dummy \
    SUPERSET_DB_URL=dummy \
    SUPERSET_DB_PORT=dummy

EXPOSE 8088

# NOTE: intentionally NO `ENTRYPOINT ["superset","run",...,"--reload","--debugger"]`.
# That is the Flask dev server and must not be used in production. We inherit the
# apache/superset base image's default entrypoint, which runs the gunicorn prod server.
# First-boot init (`superset db upgrade` / `fab create-admin` / `superset init`) is done
# by the deployment (avni-infra), not baked into the image.
