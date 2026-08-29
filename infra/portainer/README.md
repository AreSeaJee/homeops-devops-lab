# Portainer CE

Portainer provides a web interface for the local Docker Engine. It has no
published host ports and is reachable only through Caddy at
`http://portainer.home.arpa` inside the home network.

## Deploy

The external network `homeops-proxy` and the reverse proxy must already exist.

```bash
docker compose --file infra/portainer/compose.yaml up --detach
docker compose --file infra/reverse-proxy/compose.yaml restart caddy
```

Open `http://portainer.home.arpa` and create the initial administrator account.
Use a unique password that is not stored in this repository. Then select the
local Docker environment.

The `--trusted-origins` option is restricted to the LAN hostname. Caddy uses
Portainer's internal HTTP endpoint on the isolated Docker network. This matches
the LAN-only HTTP entrypoint and prevents `Secure` session cookies from being
dropped by browsers before local TLS is introduced.

## Security boundary

The Docker socket gives Portainer extensive control over the host's containers,
volumes, networks, and mounted host paths. For that reason:

- Portainer has no direct host port.
- The Edge Agent tunnel port is not enabled.
- Access remains restricted to the trusted LAN reverse proxy.
- The administrator password must be unique and strong.
- Portainer data is stored in the named volume `portainer_data` and must be
  included in the backup plan.
