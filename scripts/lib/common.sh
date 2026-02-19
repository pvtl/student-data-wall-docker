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
}

ensure_data_dirs() {
  mkdir -p "${REPO_ROOT}/data/database" "${REPO_ROOT}/data/storage"
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
  docker compose -f "${COMPOSE_FILE}" "$@"
}

runtime_version() {
  if [[ -f "${VERSION_FILE}" ]]; then
    tr -d '[:space:]' < "${VERSION_FILE}"
  else
    echo "unknown"
  fi
}
