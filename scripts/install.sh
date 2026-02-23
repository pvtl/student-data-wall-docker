#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sdw install [--help]

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

  require_command docker
  require_command openssl
  require_docker_compose

  ensure_env_file
  ensure_data_dirs
  require_license_file

  local app_key
  app_key="$(read_env_value APP_KEY)"
  if [[ -z "${app_key}" ]]; then
    local generated_app_key tmp_env_file
    generated_app_key="base64:$(openssl rand -base64 32)"
    tmp_env_file="$(mktemp)"

    awk -v new_key="${generated_app_key}" '
      BEGIN {updated = 0}
      /^APP_KEY=/ {
        print "APP_KEY=" new_key
        updated = 1
        next
      }
      { print }
      END {
        if (!updated) {
          print "APP_KEY=" new_key
        }
      }
    ' "${ENV_FILE}" > "${tmp_env_file}"
    mv "${tmp_env_file}" "${ENV_FILE}"
    app_key="${generated_app_key}"
    echo "Generated and saved APP_KEY in .env.docker."
  fi

  compose pull
  compose up -d
  compose exec app php artisan migrate --force

  echo "Install completed for runtime $(runtime_version)."
}

main "$@"
