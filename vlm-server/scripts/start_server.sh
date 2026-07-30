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

RUN_DIR="${RUN_DIR:-${PROJECT_DIR}/run}"
LOG_DIR="${LOG_DIR:-${PROJECT_DIR}/logs}"
PID_FILE="${PID_FILE:-${RUN_DIR}/vlm-server.pid}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/vlm-server.log}"
MODE="${1:-foreground}"

mkdir -p "${RUN_DIR}" "${LOG_DIR}"

is_running() {
  [ -f "${PID_FILE}" ] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1
}

case "${MODE}" in
  foreground)
    exec "${SCRIPT_DIR}/start_vllm.sh"
    ;;
  background)
    if is_running; then
      echo "vlm-server is already running with pid $(cat "${PID_FILE}")"
      exit 0
    fi
    nohup "${SCRIPT_DIR}/start_vllm.sh" >"${LOG_FILE}" 2>&1 &
    echo "$!" >"${PID_FILE}"
    echo "started vlm-server pid=$(cat "${PID_FILE}") log=${LOG_FILE}"
    ;;
  status)
    if is_running; then
      echo "running pid=$(cat "${PID_FILE}") log=${LOG_FILE}"
    else
      echo "stopped"
      exit 1
    fi
    ;;
  stop)
    if is_running; then
      kill "$(cat "${PID_FILE}")"
      echo "stopped pid=$(cat "${PID_FILE}")"
      rm -f "${PID_FILE}"
    else
      echo "stopped"
    fi
    ;;
  *)
    echo "Usage: $0 {foreground|background|status|stop}" >&2
    exit 2
    ;;
esac

