# tanuh-superset

Tanuh-branded build of [Apache Superset](https://superset.apache.org/) — the reporting UI for the Tanuh
engagement.

This repo is **consultant-facing and intentionally small**: it holds only what you need to **redesign and
build the Tanuh Superset image** (branding, theme, configuration, dashboards). It deliberately contains **no
infrastructure, secrets, or deployment code** — those live in the private `avniproject/avni-infra` repo,
owned by the Avni platform team.

> Tracking issue: **[avniproject/avni-infra#94](https://github.com/avniproject/avni-infra/issues/94)** —
> "Tanuh: stand up a whitelabeled Superset reporting instance (alongside Metabase)".

## Why a separate repo?

Superset is **Apache-2.0**, so it can be freely branded via config — unlike Metabase OSS, whose
white-labelling is an Enterprise-only feature. Keeping this build in its own repo lets external consultants
iterate on the Superset redesign **without access to Avni's production infrastructure** (`avni-infra` holds
encrypted prod secrets, RDS endpoints, IAM roles, and the full topology).

## What's in here

| Path | Purpose |
|---|---|
| `Dockerfile` | Builds the Tanuh image from `apache/superset:<TAG>` + Tanuh branding |
| `superset_config.py` | Superset config — branding (`APP_NAME`, theme logo, favicon) + metadata-DB wiring via env |
| `assets/logo.png` | Tanuh logo used for the header/login brand and (for now) the favicon |
| `Makefile` | `build-image`, `run-container`, `push-image`, … |
| `VERSION` | Single source of truth for the published image tag (`<superset-version>-tanuh-<n>`) |
| `.github/workflows/` | CI template to build + push the image to ECR (wired up by ops — see "How it ships") |

## What to (re)design — the consultant surface

- **Branding** — `superset_config.py` (`APP_NAME`, `THEME_DEFAULT`/`THEME_DARK` brand tokens, `FAVICONS`) and
  `assets/` (logo, favicon, any custom theme/CSS).
- **Dashboards & datasets** — keep exported dashboard/chart definitions here for reproducible imports (e.g.
  add an `assets/dashboards/` dir).
- **Superset config / feature flags** — anything in `superset_config.py`.

**Out of scope here** (owned by avni-infra / the Avni platform team): the host/EC2, ALB + TLS, the metadata
database and its credentials, secrets, and the deploy itself.

## Build & run locally

Prereq: Docker.

```bash
make build-image                 # builds avniproject/tanuh-superset:<TAG>
```

Superset needs its own metadata Postgres DB. Point the container at a local/throwaway one:

```bash
docker run -d -p 8088:8088 \
  -e SUPERSET_SECRET_KEY="$(openssl rand -base64 42)" \
  -e SUPERSET_DB_URL=<host> -e SUPERSET_DB_PORT=5432 \
  -e SUPERSET_DB_NAME=<db> -e SUPERSET_DB_USER=<user> -e SUPERSET_DB_PASSWORD=<pw> \
  --name tanuh_superset avniproject/tanuh-superset:<TAG>

# first run only — initialise the metadata DB + an admin user:
docker exec -it tanuh_superset superset db upgrade
docker exec -it tanuh_superset superset fab create-admin
docker exec -it tanuh_superset superset init
```

Open http://localhost:8088 and confirm the Tanuh logo/name render on the login + header.

## How it ships

1. Bump `VERSION` (e.g. `6.0.0-tanuh-2`) and tag the repo `v<VERSION>`.
2. CI builds `linux/amd64` and pushes to ECR `avniproject/tanuh-superset` (AWS account + OIDC role
   provisioned via avni-infra#94).
3. `avni-infra` consumes the published tag and deploys the container onto the Tanuh reporting host, behind
   SSL + ALB, pointed at its own metadata DB (`tanuh_reporting_superset_db`).

## Notes / TODO

- **Pin the Superset version deliberately.** `TAG` defaults to `6.0.0` (the version Avni's existing Superset
  runs). The brand-logo config in `superset_config.py` uses the theme-token branding (`brandLogoUrl`) that
  exists only on Superset's new theme system (5.0+); on 4.x the logo silently won't render. Bump intentionally,
  and if you drop below 5.0 switch back to the 4.x branding keys (`APP_ICON`/`LOGO_TARGET_PATH`). Re-test on bump.
- **Add a real favicon.** Today the PNG logo doubles as the favicon; a dedicated `.ico` renders better at
  16×16.
- **Production server only.** The image relies on the base `apache/superset` gunicorn entrypoint — do **not**
  re-introduce the Flask dev server (`superset run --reload --debugger`).
- **Reference build.** Adapted from Avni's existing Superset build in
  `avni-infra/reportingSystem/superset/`.
