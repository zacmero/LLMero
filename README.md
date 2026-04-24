# LLMero

Local AI setup repo for running project-specific `llama.cpp` builds across:

- Local Arch Linux machine with NVIDIA CUDA.
- CPU-only Ubuntu/cloud VM.
- Multiple model profiles with OpenAI-compatible APIs.

Validated local profiles:

- `llmero-bonsai`: fast text-only Bonsai 8B GGUF.
- `llmero-gemma4`: Gemma 4 E4B multimodal GGUF with text + image support.

Generated source/build files live under `.llmero/`. Model weights live under `models/`.

## Current Local Status

Gemma 4 is validated locally on the GTX 1060 6GB:

- Model: `ggml-org/gemma-4-E4B-it-GGUF`
- Text model: `gemma-4-E4B-it-Q4_K_M.gguf`
- Multimodal projector: `mmproj-gemma-4-E4B-it-Q8_0.gguf`
- API server: `http://127.0.0.1:8082/v1`
- Model alias: `gemma-4-e4b`
- Thinking mode: enabled
- Text test speed: about `27 tok/s`
- Image test speed: about `26.8 tok/s`
- GPU memory while serving: about `4.3G / 6G`

## Clone

Replace the URL with your GitHub repo URL:

```bash
git clone <your-github-repo-url> LLMero
cd LLMero
```

## Install Build Dependencies

Arch:

```bash
sudo pacman -S --needed git base-devel cmake
```

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y git build-essential cmake python3 python3-venv curl
```

## Local CUDA Build Notes

This local machine uses a GTX 1060 6GB:

- GPU architecture: Pascal
- Compute capability: `6.1`
- Required CUDA compiler arch: `compute_61`

CUDA 13 does not compile `compute_61`. Use CUDA 12.9 from:

```text
/opt/cuda-12.9
```

Keep compile jobs low on this machine:

```bash
JOBS=1
```

`100C` is the CPU critical limit. Do not sustain builds there.

## Install Bonsai

CUDA:

```bash
JOBS=1 CUDA_HOME=/opt/cuda-12.9 ./install.sh --profile llmero-bonsai --backend cuda --skip-deps
```

CPU-only VM:

```bash
./install.sh --profile llmero-bonsai --backend cpu
```

Download model:

```bash
./scripts/download-model.sh llmero-bonsai
```

Run one-shot test:

```bash
LD_LIBRARY_PATH=.llmero/build/llmero-bonsai/cuda/bin:/opt/cuda-12.9/targets/x86_64-linux/lib \
.llmero/build/llmero-bonsai/cuda/bin/llama-cli \
  -m models/llmero-bonsai/Bonsai-8B.gguf \
  -p "Write one short sentence about bonsai trees." \
  -n 32 -c 1024 -ngl 99 \
  --temp 0.5 --top-p 0.85 --top-k 20 \
  --single-turn --simple-io --no-display-prompt
```

## Install Gemma 4

CUDA:

```bash
JOBS=1 CUDA_HOME=/opt/cuda-12.9 ./install.sh --profile llmero-gemma4 --backend cuda --skip-deps
```

CPU-only VM:

```bash
./install.sh --profile llmero-gemma4 --backend cpu
```

Download model + multimodal projector:

```bash
./scripts/download-model.sh llmero-gemma4
```

Expected files:

```text
models/llmero-gemma4/gemma-4-E4B-it-Q4_K_M.gguf
models/llmero-gemma4/mmproj-gemma-4-E4B-it-Q8_0.gguf
```

## Start OpenAI-Compatible API

Use foreground mode when you want to watch logs in the current terminal. The command keeps running until you stop it with `Ctrl+C`.

Bonsai foreground:

```bash
./scripts/serve.sh llmero-bonsai
```

Gemma 4 foreground:

```bash
./scripts/serve.sh llmero-gemma4
```

For normal workflow use, start each model as a user systemd service. This keeps the API running after the terminal command exits.

Important:

- `llmero-bonsai` now binds the server to `0.0.0.0`
- this is for Docker/container reachability
- local access through `127.0.0.1:8081` still works exactly the same
- only the bind interface changed, not the local URL you use from the machine itself

Bonsai background service:

```bash
systemd-run --user --unit=llmero-bonsai \
  --working-directory=/home/zacmero/projects/LLMero \
  /home/zacmero/projects/LLMero/scripts/serve.sh llmero-bonsai
```

Persistent Bonsai service:

```bash
systemctl --user status llmero-bonsai.service --no-pager
systemctl --user restart llmero-bonsai.service
```

Gemma 4 background service:

```bash
systemd-run --user --unit=llmero-gemma4 \
  --working-directory=/home/zacmero/projects/LLMero \
  /home/zacmero/projects/LLMero/scripts/serve.sh llmero-gemma4
```

Check service status:

```bash
systemctl --user status llmero-bonsai --no-pager
systemctl --user status llmero-gemma4 --no-pager
```

Stop services:

```bash
systemctl --user stop llmero-bonsai
systemctl --user stop llmero-gemma4
```

If you see `couldn't bind HTTP server socket`, that port is already in use. Check the service status or stop the running service before starting another copy.

Endpoints:

```text
Bonsai:  http://127.0.0.1:8081/v1
Gemma 4: http://127.0.0.1:8082/v1
```

For container access on the same host, Bonsai is also reachable through the host bridge path used by Docker-based services such as n8n.

Use Gemma 4 from OpenAI-compatible frameworks with:

```bash
export OPENAI_API_KEY=local
export OPENAI_BASE_URL=http://127.0.0.1:8082/v1
export OPENAI_MODEL=gemma-4-e4b
```

Use Bonsai with:

```bash
export OPENAI_API_KEY=local
export OPENAI_BASE_URL=http://127.0.0.1:8081/v1
export OPENAI_MODEL=bonsai-8b
```

See also: [n8n integration guide](docs/n8n.md)

## Test Gemma Text API

Thinking mode is enabled, so use a larger token budget:

```bash
MAX_TOKENS=512 ./scripts/test-openai.sh \
  llmero-gemma4 \
  "Think briefly, then answer: in one paragraph, what are your strongest local capabilities for my automation workflows?"
```

Raw curl equivalent:

```bash
curl http://127.0.0.1:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-e4b",
    "messages": [
      {
        "role": "user",
        "content": "Think briefly, then answer in one paragraph: what are your strongest local capabilities?"
      }
    ],
    "max_tokens": 512
  }'
```

The response includes:

- `message.reasoning_content`
- `message.content`

## Test Gemma Image API

Default test image:

```bash
MAX_TOKENS=768 ./scripts/test-openai-image.sh llmero-gemma4
```

Custom image URL:

```bash
MAX_TOKENS=768 ./scripts/test-openai-image.sh \
  llmero-gemma4 \
  "https://example.com/image.png" \
  "Describe this image and identify anything actionable."
```

Raw curl equivalent:

```bash
curl http://127.0.0.1:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma-4-e4b",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Describe this image in one concise paragraph."
          },
          {
            "type": "image_url",
            "image_url": {
              "url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.png"
            }
          }
        ]
      }
    ],
    "max_tokens": 768
  }'
```

## Runtime Checks

Check server process:

```bash
pgrep -af 'llama-server|serve.sh'
```

Check GPU usage:

```bash
nvidia-smi
```

Check CPU temperatures:

```bash
sensors
```

Check runtime state:

```bash
cat .llmero/state/llmero-gemma4/runtime.env
```

## Useful Paths

Gemma binaries:

```text
.llmero/build/llmero-gemma4/cuda/bin/llama-cli
.llmero/build/llmero-gemma4/cuda/bin/llama-server
.llmero/build/llmero-gemma4/cuda/bin/llama-mtmd-cli
```

Gemma model files:

```text
models/llmero-gemma4/gemma-4-E4B-it-Q4_K_M.gguf
models/llmero-gemma4/mmproj-gemma-4-E4B-it-Q8_0.gguf
```

Bonsai model file:

```text
models/llmero-bonsai/Bonsai-8B.gguf
```

## Troubleshooting

### `Unsupported gpu architecture 'compute_61'`

The CUDA compiler does not support the requested GPU architecture.

For GTX 1060:

- CUDA 13: does not work for compiling `compute_61`
- CUDA 12.9: works

Use:

```bash
CUDA_HOME=/opt/cuda-12.9 ./install.sh --profile llmero-gemma4 --backend cuda --skip-deps
```

### API Test Cannot Connect

If curl cannot connect from this Codex environment but the server is running, it may be a sandbox network namespace issue. Run the command in your terminal, or run with host permissions.

Check server:

```bash
pgrep -af 'llama-server|serve.sh'
```

### Model Thinks But Does Not Answer

Gemma thinking mode can consume many tokens. Increase token budget:

```bash
MAX_TOKENS=1024 ./scripts/test-openai.sh llmero-gemma4 "Your prompt here"
```

If you want direct responses for a fast workflow, edit `profiles/llmero-gemma4.env` and change:

```bash
--reasoning on
```

to:

```bash
--reasoning off
```

Then restart:

```bash
pkill -f llama-server
./scripts/serve.sh llmero-gemma4
```

### VM Has No CUDA

Use CPU mode:

```bash
./install.sh --profile llmero-gemma4 --backend cpu
```
