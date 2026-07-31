#!/usr/bin/env python3
import argparse
import json
import os
import sys
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


def post_json(url: str, payload: dict, api_key: str, timeout: int) -> dict:
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


def main() -> int:
    load_project_env()

    parser = argparse.ArgumentParser(
        description="Probe OpenAI-compatible tool calling on a vLLM server."
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("VLLM_BASE_URL", "http://127.0.0.1:8000/v1"),
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("SERVED_MODEL_NAME", "qwen3.5-397b-a17b-fp8"),
    )
    parser.add_argument("--api-key", default=os.environ.get("VLLM_API_KEY", "EMPTY"))
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--max-tokens", type=int, default=512)
    args = parser.parse_args()

    payload = {
        "model": args.model,
        "messages": [
            {
                "role": "user",
                "content": (
                    "Use the available tool to list the current directory. "
                    "Do not answer in natural language before calling the tool."
                ),
            }
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "list_current_directory",
                    "description": "List file names in the current working directory.",
                    "parameters": {
                        "type": "object",
                        "properties": {},
                        "additionalProperties": False,
                    },
                },
            }
        ],
        "tool_choice": "auto",
        "temperature": 0.0,
        "max_tokens": args.max_tokens,
        "chat_template_kwargs": {"enable_thinking": False},
    }

    try:
        response = post_json(
            f"{args.base_url.rstrip('/')}/chat/completions",
            payload,
            args.api_key,
            args.timeout,
        )
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8"), file=sys.stderr, end="")
        return 1
    except urllib.error.URLError as exc:
        print(f"connection failed: {exc}", file=sys.stderr)
        return 1

    choice = response.get("choices", [{}])[0]
    message = choice.get("message", {})
    print(json.dumps(
        {
            "finish_reason": choice.get("finish_reason"),
            "content": message.get("content"),
            "reasoning": message.get("reasoning") or message.get("reasoning_content"),
            "tool_calls": message.get("tool_calls"),
            "raw_message": message,
        },
        ensure_ascii=False,
        indent=2,
    ))

    if not message.get("tool_calls"):
        print(
            "\nNo tool_calls were returned. Check that vLLM was restarted with "
            "ENABLE_AUTO_TOOL_CHOICE=1 and TOOL_CALL_PARSER=hermes.",
            file=sys.stderr,
        )
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
