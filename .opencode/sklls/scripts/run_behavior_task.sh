#!/usr/bin/env bash
export NO_PROXY=127.0.0.1,localhost,127.0.1.1,robots
export no_proxy=$NO_PROXY

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${BEHAVIOR_RUNNER_CONFIG:-$SKILL_DIR/config.sh}"
MODE="run"

usage() {
  cat <<'USAGE'
Usage:
  run_behavior_task.sh [--dry-run] turning_on_radio

Environment:
  BEHAVIOR_RUNNER_CONFIG  Optional path to a config.sh file.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

quote_command() {
  printf '%q ' "$@"
  printf '\n'
}

port_is_open() {
  local host="$1"
  local port="$2"
  timeout 1 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

server_ready() {
  grep -q "server listening on" "$SERVER_LOG"
}

require_nonempty() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Required config value is empty: $name"
}

if [[ "${1:-}" == "--dry-run" ]]; then
  MODE="dry-run"
  shift
fi

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
REQUESTED_TASK="$1"

case "$REQUESTED_TASK" in
  turning_on_radio|open-radio|turn-on-radio)
    TASK_NAME="turning_on_radio"
    ;;
  *)
    fail "Unsupported task '$REQUESTED_TASK'. Configured task: turning_on_radio"
    ;;
esac

[[ -f "$CONFIG_FILE" ]] || fail "Missing config: $CONFIG_FILE. Copy config.sh.example to config.sh and edit it."
# shellcheck source=/dev/null
set -a
source "$CONFIG_FILE"
set +a

: "${UV_BIN:=uv}"
: "${SERVER_HOST:=127.0.0.1}"
: "${SERVER_PORT:=8127}"
: "${CONTROL_MODE:=receeding_horizon}"
: "${MAX_LEN:=32}"
: "${POLICY_CONFIG:=pi05_b1k-base}"
: "${INSTANCE_INDICES:=0}"
: "${NUM_ROLLOUTS:=1}"
: "${SERVER_START_TIMEOUT_SECONDS:=900}"
: "${MAX_STEPS:=}"
: "${SERVER_CUDA_VISIBLE_DEVICES:=}"
: "${EVAL_CUDA_VISIBLE_DEVICES:=0}"

for var_name in OPENPI_ROOT BEHAVIOR_ROOT BEHAVIOR_PYTHON WORK_ROOT RADIO_CKPT; do
  require_nonempty "$var_name"
done

[[ -d "$OPENPI_ROOT" ]] || fail "OPENPI_ROOT does not exist: $OPENPI_ROOT"
[[ -f "$OPENPI_ROOT/scripts/serve_b1k.py" ]] || fail "serve_b1k.py not found under OPENPI_ROOT: $OPENPI_ROOT/scripts/serve_b1k.py"
[[ -d "$BEHAVIOR_ROOT" ]] || fail "BEHAVIOR_ROOT does not exist: $BEHAVIOR_ROOT"
[[ -x "$BEHAVIOR_PYTHON" ]] || fail "BEHAVIOR_PYTHON is not executable: $BEHAVIOR_PYTHON"
[[ -d "$RADIO_CKPT" ]] || fail "RADIO_CKPT does not exist: $RADIO_CKPT"
command -v "$UV_BIN" >/dev/null 2>&1 || fail "UV_BIN is not available: $UV_BIN"
command -v timeout >/dev/null 2>&1 || fail "Required command not found: timeout"
command -v setsid >/dev/null 2>&1 || fail "Required command not found: setsid"

RUN_ID="$(date +'%Y%m%d-%H%M%S')"
RUN_DIR="$WORK_ROOT/logs/behavior/$TASK_NAME/$RUN_ID"
SERVER_LOG="$RUN_DIR/server.log"
EVAL_LOG="$RUN_DIR/eval.log"
mkdir -p "$RUN_DIR"

server_env=(env)
if [[ -n "$SERVER_CUDA_VISIBLE_DEVICES" ]]; then
  server_env+=("CUDA_VISIBLE_DEVICES=$SERVER_CUDA_VISIBLE_DEVICES")
fi

eval_env=(env)
if [[ -n "$EVAL_CUDA_VISIBLE_DEVICES" ]]; then
  eval_env+=("CUDA_VISIBLE_DEVICES=$EVAL_CUDA_VISIBLE_DEVICES")
fi

server_cmd=(
  "$UV_BIN" run scripts/serve_b1k.py
  --task_name "$TASK_NAME"
  --control_mode "$CONTROL_MODE"
  --max_len "$MAX_LEN"
  --port "$SERVER_PORT"
  policy:checkpoint
  --policy.config "$POLICY_CONFIG"
  --policy.dir "$RADIO_CKPT"
)

eval_cmd=(
  "$BEHAVIOR_PYTHON" -m omnigibson.eval.eval
  --task-name "$TASK_NAME"
  --host "$SERVER_HOST"
  --port "$SERVER_PORT"
  --instance-indices "$INSTANCE_INDICES"
  --num-rollouts "$NUM_ROLLOUTS"
  --output-dir "$RUN_DIR"
  --write-video
  --headless
)
if [[ -n "$MAX_STEPS" ]]; then
  eval_cmd+=(--max-steps "$MAX_STEPS")
fi

printf 'TASK_NAME=%s\n' "$TASK_NAME"
printf 'RUN_DIR=%s\n' "$RUN_DIR"
printf 'SERVER_LOG=%s\n' "$SERVER_LOG"
printf 'EVAL_LOG=%s\n' "$EVAL_LOG"
printf 'SERVER_COMMAND='; quote_command "${server_env[@]}" "${server_cmd[@]}"
printf 'EVAL_COMMAND='; quote_command "${eval_env[@]}" "${eval_cmd[@]}"

if [[ "$MODE" == "dry-run" ]]; then
  printf 'DRY_RUN=1\n'
  exit 0
fi

if port_is_open "$SERVER_HOST" "$SERVER_PORT"; then
  fail "Port ${SERVER_HOST}:${SERVER_PORT} is already in use. Stop the existing process or choose another port in config.sh."
fi

SERVER_PID=""
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM -- "-$SERVER_PID" 2>/dev/null || kill -TERM "$SERVER_PID" 2>/dev/null || true
    sleep 2
    kill -KILL -- "-$SERVER_PID" 2>/dev/null || kill -KILL "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

(
  cd "$OPENPI_ROOT"
  exec setsid "${server_env[@]}" "${server_cmd[@]}"
) >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
printf 'SERVER_PID=%s\n' "$SERVER_PID"

start_epoch="$(date +%s)"


while ! server_ready; do

    if ! kill -0 "$SERVER_PID"; then
        echo "server died"
        tail -100 "$SERVER_LOG"
        exit 1
    fi

    sleep 2
done

printf 'SERVER_READY=1\n'

sleep 2

set +e
(
  cd "$BEHAVIOR_ROOT"
  "${eval_env[@]}" "${eval_cmd[@]}"
) 2>&1 | tee "$EVAL_LOG"
eval_status=${PIPESTATUS[0]}
set -e

if (( eval_status != 0 )); then
  printf 'Evaluator failed with exit code %s. Last log lines:\n' "$eval_status" >&2
  tail -n 120 "$EVAL_LOG" >&2 || true
  exit "$eval_status"
fi

VIDEO_PATH="$({
  find "$RUN_DIR" -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mov' \) -printf '%T@\t%p\n' 2>/dev/null || true
} | sort -nr | head -n 1 | cut -f2-)"

[[ -n "$VIDEO_PATH" && -f "$VIDEO_PATH" ]] || fail "Evaluation completed but no video file was found under $RUN_DIR"

printf 'VIDEO_PATH=%s\n' "$VIDEO_PATH"
printf 'STATUS=success\n'
