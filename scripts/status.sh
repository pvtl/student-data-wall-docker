#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
  ensure_env_file
  local image_ref
  image_ref="$(read_env_value APP_IMAGE "${ENV_FILE}")"

  echo "Runtime version: $(runtime_version)"
  echo "Configured image: ${image_ref:-unset}"
  echo

  echo "Docker version:"
  docker --version || true
  echo

  echo "Docker Compose version:"
  docker compose version || true
  echo

  echo "Container status:"
  compose ps || true
  echo

  echo "Migration status:"
  compose exec app php artisan migrate:status --no-interaction || true
  echo

  echo "Recent app logs:"
  compose logs --tail=20 app || true
}

main "$@"
