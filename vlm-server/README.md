# vlm-server

`vlm-server` deploys `Qwen3.5-397B-A17B-FP8` as a general OpenAI-compatible
vision-language chat service. It does not contain task-specific prompts or
BEHAVIOR success judging logic. The Host/OpenCode side is responsible for
building prompts, sending observations, and interpreting responses.

## Target Runtime

- Server: 8 x NVIDIA H100
- Model: Qwen3.5-397B-A17B-FP8
- Precision: FP8 checkpoint weights
- Local model path: `/srv/data2/g00806422/model_weights`
- Serving backend: vLLM
- Public API: `http://<server-ip>:8000/v1/chat/completions`

The Hugging Face model card describes this checkpoint as a vision-language
architecture and provides OpenAI-compatible vLLM usage examples with image
inputs:

https://huggingface.co/Qwen/Qwen3.5-397B-A17B-FP8

## Files

```text
vlm-server/
  env.example
  scripts/
    install_vllm.sh
    start_server.sh
    start_vllm.sh
    healthcheck.sh
    probe_text.py
    probe_image.py
    test_remote_server.py
  examples/
    chat_text.json
    chat_image.json
    curl_text.sh
    curl_image.sh
  systemd/
    vlm-server.service
```

## Installation

On the H100 server, create and activate a fresh Python environment first. Do
not change the dependency plan silently if installation fails; inspect the
error and fix the vLLM/CUDA/PyTorch compatibility issue directly.

```bash
cd /path/to/RA_demo/vlm-server
bash scripts/install_vllm.sh
```

The installer follows the model card's vLLM guidance and installs a nightly
vLLM wheel:

```bash
uv pip install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
```

## Configuration

Copy `env.example` to `.env` on the deployment server and edit values if
needed:

```bash
cp env.example .env
```

Default values are tuned for 8 x H100:

```bash
MODEL_PATH=/srv/data2/g00806422/model_weights
SERVED_MODEL_NAME=qwen3.5-397b-a17b-fp8
VLLM_HOST=0.0.0.0
VLLM_PORT=8000
TENSOR_PARALLEL_SIZE=8
MAX_MODEL_LEN=262144
ENABLE_AUTO_TOOL_CHOICE=0
TOOL_CALL_PARSER=hermes
```

## Start vLLM

```bash
cd /path/to/RA_demo/vlm-server
bash scripts/start_server.sh foreground
```

The script expands to:

```bash
vllm serve /srv/data2/g00806422/model_weights \
  --host 0.0.0.0 \
  --port 8000 \
  --served-model-name qwen3.5-397b-a17b-fp8 \
  --tensor-parallel-size 8 \
  --max-model-len 262144 \
  --reasoning-parser qwen3 \
  --trust-remote-code \
  --gpu-memory-utilization 0.90
```

Do not add `--language-model-only`; this service must keep the vision encoder
enabled.

## OpenCode Tool Calling

The error below means the client sent OpenAI-style tools with
`tool_choice: "auto"`, but vLLM was not started with automatic tool-call
parsing enabled:

```text
"auto" tool choice requires --enable-auto-tool-choice and --tool-call-parser to be set
```

If this server is used only as a generic VLM endpoint for Host-side task
judging, do not send `tools` or `tool_choice: "auto"` in requests.

If you register this server directly as an OpenCode model and OpenCode sends
tool definitions, enable tool parsing in `.env`:

```bash
ENABLE_AUTO_TOOL_CHOICE=1
TOOL_CALL_PARSER=hermes
```

Then restart:

```bash
bash scripts/start_server.sh stop
bash scripts/start_server.sh background
```

The resulting vLLM command includes:

```bash
--enable-auto-tool-choice --tool-call-parser hermes
```

Qwen's vLLM documentation uses the Hermes parser for Qwen3 tool calling:

https://github.com/QwenLM/Qwen3/blob/main/docs/source/framework/function_call.md

For a terminal-managed background process:

```bash
bash scripts/start_server.sh background
bash scripts/start_server.sh status
tail -f logs/vlm-server.log
```

To stop only the process started by this script:

```bash
bash scripts/start_server.sh stop
```

## Health Checks

```bash
bash scripts/healthcheck.sh
python scripts/probe_text.py
python scripts/probe_image.py --image /path/to/test.png
```

`probe_image.py` sends an OpenAI-compatible multimodal message with an inline
base64 data URL. This is the same message shape the Host should use for
BEHAVIOR observations.

## Test From Another Server

Copy or sync this repository to the client/Host server, then run:

```bash
python vlm-server/scripts/test_remote_server.py \
  --base-url http://<vlm-server-ip>:8000/v1
```

To test image input from the remote server:

```bash
python vlm-server/scripts/test_remote_server.py \
  --base-url http://<vlm-server-ip>:8000/v1 \
  --image /path/to/test.png
```

The remote test script disables Qwen thinking mode by default with:

```json
{"chat_template_kwargs": {"enable_thinking": false}}
```

Without this, Qwen3.5 may return only the OpenAI-compatible `reasoning` field
while `content` is still `null`, especially when `max_tokens` is too small for
both reasoning and the final answer. To test reasoning mode explicitly, pass:

```bash
python vlm-server/scripts/test_remote_server.py \
  --base-url http://<vlm-server-ip>:8000/v1 \
  --enable-thinking \
  --max-tokens 2048
```

If the client/Host server reaches the H100 server through SSH, keep vLLM bound
to the H100 machine and open a local tunnel from the client:

```bash
bash vlm-server/scripts/open_ssh_tunnel.sh user@10.160.124.xx 18000 8000
```

Then call the VLM service through the client-side local port:

```bash
python vlm-server/scripts/test_remote_server.py \
  --base-url http://127.0.0.1:18000/v1 \
  --image /path/to/test.png
```

## Host Contract

The Host calls the vLLM endpoint directly:

```http
POST http://<vlm-server-ip>:8000/v1/chat/completions
```

Text request:

```json
{
  "model": "qwen3.5-397b-a17b-fp8",
  "messages": [
    {"role": "user", "content": "hello"}
  ],
  "temperature": 0.0,
  "max_tokens": 512
}
```

Image request:

```json
{
  "model": "qwen3.5-397b-a17b-fp8",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}},
        {"type": "text", "text": "Describe this observation."}
      ]
    }
  ],
  "temperature": 0.0,
  "max_tokens": 1024
}
```

Task success prompts, JSON schemas, confidence thresholds, and retry policy
belong in the Host implementation, not in this deployment project.
