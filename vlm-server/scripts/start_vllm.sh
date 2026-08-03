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

MODEL_PATH="${MODEL_PATH:-/srv/data2/g00806422/model_weights}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.5-397b-a17b-fp8}"
VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
VLLM_PORT="${VLLM_PORT:-8000}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-8}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-262144}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"
VLLM_LOG_LEVEL="${VLLM_LOG_LEVEL:-INFO}"
REASONING_PARSER="${REASONING_PARSER:-qwen3}"
CHAT_TEMPLATE="${CHAT_TEMPLATE:-}"
DEFAULT_CHAT_TEMPLATE_KWARGS="${DEFAULT_CHAT_TEMPLATE_KWARGS:-}"
ENABLE_AUTO_TOOL_CHOICE="${ENABLE_AUTO_TOOL_CHOICE:-0}"
TOOL_CALL_PARSER="${TOOL_CALL_PARSER:-hermes}"

export VLLM_LOG_LEVEL

if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export CUDA_VISIBLE_DEVICES
fi

if [ ! -d "${MODEL_PATH}" ]; then
  echo "MODEL_PATH does not exist: ${MODEL_PATH}" >&2
  exit 1
fi

VLLM_ARGS=(
  serve "${MODEL_PATH}"
  --host "${VLLM_HOST}"
  --port "${VLLM_PORT}"
  --served-model-name "${SERVED_MODEL_NAME}"
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}"
  --max-model-len "${MAX_MODEL_LEN}"
  --reasoning-parser "${REASONING_PARSER}"
  --trust-remote-code
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}"
)

if [ -n "${CHAT_TEMPLATE}" ]; then
  VLLM_ARGS+=(--chat-template "${CHAT_TEMPLATE}")
fi

if [ -n "${DEFAULT_CHAT_TEMPLATE_KWARGS}" ]; then
  VLLM_ARGS+=(--default-chat-template-kwargs "${DEFAULT_CHAT_TEMPLATE_KWARGS}")
fi

if [ "${ENABLE_AUTO_TOOL_CHOICE}" = "1" ] || [ "${ENABLE_AUTO_TOOL_CHOICE}" = "true" ]; then
  VLLM_ARGS+=(--enable-auto-tool-choice --tool-call-parser "${TOOL_CALL_PARSER}")
fi

exec vllm "${VLLM_ARGS[@]}"
