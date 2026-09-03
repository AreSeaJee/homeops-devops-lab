# HomeOps backups

HomeOps writes independent backups to `/mnt/backup/docker/homeops`. Nextcloud is
not included because Nextcloud AIO manages its own Borg repository in
`/mnt/backup/nextcloud-aio/borg`.

## Contents

Each completed snapshot contains:

- PostgreSQL globals and custom-format dumps of the `postgres` and `_supabase`
  databases;
- Supabase Storage objects and its persistent database configuration volume;
- the local HomeOps runtime configuration, including secret `.env` files;
- consistent volume archives for Portainer and Uptime Kuma;
- Caddy's certificate and runtime-state volumes;
- a manifest and SHA-256 checksums.

Before a snapshot is published, the job validates every PostgreSQL custom dump
with `pg_restore --list`, tests gzip streams, lists every tar archive, and then
verifies all SHA-256 checksums. An incomplete or unreadable snapshot is removed.

The backup directory is root-only because `configuration.tar.gz` contains local
secrets. It must never be committed or copied to a public location. The ext4
disk is not encrypted at rest; physical access to it must therefore be treated
as privileged access.

## Schedule and retention

The system timer starts nightly at 03:15 with a randomized delay of up to 15
minutes. It retains seven daily, four Sunday, and six first-of-month snapshots.
Weekly and monthly snapshots use hard links, so promotion does not duplicate
file contents.

```bash
sudo systemctl status homeops-backup.timer
sudo systemctl list-timers homeops-backup.timer
sudo journalctl -u homeops-backup.service
```

Run a backup manually:

```bash
sudo systemctl start homeops-backup.service
sudo journalctl -u homeops-backup.service --since today
```

Install the service and execute its initial backup:

```bash
sudo ./scripts/install-homeops-backup.sh
```

Verify the newest snapshot without restoring it:

```bash
latest="$(sudo find /mnt/backup/docker/homeops/daily -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
sudo sh -c "cd '${latest}' && sha256sum --check SHA256SUMS"
```

## Restore outline

Restores are deliberately manual so an automated job cannot overwrite live
data. Stop affected services first and copy the selected snapshot away from the
backup disk before making changes.

1. Reinstall Docker and clone the two Git repositories.
2. Extract `configuration.tar.gz` at `/` and review every path before replacing
   existing files.
3. Start Supabase with an empty data directory.
4. Restore `globals.sql.gz`, followed by `_supabase.dump` and `postgres.dump`
   using `pg_restore`. Use `--clean --if-exists` only after checking the target.
5. Extract `supabase-storage.tar.gz` into
   `infra/supabase/volumes/` while the Storage service is stopped.
6. Restore the named-volume archives only while their containers are stopped.
7. Start services and verify container health, login, database row counts, and
   a private Storage object.

Before relying on a new backup format, perform a restore into isolated temporary
containers. A checksum test proves readability, but only a restore test proves
recoverability.
