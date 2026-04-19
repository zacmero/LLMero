# Progress Log

## Session Start

- Started planning and repo inspection for a cross-device llama.cpp install workflow.
- Next: inspect repo structure and diagnose the CUDA install failure.

## Implementation

- Added `install.sh` with OS detection, dependency installation, CUDA/CPU backend selection, profile loading, llama.cpp cloning, build, and install steps.
- Added starter profile templates for `llmero-bonsai` and `llmero-gemma4`.
- Added a top-level README describing the install flow and the CUDA failure mode.
- Verified `install.sh` passes `bash -n` and its `--help` output renders correctly.

## Local CUDA Repair

- Confirmed the host GPU is a GTX 1060 6GB with compute capability 6.1.
- Confirmed Arch CUDA 13 cannot compile `compute_61`, which caused the AUR `llama.cpp-cuda` failure.
- Installed and used CUDA 12.9 side-by-side at `/opt/cuda-12.9` so Pascal support remains available without replacing the system CUDA package.
- Installed compatibility packages and patches needed for CUDA 12.9 on the current Arch/glibc/GCC stack.
- Reconfigured llama.cpp CUDA with `CUDA_HOME=/opt/cuda-12.9`, `CMAKE_CUDA_ARCHITECTURES=61`, and `gcc-14`/`g++-14`.
- Stopped the original high-parallel build after the CPU reached 100C. Rebuilt with `JOBS=1`, keeping CPU package temperatures around 68-74C.
- Updated `install.sh` to default to `JOBS=2` and build only the `llama-cli` target unless overridden.

## Bonsai Test

- Determined the requested `Ternary-Bonsai-8B-mlx-2bit` artifact is MLX-only and not usable with llama.cpp on this NVIDIA/Linux host.
- Selected `prism-ml/Bonsai-8B-gguf` as the runnable 1-bit GGUF path.
- Downloaded `Bonsai-8B.gguf` to `models/llmero-bonsai/`.
- Verified the file is GGUF v3 and recorded SHA256 `284a335aa3fb2ced3b1b01fcb40b08aa783e3b70832767f0dd2e3fdfa134bd54`.
- Built `llama-cli` successfully at `.llmero/build/llmero-bonsai/cuda/bin/llama-cli`.
- Ran a CUDA inference test outside the sandbox. llama.cpp found the GTX 1060, generated one sentence, and reported about 31.9 tokens/sec generation speed.
