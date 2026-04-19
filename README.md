# LLMero Setup

This repo now ships a hardware-aware `install.sh` that can:

- Install the basic build dependencies on Arch or Ubuntu/Debian.
- Build `llama.cpp` in CPU mode for cloud VMs with no NVIDIA stack.
- Build `llama.cpp` in CUDA mode on NVIDIA machines when `nvcc` is available and supports the detected GPU architecture.
- Keep per-project runtime state under `./.llmero/state/<profile>/`.

## Quick Start

CPU-only VM:

```bash
./install.sh --profile llmero-bonsai --backend cpu
```

Auto-detect mode:

```bash
./install.sh
```

Specific profile:

```bash
./install.sh --profile llmero-gemma4
```

Local CUDA Bonsai build on this GTX 1060 machine:

```bash
CUDA_HOME=/opt/cuda-12.9 \
LLAMA_REPO_URL=https://github.com/PrismML-Eng/llama.cpp.git \
./install.sh --profile llmero-bonsai --backend cuda --skip-deps
```

Use `JOBS=1` if the CPU starts approaching 90C during compilation.

## Profile Files

Starter profile templates live in `profiles/*.env.example`.
Copy the matching example to `profiles/<name>.env` and edit it when the model-specific paths are known.

The Bonsai profile currently points at:

- Hugging Face repo: `prism-ml/Bonsai-8B-gguf`
- Model file: `Bonsai-8B.gguf`
- Local path: `models/llmero-bonsai/Bonsai-8B.gguf`

## Run Bonsai

CUDA one-shot command:

```bash
LD_LIBRARY_PATH=.llmero/build/llmero-bonsai/cuda/bin:/opt/cuda-12.9/targets/x86_64-linux/lib \
.llmero/build/llmero-bonsai/cuda/bin/llama-cli \
  -m models/llmero-bonsai/Bonsai-8B.gguf \
  -p "Write one short sentence about bonsai trees." \
  -n 32 -c 1024 -ngl 99 \
  --temp 0.5 --top-p 0.85 --top-k 20 \
  --single-turn --simple-io --no-display-prompt
```

CPU-only command after a CPU build:

```bash
.llmero/build/llmero-bonsai/cpu/bin/llama-cli \
  -m models/llmero-bonsai/Bonsai-8B.gguf \
  -p "Write one short sentence about bonsai trees." \
  -n 32 -c 1024 \
  --temp 0.5 --top-p 0.85 --top-k 20 \
  --single-turn --simple-io --no-display-prompt
```

## CUDA Build Note

If the installer detects that `nvcc` does not support the detected GPU compute capability, it stops early with a clear error.
That is the same class of failure as:

`nvcc fatal : Unsupported gpu architecture 'compute_61'`

On this local machine, the issue was the opposite of "too old": CUDA 13 no longer supports Pascal `compute_61`, while the GTX 1060 requires it. The working path is CUDA 12.9 from `/opt/cuda-12.9`.

## Temperature Note

100C on this CPU is the critical limit reported by `sensors`, not a safe sustained build temperature. Keep compile jobs low on this host:

```bash
JOBS=1 ./install.sh --profile llmero-bonsai --backend cuda --skip-deps
```
