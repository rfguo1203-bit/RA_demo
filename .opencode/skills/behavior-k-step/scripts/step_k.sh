#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../_shared/common.sh
source "$SKILLS_DIR/_shared/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  step_k.sh <task> [--k K]
USAGE
}

task_arg="${1:-}"
[[ -n "$task_arg" ]] || { usage; exit 2; }
shift
resolve_task_config "$task_arg"

k="$K_STEPS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --k)
      k="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ "$k" =~ ^[0-9]+$ && "$k" -gt 0 ]] || { json_error "$TASK_NAME" "K must be a positive integer"; exit 1; }
require_command curl

if ! load_current_session; then
  json_error "$TASK_NAME" "No current session. Start behavior-env-server first."
  exit 1
fi

curl -fsS -X POST -H 'Content-Type: application/json' \
  --data "{\"k\":$k}" \
  "http://${ENV_SERVER_HOST}:${ENV_SERVER_PORT}/session/step" || {
    json_error "$TASK_NAME" "Failed to call Env server step endpoint" "${RUN_DIR:-}"
    exit 1
  }
printf '\n'
