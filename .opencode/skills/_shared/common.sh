#!/usr/bin/env bash

set -Eeuo pipefail

export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost,127.0.1.1,robots}"
export no_proxy="$NO_PROXY"

COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$COMMON_DIR/config.sh"

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  printf '%s' "$value"
}

json_error() {
  local task="${1:-unknown}"
  local error="${2:-unknown error}"
  local log_path="${3:-}"
  printf '{"ok":false,"task_name":"%s","error":"%s","log_path":"%s"}\n' \
    "$(json_escape "$task")" "$(json_escape "$error")" "$(json_escape "$log_path")"
}

require_nonempty() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    json_error "${TASK_NAME:-unknown}" "Required config value is empty: $name"
    exit 1
  }
}

canonical_task_name() {
  case "${1:-}" in
    turning_on_radio|open-radio|turn-on-radio|turn_on_radio)
      printf 'turning_on_radio\n'
      ;;
    putting_away_Halloween_decorations|putting-away-Halloween-decorations)
      printf 'putting_away_Halloween_decorations\n'
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_task_config() {
  TASK_NAME="$(canonical_task_name "$1")" || {
    json_error "${1:-unknown}" "Unsupported task. Configured phase-1 task: turning_on_radio"
    exit 1
  }

  case "$TASK_NAME" in
    turning_on_radio)
      TASK_CKPT="$RADIO_CKPT"
      ;;
    putting_away_Halloween_decorations)
      TASK_CKPT="$HALLOWEEN_CKPT"
      ;;
  esac

  export TASK_NAME TASK_CKPT
}

session_root() {
  printf '%s/%s\n' "$BEHAVIOR_INTERACTIVE_ROOT" "$TASK_NAME"
}

current_session_file() {
  printf '%s/current.env\n' "$(session_root)"
}

new_session_id() {
  date +'%Y%m%d-%H%M%S'
}

ensure_session_dirs() {
  mkdir -p "$(session_root)"
}

load_current_session() {
  local file
  file="$(current_session_file)"
  [[ -f "$file" ]] || return 1
  # shellcheck source=/dev/null
  source "$file"
}

write_current_session() {
  ensure_session_dirs
  cat >"$(current_session_file)" <<EOF
SESSION_ID="$SESSION_ID"
RUN_DIR="$RUN_DIR"
TASK_NAME="$TASK_NAME"
EOF
}

port_is_open() {
  local host="$1"
  local port="$2"
  timeout 1 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    json_error "$TASK_NAME" "Required command is not available: $cmd"
    exit 1
  }
}

write_kv_file() {
  local file="$1"
  shift
  : >"$file"
  while [[ $# -gt 0 ]]; do
    printf '%s="%s"\n' "$1" "$2" >>"$file"
    shift 2
  done
}
