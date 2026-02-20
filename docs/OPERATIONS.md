# Student Data Wall Runtime Operations

## Prerequisites

- Docker Engine installed
- Docker Compose v2 plugin installed (`docker compose`)
- Access to pull `ghcr.io/pvtl/student-data-wall-docker`
- Runtime files checked out from this repository

## Initial Installation

```bash
cp .env.docker.example .env.docker
mkdir -p license
# Place the per-device license file at license/license.lic
./scripts/sdw install
```

If `APP_KEY` is unset, generate one and place it in `.env.docker`:

```bash
docker compose run --rm app php artisan key:generate --show
```

## Update Runtime

```bash
./scripts/sdw update
```

Optional target context flag:

```bash
./scripts/sdw update --target v0.1.0
```

This command expects the repository checkout to already match your intended release tag.

## Reset Runtime

With backup (default):

```bash
./scripts/sdw reset
```

Without backup:

```bash
./scripts/sdw reset --no-backup
```

## Runtime Status

```bash
./scripts/sdw status
```

Displays runtime version, configured image reference, container status, migration status, and recent logs.

## Version and Pinning Rules

- Runtime tag, `VERSION`, and `.env.docker.example` `RUNTIME_VERSION` must match.
- `APP_IMAGE` may stay unchanged across multiple runtime releases when packaging/scripts are updated.
- Do not use `latest` in production runtime config.
- Prefer immutable digest pinning for `APP_IMAGE`.
