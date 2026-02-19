#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_VERSION="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

main() {
  require_command docker
  require_docker_compose
  ensure_env_file
  ensure_data_dirs
  require_license_file

  if [[ -n "${TARGET_VERSION}" ]]; then
    echo "Requested target version: ${TARGET_VERSION}"
    echo "Check out that tag in this repo before running update."
  fi

  compose pull
  compose up -d
  compose exec app php artisan migrate --force

  if compose exec app php artisan about >/dev/null 2>&1; then
    echo "Health check passed."
  else
    echo "Warning: health check command failed." >&2
  fi

  echo "Update completed for runtime $(runtime_version)."
}

main "$@"
