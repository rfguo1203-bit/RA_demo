#!/usr/bin/env bash
set -euo pipefail

VLLM_BASE_URL="${VLLM_BASE_URL:-http://127.0.0.1:8000/v1}"

curl -X POST "${VLLM_BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  --data-binary "@$(dirname "$0")/chat_text.json"

