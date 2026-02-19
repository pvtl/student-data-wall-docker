# Student Data Wall Runtime Repository

This repository is the deployment source of truth for Student Data Wall on Raspberry Pi and other Docker hosts.

It contains:

- Runtime deployment assets (`docker-compose.yml`, `.env.docker.example`)
- Operator tooling (`scripts/sdw` and command scripts)
- Runtime operations documentation (`docs/OPERATIONS.md`)
- Runtime validation CI workflows

## Release Model

- Private app repo (`pvtl/student-data-wall`) builds and publishes container images.
- Runtime repo (`pvtl/student-data-wall-docker`) defines how operators deploy those images.
- Releases are synchronized by tag (`vX.Y.Z`) across both repositories.
- Production paths must use pinned image references, not `latest`.

## Quick Start

```bash
cp .env.docker.example .env.docker
mkdir -p license
# Place your device license at license/license.lic
./scripts/sdw install
```

## Runtime Commands

Use the wrapper:

```bash
./scripts/sdw <command>
```

Supported commands:

- `install`: First-time setup on a host.
- `update`: Pull latest pinned image and apply runtime updates.
- `reset`: Stop and recreate runtime state with optional backups.
- `status`: Print deployment/runtime health and diagnostics.

See `docs/OPERATIONS.md` for full details.
