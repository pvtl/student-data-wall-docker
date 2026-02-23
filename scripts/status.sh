#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sdw status [--help]

Options:
  -h, --help   Show this help message.
EOF
}

exit_with_usage_error() {
  local message="$1"
  echo "Error: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        exit_with_usage_error "Unknown option: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

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
