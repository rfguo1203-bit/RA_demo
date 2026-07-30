#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 user@10.160.124.xx [local_port] [remote_port]" >&2
  echo "Example: $0 ubuntu@10.160.124.12 18000 8000" >&2
  exit 2
fi

SSH_TARGET="$1"
LOCAL_PORT="${2:-18000}"
REMOTE_PORT="${3:-8000}"

echo "Opening SSH tunnel:"
echo "  local:  http://127.0.0.1:${LOCAL_PORT}/v1"
echo "  remote: ${SSH_TARGET}:127.0.0.1:${REMOTE_PORT}"
echo
echo "Keep this terminal open while the Host calls the VLM service."

exec ssh \
  -N \
  -L "127.0.0.1:${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
  "${SSH_TARGET}"

