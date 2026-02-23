#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_VERSION=""
LATEST_RELEASE_API="https://api.github.com/repos/pvtl/student-data-wall-docker/releases/latest"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sdw update [--target <version|latest>] [--help]

Options:
  --target <value>   Update to a specific runtime version (for example: v0.1.0)
                     or resolve the latest runtime release with "latest".
  -h, --help         Show this help message.

Examples:
  ./scripts/sdw update
  ./scripts/sdw update --target latest
  ./scripts/sdw update --target v0.1.0
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
    --target)
      TARGET_VERSION="${2:-}"
      if [[ -z "${TARGET_VERSION}" || "${TARGET_VERSION}" == -* ]]; then
        exit_with_usage_error "Missing value for --target."
      fi
      shift 2
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

resolve_latest_target_version() {
  local response auth_args=() resolved_target

  require_command curl

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  if ! response="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${auth_args[@]}" \
    "${LATEST_RELEASE_API}")"; then
    echo "Failed to resolve latest runtime release from GitHub." >&2
    echo "You can still run with an explicit target: ./scripts/sdw update --target vX.Y.Z" >&2
    exit 1
  fi

  resolved_target="$(
    printf '%s' "${response}" \
      | tr -d '\n' \
      | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
  )"

  if [[ -z "${resolved_target}" ]]; then
    echo "Unable to parse latest runtime tag from GitHub response." >&2
    exit 1
  fi

  printf '%s\n' "${resolved_target}"
}

resolve_target_version() {
  local requested_target="$1"

  if [[ -z "${requested_target}" || "${requested_target}" == "latest" ]]; then
    resolve_latest_target_version
    return 0
  fi

  printf '%s\n' "${requested_target}"
}

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
  local requested_target="$1"
  local normalized_target normalized_runtime_version target_image

  if [[ ! "${requested_target}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
    exit_with_usage_error "Invalid target value: ${requested_target}"
  fi

  normalized_runtime_version="${requested_target}"
  if [[ "${normalized_runtime_version}" != v* ]]; then
    normalized_runtime_version="v${normalized_runtime_version}"
  fi

  normalized_target="${normalized_runtime_version#v}"
  if [[ -z "${normalized_target}" || "${normalized_target}" == "${normalized_runtime_version}" ]]; then
    exit_with_usage_error "Invalid target value: ${requested_target}"
  fi

  target_image="ghcr.io/pvtl/student-data-wall-docker:${normalized_target}"
  set_env_value "APP_IMAGE" "${target_image}"
  set_env_value "RUNTIME_VERSION" "${normalized_runtime_version}"

  echo "Set APP_IMAGE to ${target_image}"
  echo "Set RUNTIME_VERSION to ${normalized_runtime_version}"
}

main() {
  local requested_target resolved_target

  require_command docker
  require_docker_compose
  ensure_env_file
  ensure_data_dirs
  require_license_file

  requested_target="${TARGET_VERSION:-latest}"
  if [[ -n "${TARGET_VERSION}" ]]; then
    echo "Requested target version: ${TARGET_VERSION}"
  else
    echo "No --target provided. Resolving latest runtime release."
  fi

  resolved_target="$(resolve_target_version "${requested_target}")"
  echo "Using target version: ${resolved_target}"
  apply_target_version "${resolved_target}"

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
