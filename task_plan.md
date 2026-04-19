# Task Plan

## Goal
Create a single install script for this repo that detects the target machine and installs or configures llama.cpp appropriately for CUDA-capable local hardware and CPU-only cloud VMs.

## Phases

1. Diagnose the current CUDA build failure and confirm the GPU/toolchain constraints.
2. Inspect the repo layout, especially the two `models` subtrees, to understand how installs should differ per project.
3. Design the hardware-aware install flow for Arch and Ubuntu, including CUDA and no-CUDA modes.
4. Implement the install script and any supporting config files.
5. Verify the script logic and document usage.
6. Diagnose host NVIDIA driver, kernel module, CUDA toolkit, and GPU compute capability.
7. Resolve whether the requested Bonsai MLX 2-bit artifact can run through llama.cpp or whether a GGUF conversion/source is required.
8. Install or repair llama.cpp CUDA support for the local Arch machine.
9. Download the selected Bonsai model artifact into `models`.
10. Verify a runnable command path for the Bonsai profile.

## Status
- Phase 1: complete
- Phase 2: complete
- Phase 3: complete
- Phase 4: complete
- Phase 5: complete
- Phase 6: complete
- Phase 7: complete
- Phase 8: complete
- Phase 9: complete
- Phase 10: complete

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| `nvcc fatal : Unsupported gpu architecture 'compute_61'` | 1 | CUDA 13 no longer supports Pascal `compute_61`; installed side-by-side CUDA 12.9 and configured llama.cpp with `CMAKE_CUDA_ARCHITECTURES=61` |
| Profile path did not refresh after `--profile`/`--prefix` parsing | 1 | Added a refresh helper so profile and state paths are recomputed after CLI parsing |
| CPU reached 100C during full parallel build | 1 | Stopped the build, changed installer default to `JOBS=2`, and used `JOBS=1` for the local CUDA build |
| `llama-cli` could not see CUDA from sandboxed command | 1 | Reran outside the sandbox; CUDA detected the GTX 1060 and inference succeeded |
