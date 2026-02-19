#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

main() {
  require_command docker
  require_docker_compose

  ensure_env_file
  ensure_data_dirs
  require_license_file

  local app_key
  app_key="$(read_env_value APP_KEY)"
  if [[ -z "${app_key}" ]]; then
    echo "APP_KEY is empty in .env.docker. Generate and set one before install:"
    echo "  docker compose run --rm app php artisan key:generate --show"
    exit 1
  fi

  compose pull
  compose up -d
  compose exec app php artisan migrate --force

  echo "Install completed for runtime $(runtime_version)."
}

main "$@"
