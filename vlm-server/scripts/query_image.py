#!/usr/bin/env python3
"""Send one image and prompt to the deployed VLM and print its response.

Usage
-----
OpenCode should call this command with a local observation image and the prompt
that describes the required visual understanding or planning task::

    python vlm-server/scripts/query_image.py \\
      --image /path/to/observation.png \\
      --prompt "Describe the robot state and recommend the next action."

The script reads the following settings from ``vlm-server/.env`` (or inherited
environment variables): ``VLLM_BASE_URL``, ``SERVED_MODEL_NAME``, and
``VLLM_API_KEY``. A Host that reaches the VLM through an SSH tunnel can override
the endpoint per invocation::

    python vlm-server/scripts/query_image.py \\
      --base-url http://127.0.0.1:18000/v1 \\
      --image /path/to/observation.png \\
      --prompt "Is the radio switched on? Answer with visual evidence."

Thinking is enabled by default. Set a sufficiently large ``--max-tokens`` value
(for example ``2048``) when reasoning plus a final answer is needed. Pass
``--disable-thinking`` when only a concise final answer is wanted.

Tool contract
-------------
On success, stdout contains only the model's final text response, making it
safe for OpenCode to consume directly. Diagnostics and failures are emitted to
stderr; failures return a non-zero exit status.
"""

import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = "http://127.0.0.1:8000/v1"
DEFAULT_MODEL = "qwen3.5-397b-a17b-fp8"


def load_project_env() -> None:
    """Load vlm-server/.env without overriding explicitly set environment values."""
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


def image_data_url(image_path: Path) -> str:
    mime_type, _ = mimetypes.guess_type(image_path.name)
    if not mime_type or not mime_type.startswith("image/"):
        mime_type = "image/png"
    encoded = base64.b64encode(image_path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def post_json(url: str, payload: dict[str, Any], api_key: str, timeout: int) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def response_text(response: dict[str, Any]) -> str:
    try:
        message = response["choices"][0]["message"]
    except (IndexError, KeyError, TypeError) as exc:
        raise ValueError("VLM response does not contain choices[0].message") from exc

    content = message.get("content")
    if isinstance(content, str) and content:
        return content
    if content == "":
        return ""

    if message.get("reasoning"):
        raise ValueError(
            "VLM returned reasoning but no final content. "
            "Keep thinking disabled or retry with a larger --max-tokens value."
        )
    raise ValueError("VLM response has no text content")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send an image and prompt to the VLM; print the final text response."
    )
    parser.add_argument("--image", required=True, help="Path to a local image file.")
    parser.add_argument("--prompt", required=True, help="Prompt sent with the image.")
    parser.add_argument(
        "--base-url",
        default=os.environ.get("VLLM_BASE_URL", DEFAULT_BASE_URL),
        help="OpenAI-compatible VLM base URL (default: VLLM_BASE_URL or localhost).",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("SERVED_MODEL_NAME", DEFAULT_MODEL),
        help="Served model name (default: SERVED_MODEL_NAME).",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("VLLM_API_KEY", "EMPTY"),
        help="Bearer token (default: VLLM_API_KEY or EMPTY).",
    )
    parser.add_argument("--timeout", type=int, default=180, help="Request timeout in seconds.")
    parser.add_argument("--max-tokens", type=int, default=1024, help="Maximum output tokens.")
    parser.add_argument("--temperature", type=float, default=0.0, help="Sampling temperature.")
    parser.add_argument(
        "--disable-thinking",
        action="store_true",
        help="Disable Qwen thinking mode (enabled by default).",
    )
    return parser.parse_args()


def main() -> int:
    load_project_env()
    args = parse_args()
    image_path = Path(args.image).expanduser()

    if not image_path.is_file():
        print(f"image file not found: {image_path}", file=sys.stderr)
        return 2
    if args.timeout <= 0 or args.max_tokens <= 0:
        print("--timeout and --max-tokens must be positive", file=sys.stderr)
        return 2

    payload: dict[str, Any] = {
        "model": args.model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": image_data_url(image_path)}},
                    {"type": "text", "text": args.prompt},
                ],
            }
        ],
        "temperature": args.temperature,
        "max_tokens": args.max_tokens,
        "chat_template_kwargs": {"enable_thinking": not args.disable_thinking},
    }

    try:
        response = post_json(
            f"{args.base_url.rstrip('/')}/chat/completions",
            payload,
            args.api_key,
            args.timeout,
        )
        print(response_text(response))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"VLM request failed with HTTP {exc.code}: {detail}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"VLM connection failed: {exc.reason}", file=sys.stderr)
        return 1
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"VLM request failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
