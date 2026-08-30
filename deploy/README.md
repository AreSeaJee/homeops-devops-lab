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
Compose project, waits for Docker's healthcheck, and verifies `/version`. Before
an update it tags the currently healthy image as `rollback`. If the replacement
does not become healthy, the script immediately restores that local image.

Concurrent deployments are prevented with a non-blocking file lock.

## Automatic staging updates

The user-level systemd timer checks `latest` approximately every five minutes.
If GHCR still points to the image currently running, the script exits without
recreating the container.

Install and activate it as the normal server user:

```bash
mkdir -p ~/.config/systemd/user
cp deploy/systemd/homeops-demo-update.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now homeops-demo-update.timer
```

Allow the user service manager to run after SSH logout (one-time root action):

```bash
sudo loginctl enable-linger "$USER"
```

Inspect the timer and recent deployment logs:

```bash
systemctl --user list-timers homeops-demo-update.timer
journalctl --user --unit homeops-demo-update.service --lines 50
```

The GHCR package should remain public for anonymous pulls. If it is private,
authenticate Docker once with a read-only package token; never store that token
in this repository.
