#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


def load_project_env() -> None:
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


def main() -> int:
    load_project_env()

    base_url = os.environ.get("VLLM_BASE_URL", "http://127.0.0.1:8000/v1").rstrip("/")
    model = os.environ.get("SERVED_MODEL_NAME", "qwen3.5-397b-a17b-fp8")
    api_key = os.environ.get("VLLM_API_KEY", "EMPTY")

    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": "Reply with exactly: vlm-server text probe ok",
            }
        ],
        "temperature": 0.0,
        "max_tokens": 64,
    }

    request = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            print(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8"), end="")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
