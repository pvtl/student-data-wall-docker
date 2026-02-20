#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"
ENV_FILE="${REPO_ROOT}/.env.docker"
ENV_EXAMPLE_FILE="${REPO_ROOT}/.env.docker.example"
VERSION_FILE="${REPO_ROOT}/VERSION"
LICENSE_FILE="${REPO_ROOT}/license/license.lic"

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    return 1
  fi
}

require_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    return 0
  fi
  echo "Docker Compose v2 plugin is required (docker compose)." >&2
  return 1
}

ensure_env_file() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE} from template."
  fi

  ensure_required_env_key "APP_IMAGE"
  normalize_app_image_tag
}

ensure_required_env_key() {
  local key="$1"
  local current_value default_value tmp_env_file

  current_value="$(read_env_value "${key}" "${ENV_FILE}" || true)"
  if [[ -n "${current_value}" ]]; then
    return 0
  fi

  default_value="$(read_env_value "${key}" "${ENV_EXAMPLE_FILE}" || true)"
  if [[ -z "${default_value}" ]]; then
    echo "Missing required env key ${key} in ${ENV_FILE} and no default in ${ENV_EXAMPLE_FILE}." >&2
    return 1
  fi

  tmp_env_file="$(mktemp)"
  awk -F= -v k="${key}" -v v="${default_value}" '
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
  ' "${ENV_FILE}" > "${tmp_env_file}"
  mv "${tmp_env_file}" "${ENV_FILE}"

  echo "Set ${key} in .env.docker from template."
}

normalize_app_image_tag() {
  local current_value normalized_value tmp_env_file

  current_value="$(read_env_value "APP_IMAGE" "${ENV_FILE}" || true)"
  if [[ -z "${current_value}" ]]; then
    return 0
  fi

  normalized_value="$(printf '%s' "${current_value}" | sed -E 's#^(ghcr\.io/pvtl/student-data-wall-docker:)v([0-9].*)$#\1\2#')"
  if [[ "${normalized_value}" == "${current_value}" ]]; then
    return 0
  fi

  tmp_env_file="$(mktemp)"
  awk -F= -v k="APP_IMAGE" -v v="${normalized_value}" '
    $1 == k {
      print k "=" v
      next
    }
    { print }
  ' "${ENV_FILE}" > "${tmp_env_file}"
  mv "${tmp_env_file}" "${ENV_FILE}"

  echo "Normalized APP_IMAGE tag format in .env.docker: ${normalized_value}"
}

ensure_data_dirs() {
  mkdir -p \
    "${REPO_ROOT}/data/database" \
    "${REPO_ROOT}/data/storage_private" \
    "${REPO_ROOT}/data/storage_public"
  touch "${REPO_ROOT}/data/database/database.sqlite"
}

require_license_file() {
  if [[ ! -f "${LICENSE_FILE}" ]]; then
    echo "Missing license file: ${LICENSE_FILE}" >&2
    echo "Place your per-device license at license/license.lic before running this command." >&2
    return 1
  fi
}

read_env_value() {
  local key="$1"
  local file="${2:-${ENV_FILE}}"
  awk -F= -v k="${key}" '$1 == k {print substr($0, index($0, "=") + 1); exit}' "${file}"
}

compose() {
  local app_image
  app_image="$(read_env_value "APP_IMAGE" "${ENV_FILE}" || true)"
  APP_IMAGE="${app_image}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

runtime_version() {
  if [[ -f "${VERSION_FILE}" ]]; then
    tr -d '[:space:]' < "${VERSION_FILE}"
  else
    echo "unknown"
  fi
}
