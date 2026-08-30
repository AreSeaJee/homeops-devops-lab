# Supabase test platform

This directory vendors the official Supabase self-hosting bundle pinned to
`self-hosted/v0.8.0`. The HomeOps-specific override connects only the Envoy API
gateway to the shared reverse-proxy network and removes all direct host ports.

## Access

- Studio and API gateway: `http://supabase.home.arpa`
- Auth API: `http://supabase.home.arpa/auth/v1`
- REST API: `http://supabase.home.arpa/rest/v1`
- Default application redirect: `http://app.home.arpa`

Add `supabase.home.arpa` and `app.home.arpa` to the client hosts file alongside
the existing HomeOps names. Both names resolve to the server LAN address.

## Commands

Run these commands from the repository root:

```bash
docker compose \
  --env-file infra/supabase/.env \
  --file infra/supabase/docker-compose.yml \
  --file infra/supabase/docker-compose.homeops.yml \
  up --detach
```

```bash
docker compose \
  --env-file infra/supabase/.env \
  --file infra/supabase/docker-compose.yml \
  --file infra/supabase/docker-compose.homeops.yml \
  ps
```

The generated `.env` is intentionally ignored. Never commit it: it contains
the database password, dashboard password, signing keys, and privileged API
keys. Frontend code may use only the publishable key. Never expose the secret
or legacy service-role key to a browser.

## Database migrations

The first example migration creates `public.todos`. Every row belongs to an
authenticated user and RLS policies restrict all reads and writes to that
owner. Apply tracked migrations deliberately and record them in the project
documentation.

```bash
docker exec --interactive supabase-db \
  psql --username postgres --dbname postgres \
  < infra/supabase/migrations/001_webapp_todos.sql
```

## Version and updates

The vendored files originate from Supabase tag `self-hosted/v0.8.0`. Review the
official changelog and update guide before changing that version. Back up the
database and storage data before every update.
