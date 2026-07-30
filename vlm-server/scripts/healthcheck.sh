#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_DIR}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${PROJECT_DIR}/.env"
  set +a
fi

VLLM_BASE_URL="${VLLM_BASE_URL:-http://127.0.0.1:8000/v1}"

curl --fail --silent --show-error "${VLLM_BASE_URL}/models"
echo

