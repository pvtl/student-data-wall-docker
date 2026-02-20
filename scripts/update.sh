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

set_env_value() {
  local key="$1"
  local value="$2"
  local target_file="${3:-${ENV_FILE}}"
  local tmp_env_file

  tmp_env_file="$(mktemp)"
  awk -F= -v k="${key}" -v v="${value}" '
    BEGIN {updated = 0}
    $1 == k {
      print k "=" v
      updated = 1
      next
    }
    { print }
    END {
      if (!updated) {
        print k "=" v
      }
    }
  ' "${target_file}" > "${tmp_env_file}"
  mv "${tmp_env_file}" "${target_file}"
}

apply_target_version() {
  local normalized_target normalized_runtime_version target_image

  normalized_runtime_version="${TARGET_VERSION}"
  if [[ "${normalized_runtime_version}" != v* ]]; then
    normalized_runtime_version="v${normalized_runtime_version}"
  fi

  normalized_target="${normalized_runtime_version#v}"
  if [[ -z "${normalized_target}" || "${normalized_target}" == "${normalized_runtime_version}" ]]; then
    echo "Invalid --target value: ${TARGET_VERSION}" >&2
    exit 1
  fi

  target_image="ghcr.io/pvtl/student-data-wall-docker:${normalized_target}"
  set_env_value "APP_IMAGE" "${target_image}"
  set_env_value "RUNTIME_VERSION" "${normalized_runtime_version}"

  echo "Set APP_IMAGE to ${target_image}"
  echo "Set RUNTIME_VERSION to ${normalized_runtime_version}"
}

main() {
  require_command docker
  require_docker_compose
  ensure_env_file
  ensure_data_dirs
  require_license_file

  if [[ -n "${TARGET_VERSION}" ]]; then
    echo "Requested target version: ${TARGET_VERSION}"
    apply_target_version
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
