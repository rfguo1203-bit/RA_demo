#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../_shared/common.sh
source "$SKILLS_DIR/_shared/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  run_task.sh <task> [--k K] [--max-rounds N]
USAGE
}

json_get() {
  local json="$1"
  local key="$2"
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); value=data.get(sys.argv[2]); print("" if value is None else value)' "$json" "$key"
}

json_get_bool() {
  local json="$1"
  local key="$2"
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print("true" if bool(data.get(sys.argv[2])) else "false")' "$json" "$key"
}

stop_owned_servers() {
  "$SKILLS_DIR/behavior-env-server/scripts/env_server.sh" stop "$TASK_NAME" >/dev/null 2>&1 || true
  "$SKILLS_DIR/behavior-vla-server/scripts/vla_server.sh" stop "$TASK_NAME" >/dev/null 2>&1 || true
}

print_final_json() {
  local json="$1"
  local ok_override="${2:-}"
  local error="${3:-}"
  local run_dir="${RUN_DIR:-}"
  python3 -c '
import json, sys
data = json.loads(sys.argv[1])
ok_override, error, run_dir, k, max_rounds, rounds = sys.argv[2:8]
if ok_override:
    data["ok"] = ok_override == "true"
if error:
    data["error"] = error
if run_dir:
    data.setdefault("run_dir", run_dir)
    data.setdefault("server_log", f"{run_dir}/vla_server.log")
    data.setdefault("env_log", f"{run_dir}/env_server.log")
data["k_steps"] = int(k)
data["max_host_rounds"] = int(max_rounds)
data["host_rounds"] = int(rounds)
print(json.dumps(data))
' "$json" "$ok_override" "$error" "$run_dir" "$k" "$max_rounds" "$round"
}

task_arg="${1:-}"
[[ -n "$task_arg" ]] || { usage; exit 2; }
shift
resolve_task_config "$task_arg"

k="$K_STEPS"
max_rounds="$MAX_HOST_ROUNDS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --k)
      k="${2:-}"
      shift 2
      ;;
    --max-rounds)
      max_rounds="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ "$k" =~ ^[0-9]+$ && "$k" -gt 0 ]] || { json_error "$TASK_NAME" "K must be a positive integer"; exit 1; }
[[ "$max_rounds" =~ ^[0-9]+$ && "$max_rounds" -gt 0 ]] || { json_error "$TASK_NAME" "max rounds must be a positive integer"; exit 1; }
require_command python3
round=0

vla_json="$("$SKILLS_DIR/behavior-vla-server/scripts/vla_server.sh" start "$TASK_NAME")" || {
  printf '%s\n' "$vla_json"
  exit 1
}
if [[ "$(json_get_bool "$vla_json" ok)" != "true" ]]; then
  printf '%s\n' "$vla_json"
  exit 1
fi
load_current_session || true

env_json="$("$SKILLS_DIR/behavior-env-server/scripts/env_server.sh" start "$TASK_NAME")" || {
  stop_owned_servers
  printf '%s\n' "$env_json"
  exit 1
}
if [[ "$(json_get_bool "$env_json" ok)" != "true" ]]; then
  stop_owned_servers
  printf '%s\n' "$env_json"
  exit 1
fi
load_current_session || true

last_json="$env_json"
while (( round < max_rounds )); do
  round=$((round + 1))
  step_json="$("$SKILLS_DIR/behavior-k-step/scripts/step_k.sh" "$TASK_NAME" --k "$k")" || {
    stop_owned_servers
    printf '%s\n' "$step_json"
    exit 1
  }
  last_json="$step_json"

  if [[ "$(json_get_bool "$step_json" ok)" != "true" ]]; then
    stop_owned_servers
    printf '%s\n' "$step_json"
    exit 1
  fi

  if [[ "$(json_get_bool "$step_json" success)" == "true" ]]; then
    stop_owned_servers
    print_final_json "$step_json"
    exit 0
  fi

  if [[ "$(json_get_bool "$step_json" done)" == "true" ]]; then
    stop_owned_servers
    print_final_json "$step_json"
    exit 1
  fi
done

stop_owned_servers
print_final_json "$last_json" false "Task did not finish within ${max_rounds} host rounds."
exit 1
