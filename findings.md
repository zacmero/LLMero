# Findings

## Initial Context

- Repo root: `/home/zacmero/projects/LLMero`
- Top-level entries currently visible: `llmero-bonsai`, `llmero-gemma4`, `models`

## CUDA Diagnosis

- The pasted failure `nvcc fatal : Unsupported gpu architecture 'compute_61'` is a CUDA toolkit/architecture mismatch, not a driver-vs-GPU absence issue.
- llama.cpp's official build docs say CUDA builds should use `-DGGML_CUDA=ON`, optionally `-DGGML_NATIVE=OFF` for broader CUDA portability, and `-DCMAKE_CUDA_ARCHITECTURES` when the GPU architecture must be set explicitly.
- The new installer now checks whether `nvcc` supports the detected GPU compute capability before trying to build, so this class of error is caught early with a clearer message.
- Local GPU: NVIDIA GeForce GTX 1060 6GB, Pascal, compute capability 6.1.
- Local Arch CUDA package was CUDA 13.2.1. Its `nvcc --list-gpu-arch` starts at `compute_75`, so it cannot build code for the GTX 1060's `compute_61`.
- Side-by-side CUDA 12.9 at `/opt/cuda-12.9` supports `compute_61` and successfully compiled llama.cpp CUDA.
- CUDA 12.9 on this rolling Arch host needed extra compatibility work: `libxml2-legacy`, `gcc14`/`gcc14-libs`, glibc 2.41/2.42 compatibility patches in CUDA headers, and the AUR CCCL preprocessor patch.
- The CPU hit 100C during the first full parallel build. That is the CPU critical limit, not a safe sustained compile temperature. Single-threaded build stayed around 68-74C, and the installer now defaults to `JOBS=2`.

## Bonsai Model

- `prism-ml/Ternary-Bonsai-8B-mlx-2bit` is MLX-only and is not runnable through llama.cpp on this NVIDIA/Linux machine.
- The current runnable llama.cpp artifact is `prism-ml/Bonsai-8B-gguf` with `Bonsai-8B.gguf`.
- Downloaded model path: `/home/zacmero/projects/LLMero/models/llmero-bonsai/Bonsai-8B.gguf`.
- Model size: 1,158,654,496 bytes.
- SHA256: `284a335aa3fb2ced3b1b01fcb40b08aa783e3b70832767f0dd2e3fdfa134bd54`.
- GGUF metadata check: GGUF v3, qwen3 architecture, 36 blocks, 65,536 context length, 4,096 embedding length.

## Validation

- Built `llama-cli` from `https://github.com/PrismML-Eng/llama.cpp.git` with CUDA 12.9, `gcc-14`, and `CMAKE_CUDA_ARCHITECTURES=61`.
- Built binary: `/home/zacmero/projects/LLMero/.llmero/build/llmero-bonsai/cuda/bin/llama-cli`.
- CUDA inference outside the sandbox detected the GTX 1060 and generated successfully.
- Test output speed: prompt processing about 197.7 tokens/sec, generation about 31.9 tokens/sec.
- Reported CUDA memory during test: total 6065 MiB, about 1464 MiB used by model/context/compute for this short context.

## Gemma 4 / Server Architecture

- llama.cpp supports multimodal input through `libmtmd` with `llama-mtmd-cli` and `llama-server` via OpenAI-compatible `/chat/completions`.
- llama.cpp's multimodal docs list Gemma 4 GGUF models as supported, including `ggml-org/gemma-4-E2B-it-GGUF`, `ggml-org/gemma-4-E4B-it-GGUF`, `ggml-org/gemma-4-26B-A4B-it-GGUF`, and `ggml-org/gemma-4-31B-it-GGUF`.
- For the user's requested Gemma 4 4B-class model, use `ggml-org/gemma-4-E4B-it-GGUF`. Hugging Face reports it as Gemma 4 architecture with 8B total params and E4B active class.
- `ggml-org/gemma-4-E4B-it-GGUF` files include `gemma-4-E4B-it-Q4_K_M.gguf` at about 5.34 GB, `mmproj-gemma-4-E4B-it-Q8_0.gguf` at about 560 MB, and `mmproj-gemma-4-E4B-it-bf16.gguf` at about 992 MB.
- `llama-server` is the right integration layer because it exposes OpenAI-compatible `/v1/chat/completions`; profiles should own ports, aliases, context, GPU layer policy, and model/projector source.
- Local Gemma 4 server validated on `http://127.0.0.1:8082/v1` with alias `gemma-4-e4b`.
- Text API test succeeded with thinking enabled, returning both `reasoning_content` and final `content`, at about 27 tokens/sec.
- Image API test succeeded using OpenAI-style `image_url`, returning a correct description of a cat image, at about 26.8 tokens/sec.
- Runtime memory while serving Gemma 4: about 4.3 GB VRAM used on the GTX 1060, CPU package around 55C, GPU around 55C after validation.
