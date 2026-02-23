#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NO_BACKUP="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sdw reset [--no-backup] [--help]

Options:
  --no-backup   Skip creating a backup before resetting runtime data.
  -h, --help    Show this help message.
EOF
}

exit_with_usage_error() {
  local message="$1"
  echo "Error: ${message}" >&2
  echo >&2
  usage >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-backup)
      NO_BACKUP="true"
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      exit_with_usage_error "Unknown option: $1"
      ;;
  esac
done

backup_data() {
  local backup_dir
  backup_dir="${REPO_ROOT}/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "${backup_dir}"

  if [[ -d "${REPO_ROOT}/data/database" ]]; then
    cp -R "${REPO_ROOT}/data/database" "${backup_dir}/database"
  fi
  if [[ -d "${REPO_ROOT}/data/storage_private" ]]; then
    cp -R "${REPO_ROOT}/data/storage_private" "${backup_dir}/storage_private"
  fi
  if [[ -d "${REPO_ROOT}/data/storage_public" ]]; then
    cp -R "${REPO_ROOT}/data/storage_public" "${backup_dir}/storage_public"
  fi

  echo "Backup completed: ${backup_dir}"
}

main() {
  require_command docker
  require_docker_compose
  ensure_env_file
  require_license_file

  if [[ "${NO_BACKUP}" != "true" ]]; then
    backup_data
  fi

  compose down --remove-orphans || true
  rm -rf "${REPO_ROOT}/data"
  ensure_data_dirs

  compose pull
  compose up -d
  compose exec app php artisan migrate --force

  echo "Reset completed for runtime $(runtime_version)."
}

main "$@"
