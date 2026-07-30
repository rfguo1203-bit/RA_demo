#!/usr/bin/env python3
import argparse
import base64
import json
import mimetypes
import sys
import urllib.error
import urllib.request


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


def get_json(url: str, api_key: str, timeout: int) -> dict:
    request = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {api_key}"},
        method="GET",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def image_data_url(path: str) -> str:
    mime_type, _ = mimetypes.guess_type(path)
    if not mime_type:
        mime_type = "image/png"
    with open(path, "rb") as image_file:
        encoded = base64.b64encode(image_file.read()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def print_choice(label: str, response: dict) -> None:
    choice = response.get("choices", [{}])[0]
    message = choice.get("message", {})
    print(f"\n[{label}]")
    print(json.dumps(message, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Test a remote OpenAI-compatible Qwen3.5 VLM server."
    )
    parser.add_argument(
        "--base-url",
        required=True,
        help="Remote vLLM base URL, for example http://10.0.0.12:8000/v1",
    )
    parser.add_argument(
        "--model",
        default="qwen3.5-397b-a17b-fp8",
        help="Served model name configured in vLLM.",
    )
    parser.add_argument("--api-key", default="EMPTY")
    parser.add_argument("--image", help="Optional local image path for VLM test.")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")

    try:
        models = get_json(f"{base_url}/models", args.api_key, args.timeout)
        print("[models]")
        print(json.dumps(models, ensure_ascii=False, indent=2))

        text_response = post_json(
            f"{base_url}/chat/completions",
            {
                "model": args.model,
                "messages": [
                    {
                        "role": "user",
                        "content": "Reply with exactly: remote text probe ok",
                    }
                ],
                "temperature": 0.0,
                "max_tokens": 64,
            },
            args.api_key,
            args.timeout,
        )
        print_choice("text chat", text_response)

        if args.image:
            image_response = post_json(
                f"{base_url}/chat/completions",
                {
                    "model": args.model,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image_url",
                                    "image_url": {"url": image_data_url(args.image)},
                                },
                                {
                                    "type": "text",
                                    "text": "Describe this image in one sentence.",
                                },
                            ],
                        }
                    ],
                    "temperature": 0.0,
                    "max_tokens": 256,
                },
                args.api_key,
                args.timeout,
            )
            print_choice("image chat", image_response)

    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8"), file=sys.stderr, end="")
        return 1
    except urllib.error.URLError as exc:
        print(f"connection failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

