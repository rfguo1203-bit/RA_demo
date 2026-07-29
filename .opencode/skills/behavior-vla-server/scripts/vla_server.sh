#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../_shared/common.sh
source "$SKILLS_DIR/_shared/common.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  vla_server.sh start <task>
  vla_server.sh status <task>
  vla_server.sh stop <task>
USAGE
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

VLA_STATE_FILE="$RUN_DIR/vla_server.env"
VLA_LOG="$RUN_DIR/vla_server.log"

print_status() {
  local state="stopped"
  local pid=""
  if [[ -f "$VLA_STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$VLA_STATE_FILE"
    pid="${VLA_PID:-}"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      state="running"
    fi
  fi
  printf '{"ok":true,"task_name":"%s","session_id":"%s","state":"%s","vla_host":"%s","vla_port":%s,"vla_pid":"%s","run_dir":"%s","server_log":"%s"}\n' \
    "$(json_escape "$TASK_NAME")" "$(json_escape "$SESSION_ID")" "$state" \
    "$(json_escape "$SERVER_HOST")" "$SERVER_PORT" "$(json_escape "$pid")" \
    "$(json_escape "$RUN_DIR")" "$(json_escape "$VLA_LOG")"
}

vla_health_ready() {
  curl -fsS "http://${SERVER_HOST}:${SERVER_PORT}/healthz" >/dev/null 2>&1
}

case "$action" in
  start)
    for name in OPENPI_ROOT WORK_ROOT TASK_CKPT; do
      require_nonempty "$name"
    done
    [[ -d "$OPENPI_ROOT" ]] || { json_error "$TASK_NAME" "OPENPI_ROOT does not exist: $OPENPI_ROOT" "$VLA_LOG"; exit 1; }
    [[ -f "$OPENPI_ROOT/scripts/serve_b1k.py" ]] || { json_error "$TASK_NAME" "serve_b1k.py not found under OPENPI_ROOT" "$VLA_LOG"; exit 1; }
    [[ -d "$TASK_CKPT" ]] || { json_error "$TASK_NAME" "Task checkpoint does not exist: $TASK_CKPT" "$VLA_LOG"; exit 1; }
    require_command curl
    require_command "$UV_BIN"
    require_command timeout
    require_command setsid

    if [[ -f "$VLA_STATE_FILE" ]]; then
      # shellcheck source=/dev/null
      source "$VLA_STATE_FILE"
      if [[ -n "${VLA_PID:-}" ]] && kill -0 "$VLA_PID" 2>/dev/null; then
        print_status
        exit 0
      fi
    fi

    if port_is_open "$SERVER_HOST" "$SERVER_PORT"; then
      json_error "$TASK_NAME" "Port ${SERVER_HOST}:${SERVER_PORT} is already in use by an unknown process" "$VLA_LOG"
      exit 1
    fi

    server_env=(env)
    if [[ -n "$SERVER_CUDA_VISIBLE_DEVICES" ]]; then
      server_env+=("CUDA_VISIBLE_DEVICES=$SERVER_CUDA_VISIBLE_DEVICES")
    fi

    server_cmd=(
      "$UV_BIN" run scripts/serve_b1k.py
      --task_name "$TASK_NAME"
      --control_mode "$CONTROL_MODE"
      --max_len "$MAX_LEN"
      --port "$SERVER_PORT"
      policy:checkpoint
      --policy.config "$POLICY_CONFIG"
      --policy.dir "$TASK_CKPT"
    )

    (
      cd "$OPENPI_ROOT"
      exec setsid "${server_env[@]}" "${server_cmd[@]}"
    ) >"$VLA_LOG" 2>&1 &
    VLA_PID=$!
    write_kv_file "$VLA_STATE_FILE" VLA_PID "$VLA_PID" VLA_LOG "$VLA_LOG" SERVER_HOST "$SERVER_HOST" SERVER_PORT "$SERVER_PORT"

    start_epoch="$(date +%s)"
    while ! vla_health_ready; do
      if ! kill -0 "$VLA_PID" 2>/dev/null; then
        json_error "$TASK_NAME" "VLA server exited during startup" "$VLA_LOG"
        exit 1
      fi
      now="$(date +%s)"
      if (( now - start_epoch > SERVER_START_TIMEOUT_SECONDS )); then
        json_error "$TASK_NAME" "Timed out waiting for VLA server" "$VLA_LOG"
        exit 1
      fi
      sleep 2
    done
    print_status
    ;;
  status)
    print_status
    ;;
  stop)
    if [[ -f "$VLA_STATE_FILE" ]]; then
      # shellcheck source=/dev/null
      source "$VLA_STATE_FILE"
      if [[ -n "${VLA_PID:-}" ]] && kill -0 "$VLA_PID" 2>/dev/null; then
        kill -TERM -- "-$VLA_PID" 2>/dev/null || kill -TERM "$VLA_PID" 2>/dev/null || true
        sleep 1
      fi
    fi
    print_status
    ;;
  *)
    usage
    exit 2
    ;;
esac
