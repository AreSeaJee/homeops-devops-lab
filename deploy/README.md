# Pull-based deployment

GitHub Actions builds and publishes the application image. The home server only
pulls that artifact; it does not execute repository code received from pull
requests through a permanent self-hosted runner.

Deploy the current main image:

```bash
./scripts/deploy.sh latest
```

Deploy an immutable commit image:

```bash
./scripts/deploy.sh sha-0123456789ab
```

Deploy a release after a matching Git tag has been published:

```bash
./scripts/deploy.sh 0.1.0
```

The script pulls the selected image, reconciles the existing `devops-setup`
Compose project, waits for Docker's healthcheck, and verifies `/version`.

The GHCR package should remain public for anonymous pulls. If it is private,
authenticate Docker once with a read-only package token; never store that token
in this repository.
