# Uptime Kuma

Uptime Kuma provides availability monitoring for services in the HomeOps lab.
It has no published host port and is reachable only through Caddy at
`http://status.home.arpa` inside the home network or its VPN.

## Deploy

The external network `homeops-proxy` and the reverse proxy must already exist.

```bash
docker compose --file infra/uptime-kuma/compose.yaml up --detach
docker compose --file infra/reverse-proxy/compose.yaml exec caddy \
  caddy reload --config /etc/caddy/Caddyfile
```

Open `http://status.home.arpa` and create the initial administrator account.
Use a unique password that is not stored in this repository.

## Initial monitors

Create HTTP monitors for these Docker-network addresses:

| Name | URL | Expected result |
| --- | --- | --- |
| Demo health | `http://homeops-demo:8080/health` | HTTP 200 |
| Portainer UI | `http://portainer:9000/` | HTTP 200 |

The internal addresses test the applications directly. A later external-path
monitor can additionally verify DNS/VPN and Caddy from another device.

## Security and persistence

- No host port is published for port `3001`.
- Uptime Kuma does not receive the Docker socket.
- Application data is stored in the local named volume `uptime_kuma_data`.
- The data volume must be included in the backup plan.
