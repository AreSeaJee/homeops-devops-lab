#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compose_file="$repository_root/deploy/compose.yaml"
tag=${1:-latest}
lock_file=${XDG_RUNTIME_DIR:-/tmp}/homeops-demo-deploy.lock

case "$tag" in
  *[!A-Za-z0-9_.-]*|'')
    echo "Invalid image tag: $tag" >&2
    exit 2
    ;;
esac

export HOMEOPS_IMAGE=${HOMEOPS_IMAGE:-ghcr.io/areseajee/homeops-devops-lab}
export HOMEOPS_TAG=$tag

exec 9>"$lock_file"
if ! flock --nonblock 9; then
  echo "Another deployment is already running; skipping."
  exit 0
fi

compose() {
  docker compose --project-name devops-setup --file "$compose_file" "$@"
}

echo "Deploying $HOMEOPS_IMAGE:$HOMEOPS_TAG"
current_container=$(compose ps --quiet homeops-demo)
current_image_id=
if [ -n "$current_container" ]; then
  current_image_id=$(docker inspect --format '{{.Image}}' "$current_container")
fi

compose pull
target_image_id=$(docker image inspect --format '{{.Id}}' "$HOMEOPS_IMAGE:$HOMEOPS_TAG")

if [ -n "$current_image_id" ] && [ "$current_image_id" = "$target_image_id" ]; then
  actual_version=$(curl --fail --silent --show-error http://127.0.0.1:8080/version)
  echo "Already running selected image: $actual_version"
  exit 0
fi

if [ -n "$current_image_id" ]; then
  docker image tag "$current_image_id" "$HOMEOPS_IMAGE:rollback"
fi

if compose up --detach --wait; then
  if actual_version=$(curl --fail --silent --show-error http://127.0.0.1:8080/version); then
    echo "Deployment healthy: $actual_version"
    exit 0
  fi
fi

echo "Deployment failed health verification." >&2

if [ -z "$current_image_id" ]; then
  echo "No previous healthy image is available for rollback." >&2
  exit 1
fi

echo "Rolling back to the previously running image." >&2
HOMEOPS_TAG=rollback
export HOMEOPS_TAG
compose up --detach --wait

actual_version=$(curl --fail --silent --show-error http://127.0.0.1:8080/version)
echo "Rollback healthy: $actual_version" >&2
exit 1
