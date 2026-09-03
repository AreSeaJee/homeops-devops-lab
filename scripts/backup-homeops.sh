#!/usr/bin/env bash
set -Eeuo pipefail

readonly BACKUP_MOUNT="${BACKUP_MOUNT:-/mnt/backup}"
readonly BACKUP_ROOT="${BACKUP_ROOT:-${BACKUP_MOUNT}/docker/homeops}"
readonly DEVOPS_ROOT="${DEVOPS_ROOT:-/home/areseajee/Documents/Devops-Setup}"
readonly FORGE_ROOT="${FORGE_ROOT:-/home/areseajee/Documents/forge-of-becoming}"
readonly TIMESTAMP="$(date --utc +%Y%m%dT%H%M%SZ)"
readonly DAILY_ROOT="${BACKUP_ROOT}/daily"
readonly STAGING_DIR="${BACKUP_ROOT}/.incomplete-${TIMESTAMP}"
readonly FINAL_DIR="${DAILY_ROOT}/${TIMESTAMP}"

stopped_containers=()

log() {
  printf '[homeops-backup] %s\n' "$*"
}

cleanup() {
  local exit_code=$?
  local container

  for container in "${stopped_containers[@]:-}"; do
    if [[ -n "${container}" ]]; then
      docker start "${container}" >/dev/null || true
    fi
  done

  if (( exit_code != 0 )); then
    rm -rf -- "${STAGING_DIR}"
    log "FAILED (exit ${exit_code})"
  fi
}
trap cleanup EXIT

require_root() {
  if (( EUID != 0 )); then
    log "Run this script as root."
    exit 1
  fi
}

verify_destination() {
  mountpoint --quiet "${BACKUP_MOUNT}" || {
    log "Backup disk is not mounted at ${BACKUP_MOUNT}."
    exit 1
  }

  findmnt --noheadings --output OPTIONS --target "${BACKUP_MOUNT}" | grep --quiet --word-regexp rw || {
    log "Backup disk is not writable."
    exit 1
  }
}

archive_volume() {
  local volume=$1
  local output=$2
  local mountpoint_path

  mountpoint_path="$(docker volume inspect --format '{{ .Mountpoint }}' "${volume}")"
  tar --create --gzip --file "${output}" --directory "${mountpoint_path}" .
}

stop_for_snapshot() {
  local container=$1

  if [[ "$(docker inspect --format '{{.State.Running}}' "${container}" 2>/dev/null || true)" == "true" ]]; then
    docker stop --time 30 "${container}" >/dev/null
    stopped_containers+=("${container}")
  fi
}

promote_snapshot() {
  local period=$1
  local keep=$2
  local period_root="${BACKUP_ROOT}/${period}"
  local promoted="${period_root}/${TIMESTAMP}"

  mkdir -p -- "${period_root}"
  cp --archive --link "${FINAL_DIR}" "${promoted}"
  find "${period_root}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort --reverse \
    | tail --lines "+$((keep + 1))" \
    | while IFS= read -r old_snapshot; do
        [[ -z "${old_snapshot}" ]] || rm -rf -- "${period_root}/${old_snapshot}"
      done
}

prune_daily() {
  find "${DAILY_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort --reverse \
    | tail --lines '+8' \
    | while IFS= read -r old_snapshot; do
        [[ -z "${old_snapshot}" ]] || rm -rf -- "${DAILY_ROOT}/${old_snapshot}"
      done
}

require_root
verify_destination
command -v docker >/dev/null

umask 077
mkdir -p -- "${DAILY_ROOT}" "${STAGING_DIR}/database" "${STAGING_DIR}/volumes"

log "Dumping Supabase databases."
docker exec supabase-db pg_dumpall --username postgres --globals-only \
  | gzip --best > "${STAGING_DIR}/database/globals.sql.gz"

while IFS= read -r database; do
  [[ -z "${database}" ]] && continue
  docker exec supabase-db pg_dump --username postgres --format=custom --dbname "${database}" \
    > "${STAGING_DIR}/database/${database}.dump"
done < <(
  docker exec supabase-db psql --username postgres --dbname postgres --tuples-only --no-align \
    --command "select datname from pg_database where datallowconn and not datistemplate order by datname"
)

log "Archiving Supabase Storage and runtime configuration."
tar --create --gzip --file "${STAGING_DIR}/supabase-storage.tar.gz" \
  --directory "${DEVOPS_ROOT}/infra/supabase/volumes" storage
archive_volume supabase_db-config "${STAGING_DIR}/volumes/supabase_db-config.tar.gz"
archive_volume reverse-proxy_caddy_data "${STAGING_DIR}/volumes/caddy_data.tar.gz"
archive_volume reverse-proxy_caddy_config "${STAGING_DIR}/volumes/caddy_config.tar.gz"

tar --create --gzip --file "${STAGING_DIR}/configuration.tar.gz" \
  --directory / \
  "etc/fstab" \
  "home/areseajee/Documents/Devops-Setup/compose.yaml" \
  "home/areseajee/Documents/Devops-Setup/deploy" \
  "home/areseajee/Documents/Devops-Setup/infra/portainer" \
  "home/areseajee/Documents/Devops-Setup/infra/reverse-proxy" \
  "home/areseajee/Documents/Devops-Setup/infra/supabase/.env" \
  "home/areseajee/Documents/Devops-Setup/infra/supabase/docker-compose.yml" \
  "home/areseajee/Documents/Devops-Setup/infra/supabase/docker-compose.homeops.yml" \
  "home/areseajee/Documents/Devops-Setup/infra/uptime-kuma" \
  "home/areseajee/Documents/forge-of-becoming/compose.staging.yaml"

log "Taking short, consistent snapshots of Portainer and Uptime Kuma."
stop_for_snapshot portainer-portainer-1
stop_for_snapshot uptime-kuma-uptime-kuma-1
archive_volume portainer_portainer_data "${STAGING_DIR}/volumes/portainer_data.tar.gz"
archive_volume uptime-kuma_uptime_kuma_data "${STAGING_DIR}/volumes/uptime-kuma_data.tar.gz"

for container in "${stopped_containers[@]:-}"; do
  [[ -z "${container}" ]] || docker start "${container}" >/dev/null
done
stopped_containers=()

cat > "${STAGING_DIR}/manifest.txt" <<EOF
created_utc=${TIMESTAMP}
hostname=$(hostname --fqdn 2>/dev/null || hostname)
supabase_container=$(docker inspect --format '{{.Config.Image}}' supabase-db)
forge_container=$(docker inspect --format '{{.Config.Image}}' forge-of-becoming 2>/dev/null || printf 'not-running')
retention=7-daily,4-weekly,6-monthly
EOF

log "Verifying dump and archive readability."
gzip --test "${STAGING_DIR}/database/globals.sql.gz"
while IFS= read -r dump_file; do
  docker exec --interactive supabase-db pg_restore --list < "${dump_file}" >/dev/null
done < <(find "${STAGING_DIR}/database" -maxdepth 1 -type f -name '*.dump' -print)
while IFS= read -r archive_file; do
  tar --list --gzip --file "${archive_file}" >/dev/null
done < <(find "${STAGING_DIR}" -type f -name '*.tar.gz' -print)

(
  cd "${STAGING_DIR}"
  find . -type f ! -name SHA256SUMS -print0 | sort --zero-terminated | xargs --null sha256sum > SHA256SUMS
  sha256sum --check SHA256SUMS >/dev/null
)

mv -- "${STAGING_DIR}" "${FINAL_DIR}"
chmod -R go-rwx "${BACKUP_ROOT}"

if [[ "$(date +%u)" == "7" ]]; then
  promote_snapshot weekly 4
fi
if [[ "$(date +%d)" == "01" ]]; then
  promote_snapshot monthly 6
fi
prune_daily

log "Backup completed: ${FINAL_DIR}"
