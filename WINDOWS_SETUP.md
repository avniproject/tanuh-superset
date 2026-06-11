# Setting up Tanuh Superset locally on Windows

This guide walks you from cloning the repo to a running, Tanuh-branded Superset at
http://localhost:8088 on a Windows machine. Everything runs in Docker — you do **not**
need Python, Node, or Superset installed on Windows itself.

There are two ways to work, pick one and stick with it:

- **Path A — WSL2 terminal (recommended).** You get a real Linux shell, so `make` and the
  repo's `Makefile` work exactly as documented in the README.
- **Path B — PowerShell.** No `make` on Windows, so you run the equivalent raw `docker`
  commands instead. Functionally identical.

---

## 1. Prerequisites (one-time machine setup)

1. **WSL2** — open *PowerShell as Administrator* and run:

   ```powershell
   wsl --install
   ```

   This installs WSL2 with an Ubuntu distro. Reboot when prompted, then launch "Ubuntu"
   from the Start menu once to create your Linux username/password.

2. **Docker Desktop for Windows** — download from https://www.docker.com/products/docker-desktop/
   and install. In *Settings*:
   - *General* → ensure **"Use the WSL 2 based engine"** is checked.
   - *Resources → WSL Integration* → enable integration for your **Ubuntu** distro.

   Docker Desktop must be **running** for any of the commands below to work.

3. **Git**
   - Path A: inside the Ubuntu terminal: `sudo apt update && sudo apt install -y git make`
   - Path B: install [Git for Windows](https://git-scm.com/download/win).

4. **GitHub access** — you need access to `avniproject/tanuh-superset`. Authenticate with
   a personal access token or `gh auth login` as you normally would.

> **Hardware note:** the image is `linux/amd64`. On a normal Intel/AMD Windows machine this
> is native. On Windows-on-ARM laptops it runs under emulation (slow, but works).

## 2. Clone the repo

**Path A (WSL):** clone into the Linux filesystem (your WSL home, *not* `/mnt/c/...` —
Docker builds from the Windows filesystem are much slower):

```bash
cd ~
git clone https://github.com/avniproject/tanuh-superset
cd tanuh-superset
```

**Path B (PowerShell):**

```powershell
cd $HOME
git clone https://github.com/avniproject/tanuh-superset
cd tanuh-superset
```

## 3. Build the image

The Dockerfile takes upstream `apache/superset:6.0.0` and layers in Tanuh branding,
`superset_config.py`, and the Postgres driver. First build downloads ~2 GB, so give it
a few minutes.

**Path A:**

```bash
make build-image
```

**Path B (equivalent of `make build-image`):**

```powershell
docker image build --build-arg TAG=6.0.0 -t avniproject/tanuh-superset:6.0.0 .
```

Verify: `docker images` should list `avniproject/tanuh-superset:6.0.0`.

## 4. Start a local metadata database (Postgres)

Superset needs its own Postgres database for its metadata (users, dashboards, charts —
**not** your reporting data). Run a throwaway one in Docker (same command both paths):

```bash
docker run -d --name tanuh-superset-db -p 5432:5432 \
  -e POSTGRES_USER=superset \
  -e POSTGRES_PASSWORD=superset \
  -e POSTGRES_DB=superset_meta \
  postgres:16
```

(In PowerShell, either put it on one line or replace the `\` line-continuations with `` ` ``.)

This DB keeps your local dashboards/users between restarts as long as the
`tanuh-superset-db` container exists. `docker start tanuh-superset-db` brings it back
after a reboot.

## 5. Create `superset.env`

The Makefile's `run-container` target reads environment variables from a `superset.env`
file in the repo root. Create it with this content:

```env
SUPERSET_SECRET_KEY=<paste-a-random-secret-here>
SUPERSET_DB_URL=host.docker.internal
SUPERSET_DB_PORT=5432
SUPERSET_DB_NAME=superset_meta
SUPERSET_DB_USER=superset
SUPERSET_DB_PASSWORD=superset
```

Generate the secret key:

- Path A / Git Bash: `openssl rand -base64 42`
- Path B (PowerShell): `python -c "import secrets; print(secrets.token_urlsafe(42))"`
  (or any long random string — this is only a local instance)

Notes:

- `host.docker.internal` is how a container reaches services published on your Windows
  host (here: the Postgres container's port 5432). Don't use `localhost` — inside the
  Superset container that points at the container itself.
- **Save the file with LF line endings** (in VS Code: click `CRLF` in the status bar →
  select `LF`). `docker --env-file` does not strip Windows `\r` characters, and a stray
  `\r` on the end of the password silently breaks the DB connection.
- This file holds credentials — it is gitignored; **never commit it**.

## 6. Run Superset

**Path A:**

```bash
make run-container
```

This starts the container as `superset_6.0.0`, publishes port 8088, and tails the logs
(Ctrl+C stops the log tail, not the container).

**Path B (equivalent):**

```powershell
docker run -d -p 8088:8088 --name superset_6.0.0 --env-file superset.env avniproject/tanuh-superset:6.0.0
docker logs -f superset_6.0.0
```

Wait until the logs show gunicorn workers booted (lines like `Booting worker with pid: ...`).

## 7. First-run initialization (once per fresh metadata DB)

The image deliberately does **not** auto-initialize the database (in production that's
done by the deployment). On a brand-new metadata DB, run (same commands both paths):

```bash
docker exec -it superset_6.0.0 superset db upgrade
docker exec -it superset_6.0.0 superset fab create-admin
docker exec -it superset_6.0.0 superset init
```

`fab create-admin` prompts you interactively for the admin username/password you'll use
to log in. You only do this once — the data lives in the `tanuh-superset-db` container.

## 8. Open it

Go to **http://localhost:8088** and log in with the admin user you just created.

Sanity checks:

- The **Tanuh logo** shows on the login page and the header (this is the whole point of
  this image — if you see the default Superset logo, the build didn't pick up the branding).
- The browser tab title says **Tanuh**.

## Day-to-day commands

| Task | Path A (`make`) | Path B (raw docker) |
|---|---|---|
| Tail logs | `make get-container-logs` | `docker logs -f superset_6.0.0` |
| Shell inside container | `make execute-container` | `docker exec -it superset_6.0.0 bash` |
| Stop & remove container | `make remove-container` | `docker container rm -f superset_6.0.0` |
| Rebuild image from scratch | `make re-build-image` | remove image, then build again |

Typical iteration loop after changing `superset_config.py` or `assets/`:

```bash
make remove-container && make build-image && make run-container
```

(Config and assets are **baked into the image**, so a rebuild is required — restarting the
container is not enough. Your dashboards/users survive because they live in Postgres.)

## Troubleshooting

- **`docker: command not found` (in WSL)** — Docker Desktop isn't running, or WSL
  integration isn't enabled for your Ubuntu distro (Docker Desktop → Settings →
  Resources → WSL Integration).
- **Container exits immediately / `connection refused` in logs** — Postgres isn't up
  (`docker ps` should show `tanuh-superset-db`) or `SUPERSET_DB_URL` is wrong. It must be
  `host.docker.internal`, not `localhost`.
- **`password authentication failed` even though the password is right** — almost always
  CRLF line endings in `superset.env` (see step 5). Re-save the file with LF.
- **Port 8088 already in use** — something else is on 8088. Either stop it or change the
  publish mapping to e.g. `-p 8089:8088` and browse to `localhost:8089`.
- **`No module named 'psycopg2'`** — you're running a stale image from before the uv fix.
  `make re-build-image` and recreate the container.
- **Login page shows the default Superset logo** — the container is running an old image.
  `make remove-container && make run-container` after rebuilding.
- **Want to start completely fresh** — remove the Superset container, then
  `docker rm -f tanuh-superset-db` and redo steps 4–7 (this wipes local dashboards/users).
