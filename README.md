# petRing & petAds

> [!NOTE]
> petRing has moved!
>
> petRing has moved to a new remote @ git.scug.io
>
> See [here](https://git.scug.io/paws/petring)

> [!WARNING]
> This project is in an early ALPHA and is not ready for any serious usecase
>
> Bugs will exist, and code will be messy; Keep that in mind.

petRing is the pet-coded webring and navlink ad system; Written in Erlang (OTP 28) with rebar3 and runs as a single server that
serves both the JSON API and the frontend.

## Table of Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [How to install](#how-to-install)
  - [Requirements](#requirements)
  - [Installation](#installation)
- [How to build](#how-to-build)
  - [Prerequisites](#prerequisites)
  - [Frontend](#frontend)
  - [Prebuild](#prebuild)
  - [Configuration](#configuration)
  - [Finally](#finally)
  - [Running](#running)
  - [Docker](#docker)
- [Contributing](#contributing)
  - [For people without write access](#for-people-without-write-access)
  - [For people with write access](#for-people-with-write-access)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## How to install

### Requirements

- Erlang/OTP 28
- rebar3 3.27 or newer
- SQLite3
- A C toolchain (`gcc`, `pkg-config`) plus the development headers for
  SQLite3, brotli, libmagic, and libargon2, which are needed to build the errm
  NIFs
- just, which the errm NIF build hooks invoke
- Deno, which builds the frontend
- Nix (optional; the flake reproduces the full toolchain)
- Docker (optional)

### Installation

- Clone the repo:

```bash
git clone https://github.com/h4rldev/petring.git
cd petring
```

- And for people using Nix or NixOS, optionally enter the Nix dev shell, which provides every build dependency:

```bash
nix develop
```

- Or

```bash
direnv allow
```

## How to build

### Prerequisites

- All of the [Requirements](#requirements) above
- A populated `site-root/` directory if you want to serve the frontend (see
  [Frontend](#frontend))

### Frontend

The SvelteKit app lives in `frontend/` and builds into `site-root/`, which the
server serves. Build it with Deno:

```bash
cd frontend
deno install
deno task build
```

The `build` task runs `vite build` and moves the output into `site-root/`. The
server serves that directory and falls back to `200.html` for client side
routing. The interactive API reference is the `/docs/` page of the frontend.

### Prebuild

petRing stores everything in a single SQLite database. Create and migrate it
before the first run:

```bash
rebar3 as migrations escriptize
_build/migrations/bin/migrator migrate petring.db migrations
```

The migrator takes the database path and, optionally, the migrations directory.
Pass the directory whenever you run it from outside the repo root.

### Configuration

Settings live in `petring-config.json`. The file is created with defaults on
first boot if it does not exist.

| Key | Default | Description |
| --- | --- | --- |
| `port` | `8080` | HTTP listen port |
| `internal_log_level` | `"info"` | Erlang logger level |
| `db_path` | `"petring.db"` | SQLite database file |
| `server_name` | `"petring"` | Server name |
| `server_url` | `"https://your-domain.example"` | Public base URL used in feeds, the sitemap, and webhook payloads |
| `cors_origins` | `["*"]` | Allowed CORS origins |
| `cors_credentials` | `false` | Allow credentials in CORS |
| `url_reachability` | `false` | Require submitted URLs to be reachable |
| `log_access` | `true` | Write an access log |
| `access_log_file` | `""` | Access log file; when empty, logs to the Erlang logger |

Secrets and other environment variables are read from the environment first,
and then from `petring.env` (also auto-generated on first boot).

- `JWT_SECRET`: the session signing secret. Generated and written to
  `petring.env` if it is not set.
- `PETRING_SUPERADMIN_USER` / `PETRING_SUPERADMIN_PASS`: credentials for the
  bootstrapped superadmin (default `superadmin` / `superadmin`). They are
  applied only until the account is first modified.

### Finally

Build the production escript:

```bash
rebar3 as prod escriptize
```

The escript lands at `_build/prod/bin/petring`.

### Running

```bash
./_build/prod/bin/petring
```

By default the server listens on `http://localhost:8080`. The JSON API is
served under `/api` (`/api` itself redirects to the frontend `/docs/` page),
and the frontend is served from `site-root/`, with `200.html` as the fallback
for client side routing.

For development you can compile and start without packaging:

```bash
rebar3 compile
erl -noshell -pa _build/default/lib/*/ebin -eval 'petring:start(), timer:sleep(infinity).'
```

### Docker

A prebuilt multi-arch image is published to `ghcr.io/h4rldev/petring:latest`.
The included compose file runs a single `petring` service, mounts `./data` for
the database, config, and secrets, and serves on port `8080` by default:

```bash
docker compose up -d
```

The image builds the backend, the migrator, and the frontend, and runs
migrations automatically on start. To build from source instead, comment out
the `image:` line and uncomment `build: .` in `docker-compose.yml`.

- Or, to deploy without cloning the repo, run the download script, which fetches
  the compose files and starts the published image:

```bash
curl -fsSL https://raw.githubusercontent.com/h4rldev/petring/main/download.sh | bash
```

## Contributing

### For people without write access

- Fork the repo
- Check out a new branch based on [dev](https://github.com/h4rldev/petring/tree/dev)
- Make your changes
- Test your changes locally.
- If you want to be considerate, follow the [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.
- Submit a PR describing what you've done

### For people with write access

- No need to fork the repo, just clone it
- And then follow the same instructions as above
- When merging auto-prs, also follow the [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.

## License

This project is licensed under the BSD-3 Clause License, see the [LICENSE](LICENSE) file for details.
