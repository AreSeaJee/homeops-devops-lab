# LAN reverse proxy

Caddy provides a single HTTP entrypoint for services in the home network. It
binds only to the configured LAN address and reaches application containers
through the external Docker network `homeops-proxy`.

## Local setup

Create the shared network once:

```bash
docker network create homeops-proxy
```

Create the local environment file and adjust the address if necessary:

```bash
cp .env.example .env
```

Start the application stack first, followed by the proxy:

```bash
docker compose up --build --detach --wait
docker compose --file infra/reverse-proxy/compose.yaml up --detach --wait
```

## Local name resolution

The home router or local DNS server should map this hostname to the Debian
server's LAN address:

```text
192.168.178.170 demo.home.arpa portainer.home.arpa status.home.arpa supabase.home.arpa app.home.arpa
```

For a single client, the same entry can temporarily be added to its hosts file.

Verify the route without changing DNS:

```bash
curl --resolve demo.home.arpa:80:192.168.178.170 \
  http://demo.home.arpa/health
```

Once the Forge of Becoming staging container is attached to `homeops-proxy`,
verify its route with:

```bash
curl --resolve app.home.arpa:80:192.168.178.170 \
  http://app.home.arpa/api/health
```

This baseline intentionally uses unencrypted HTTP inside the trusted LAN.
Public exposure, port forwarding, and public TLS are out of scope for this
stage.
