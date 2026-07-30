#!/usr/bin/env bash
set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install uv or activate an environment where uv is available." >&2
  exit 1
fi

uv pip install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly

