# HomeOps DevOps Lab

A small, reproducible DevOps lab running on a Debian home server. The project
documents the path from a minimal containerized application to a monitored
delivery platform with CI/CD, a container registry, staging, tests, releases,
and rollback.

## Current milestone: V0.1 Docker baseline

The repository currently contains a dependency-free Python demo application
with three HTTP endpoints:

| Endpoint | Purpose |
| --- | --- |
| `/` | Human-readable status page with application version |
| `/health` | Machine-readable health status |
| `/version` | Application name and version |

The application runs as an unprivileged user inside the container. Docker
Compose builds the image, publishes port `8080`, and reports the service as
healthy only after the internal health endpoint responds successfully.

## Run locally

Requirements:

- Docker Engine
- Docker Compose

Start the service:

```bash
docker compose up --build --detach --wait
```

Verify it:

```bash
docker compose ps
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/version
```

Stop it:

```bash
docker compose down
```

## Repository structure

```text
.
├── app.py          # Minimal HTTP application
├── VERSION         # Single source of application version
├── Dockerfile      # Reproducible container image
├── compose.yaml    # Runtime configuration and healthcheck
├── .dockerignore   # Minimal Docker build context
└── infra/
    ├── reverse-proxy/ # LAN-only Caddy entrypoint
    ├── portainer/     # Docker management UI
    └── uptime-kuma/   # Availability monitoring
```

## Roadmap

- [x] V0.1: Minimal app, Docker image, Compose, healthcheck, visible version
- [ ] Server foundation: GitHub, reverse proxy, Portainer, monitoring
  - [x] Public GitHub showcase repository
  - [x] LAN-only Caddy reverse proxy
  - [x] Portainer
  - [x] Availability monitoring
- [ ] V0.2: Continuous integration build
- [ ] V0.3: Versioned image in GitHub Container Registry
- [ ] V0.4: Automated staging deployment on the Debian home server
- [ ] V0.5: Integration and API tests
- [ ] V0.6: Headless browser and exploratory tests
- [ ] V0.7: Release gate and rollback

## Security principles

- No credentials, tokens, production data, or private keys belong in Git.
- Containers run without root privileges where practical.
- Development, staging, and production remain separate.
- CI builds immutable images; deployment consumes those artifacts.
- Management interfaces are not exposed publicly without authentication and
  transport encryption.

## Documentation

Architecture decisions, implementation results, incidents, and learnings are
tracked separately in the private project documentation. This repository is the
sanitized, reproducible technical showcase.
