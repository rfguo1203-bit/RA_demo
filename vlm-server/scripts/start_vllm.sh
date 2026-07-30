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

export VLLM_LOG_LEVEL

if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  export CUDA_VISIBLE_DEVICES
fi

if [ ! -d "${MODEL_PATH}" ]; then
  echo "MODEL_PATH does not exist: ${MODEL_PATH}" >&2
  exit 1
fi

exec vllm serve "${MODEL_PATH}" \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --served-model-name "${SERVED_MODEL_NAME}" \
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --reasoning-parser qwen3 \
  --trust-remote-code \
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}"

