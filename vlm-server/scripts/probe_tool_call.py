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
    parser.add_argument("--max-tokens", type=int, default=4096)
    parser.add_argument(
        "--chat-template-kwargs",
        default=os.environ.get(
            "PROBE_CHAT_TEMPLATE_KWARGS",
            os.environ.get("DEFAULT_CHAT_TEMPLATE_KWARGS", ""),
        ),
        help=(
            "JSON object passed as chat_template_kwargs. Defaults to "
            "PROBE_CHAT_TEMPLATE_KWARGS or DEFAULT_CHAT_TEMPLATE_KWARGS."
        ),
    )
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
                    "strict": True,
                },
            }
        ],
        "tool_choice": "auto",
        "temperature": 0.0,
        "max_tokens": args.max_tokens,
    }

    if args.chat_template_kwargs:
        try:
            chat_template_kwargs = json.loads(args.chat_template_kwargs)
        except json.JSONDecodeError as exc:
            print(f"invalid --chat-template-kwargs JSON: {exc}", file=sys.stderr)
            return 2
        if not isinstance(chat_template_kwargs, dict):
            print("--chat-template-kwargs must decode to a JSON object", file=sys.stderr)
            return 2
        payload["chat_template_kwargs"] = chat_template_kwargs

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
        content = message.get("content") or ""
        if "<tool_call>" in content and "<function=" in content:
            print(
                "\nThe model emitted a malformed Hermes tool call. vLLM's Hermes "
                "parser expects JSON inside <tool_call>, for example:\n"
                '<tool_call>{"name":"list_current_directory","arguments":{}}</tool_call>\n'
                "but the model returned XML-like <function=...> content instead. "
                "Verify that the served model/tokenizer chat template supports "
                "Hermes/Qwen tool calling, or start vLLM with the parser/template "
                "that matches this model.",
                file=sys.stderr,
            )
        else:
            print(
                "\nNo tool_calls were returned. Check that vLLM was restarted with "
                "ENABLE_AUTO_TOOL_CHOICE=1 and a TOOL_CALL_PARSER matching the model.",
                file=sys.stderr,
            )
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
