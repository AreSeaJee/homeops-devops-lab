#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
compose_file="$repository_root/deploy/compose.yaml"
tag=${1:-latest}

case "$tag" in
  *[!A-Za-z0-9_.-]*|'')
    echo "Invalid image tag: $tag" >&2
    exit 2
    ;;
esac

export HOMEOPS_IMAGE=${HOMEOPS_IMAGE:-ghcr.io/areseajee/homeops-devops-lab}
export HOMEOPS_TAG=$tag

echo "Deploying $HOMEOPS_IMAGE:$HOMEOPS_TAG"
docker compose --project-name devops-setup --file "$compose_file" pull
docker compose --project-name devops-setup --file "$compose_file" up --detach --wait

actual_version=$(curl --fail --silent --show-error http://127.0.0.1:8080/version)
echo "Deployment healthy: $actual_version"
