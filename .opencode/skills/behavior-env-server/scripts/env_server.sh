#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../_shared/common.sh
source "$SKILLS_DIR/_shared/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  env_server.sh start <task>
  env_server.sh status <task>
  env_server.sh stop <task>
USAGE
}

http_get() {
  curl -fsS "http://${ENV_SERVER_HOST}:${ENV_SERVER_PORT}$1"
}

http_post() {
  local path="$1"
  local body="$2"
  curl -fsS -X POST -H 'Content-Type: application/json' --data "$body" "http://${ENV_SERVER_HOST}:${ENV_SERVER_PORT}${path}"
}

action="${1:-}"
task_arg="${2:-}"
[[ -n "$action" && -n "$task_arg" ]] || { usage; exit 2; }
resolve_task_config "$task_arg"

ensure_session_dirs
if ! load_current_session; then
  SESSION_ID="$(new_session_id)"
  RUN_DIR="$(session_root)/$SESSION_ID"
  write_current_session
fi
mkdir -p "$RUN_DIR"

ENV_STATE_FILE="$RUN_DIR/env_server.env"
ENV_LOG="$RUN_DIR/env_server.log"
VIDEO_DIR="$RUN_DIR/videos"
JSON_DIR="$RUN_DIR/json"
mkdir -p "$VIDEO_DIR" "$JSON_DIR"

print_local_status() {
  local state="stopped"
  local pid=""
  if [[ -f "$ENV_STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_STATE_FILE"
    pid="${ENV_PID:-}"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      state="running"
    fi
  fi
  printf '{"ok":true,"task_name":"%s","session_id":"%s","state":"%s","env_host":"%s","env_port":%s,"env_pid":"%s","run_dir":"%s","env_log":"%s"}\n' \
    "$(json_escape "$TASK_NAME")" "$(json_escape "$SESSION_ID")" "$state" \
    "$(json_escape "$ENV_SERVER_HOST")" "$ENV_SERVER_PORT" "$(json_escape "$pid")" \
    "$(json_escape "$RUN_DIR")" "$(json_escape "$ENV_LOG")"
}

case "$action" in
  start)
    for name in BEHAVIOR_ROOT BEHAVIOR_PYTHON WORK_ROOT; do
      require_nonempty "$name"
    done
    [[ -d "$BEHAVIOR_ROOT" ]] || { json_error "$TASK_NAME" "BEHAVIOR_ROOT does not exist: $BEHAVIOR_ROOT" "$ENV_LOG"; exit 1; }
    [[ -x "$BEHAVIOR_PYTHON" ]] || { json_error "$TASK_NAME" "BEHAVIOR_PYTHON is not executable: $BEHAVIOR_PYTHON" "$ENV_LOG"; exit 1; }
    require_command curl
    require_command timeout
    require_command setsid

    if [[ -f "$ENV_STATE_FILE" ]]; then
      # shellcheck source=/dev/null
      source "$ENV_STATE_FILE"
      if [[ -n "${ENV_PID:-}" ]] && kill -0 "$ENV_PID" 2>/dev/null; then
        http_get /session/status || print_local_status
        exit 0
      fi
    fi

    if port_is_open "$ENV_SERVER_HOST" "$ENV_SERVER_PORT"; then
      json_error "$TASK_NAME" "Port ${ENV_SERVER_HOST}:${ENV_SERVER_PORT} is already in use by an unknown process" "$ENV_LOG"
      exit 1
    fi

    INSTANCE_INDEX="${INSTANCE_INDICES%% *}"
    env_cmd=(
      "$BEHAVIOR_PYTHON" -m omnigibson.eval.interactive_server
      --server-host "$ENV_SERVER_HOST"
      --server-port "$ENV_SERVER_PORT"
      --task-name "$TASK_NAME"
      --policy-host "$SERVER_HOST"
      --policy-port "$SERVER_PORT"
      --instance-index "$INSTANCE_INDEX"
      --mode "$MODE"
      --output-dir "$RUN_DIR"
      --env-wrapper "$ENV_WRAPPER"
      --video-fps "$VIDEO_FPS"
    )
    if [[ "$WRITE_VIDEO" == "1" ]]; then
      env_cmd+=(--write-video)
    else
      env_cmd+=(--no-write-video)
    fi
    if [[ "$HEADLESS" == "1" ]]; then
      env_cmd+=(--headless)
    else
      env_cmd+=(--no-headless)
    fi
    if [[ -n "$MAX_STEPS" ]]; then
      env_cmd+=(--max-steps "$MAX_STEPS")
    fi
    if [[ -n "$ROBOT_CONFIG" ]]; then
      env_cmd+=(--robot-config "$ROBOT_CONFIG")
    fi

    eval_env=(env)
    if [[ -n "$EVAL_CUDA_VISIBLE_DEVICES" ]]; then
      eval_env+=("CUDA_VISIBLE_DEVICES=$EVAL_CUDA_VISIBLE_DEVICES")
    fi

    (
      cd "$BEHAVIOR_ROOT"
      exec setsid "${eval_env[@]}" "${env_cmd[@]}"
    ) >"$ENV_LOG" 2>&1 &
    ENV_PID=$!
    write_kv_file "$ENV_STATE_FILE" ENV_PID "$ENV_PID" ENV_LOG "$ENV_LOG" ENV_SERVER_HOST "$ENV_SERVER_HOST" ENV_SERVER_PORT "$ENV_SERVER_PORT"

    start_epoch="$(date +%s)"
    while ! http_get /healthz >/dev/null 2>&1; do
      if ! kill -0 "$ENV_PID" 2>/dev/null; then
        json_error "$TASK_NAME" "Env server exited during startup" "$ENV_LOG"
        exit 1
      fi
      now="$(date +%s)"
      if (( now - start_epoch > ENV_SERVER_START_TIMEOUT_SECONDS )); then
        json_error "$TASK_NAME" "Timed out waiting for Env server" "$ENV_LOG"
        exit 1
      fi
      sleep 2
    done

    http_post /session/start "{\"task_name\":\"$TASK_NAME\"}" || {
      json_error "$TASK_NAME" "Env server started but session initialization failed" "$ENV_LOG"
      exit 1
    }
    ;;
  status)
    require_command curl
    http_get /session/status || print_local_status
    ;;
  stop)
    require_command curl
    http_post /session/stop '{}' >/dev/null 2>&1 || true
    if [[ -f "$ENV_STATE_FILE" ]]; then
      # shellcheck source=/dev/null
      source "$ENV_STATE_FILE"
      if [[ -n "${ENV_PID:-}" ]] && kill -0 "$ENV_PID" 2>/dev/null; then
        kill -TERM -- "-$ENV_PID" 2>/dev/null || kill -TERM "$ENV_PID" 2>/dev/null || true
        sleep 1
      fi
    fi
    print_local_status
    ;;
  *)
    usage
    exit 2
    ;;
esac
