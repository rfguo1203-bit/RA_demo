#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/image.png" >&2
  exit 2
fi

VLLM_BASE_URL="${VLLM_BASE_URL:-http://127.0.0.1:8000/v1}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen3.5-397b-a17b-fp8}"
IMAGE_PATH="$1"

python - "$IMAGE_PATH" "$VLLM_BASE_URL" "$SERVED_MODEL_NAME" <<'PY'
import base64
import json
import mimetypes
import sys
import urllib.request

image_path, base_url, model = sys.argv[1:4]
mime_type, _ = mimetypes.guess_type(image_path)
if not mime_type:
    mime_type = "image/png"
with open(image_path, "rb") as image_file:
    encoded = base64.b64encode(image_file.read()).decode("ascii")

payload = {
    "model": model,
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{encoded}"}},
                {"type": "text", "text": "Describe this image in one sentence."},
            ],
        }
    ],
    "temperature": 0.0,
    "max_tokens": 256,
}

request = urllib.request.Request(
    f"{base_url.rstrip('/')}/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=180) as response:
    print(response.read().decode("utf-8"))
PY

