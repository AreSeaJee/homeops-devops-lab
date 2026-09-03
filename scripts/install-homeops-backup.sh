#!/usr/bin/env bash
set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if (( EUID != 0 )); then
  printf 'Run with sudo: sudo %s\n' "$0" >&2
  exit 1
fi

install -d -m 700 /mnt/backup/docker/homeops
install -m 644 "${PROJECT_ROOT}/deploy/systemd/homeops-backup.service" \
  /etc/systemd/system/homeops-backup.service
install -m 644 "${PROJECT_ROOT}/deploy/systemd/homeops-backup.timer" \
  /etc/systemd/system/homeops-backup.timer

systemctl daemon-reload
systemctl enable --now homeops-backup.timer
systemctl start homeops-backup.service

printf '\nBackup installed and initial run completed.\n'
systemctl --no-pager status homeops-backup.timer
systemctl --no-pager status homeops-backup.service

