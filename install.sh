#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_DIR="${PREFIX_DIR:-$ROOT_DIR/.llmero}"
LLAMA_REPO_URL="${LLAMA_REPO_URL:-https://github.com/ggml-org/llama.cpp.git}"
LLAMA_REPO_REF="${LLAMA_REPO_REF:-master}"
PROFILE_NAME="${PROFILE_NAME:-llmero-bonsai}"
BACKEND_MODE="${BACKEND_MODE:-auto}"
SKIP_DEPS="${SKIP_DEPS:-0}"
JOBS="${JOBS:-2}"
CUDA_HOME="${CUDA_HOME:-}"
LLAMA_BUILD_TARGETS="${LLAMA_BUILD_TARGETS:-${LLAMA_BUILD_TARGET:-llama-cli}}"

PROFILE_DIR="$ROOT_DIR/profiles"

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  printf '[install] warning: %s\n' "$*" >&2
}

die() {
  printf '[install] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --profile NAME        Select project profile (default: llmero-bonsai)
  --backend MODE        auto, cuda, or cpu (default: auto)
  --prefix DIR          Install root for source/build artifacts (default: ./.llmero)
  --repo URL            llama.cpp git repository URL
  --ref REF             llama.cpp git ref or branch (default: master)
  --skip-deps           Do not install system packages
  --target TARGETS      Space-separated CMake targets to build (default: llama-cli)
  -h, --help            Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE_NAME="${2:-}"; shift 2 ;;
    --backend)
      BACKEND_MODE="${2:-}"; shift 2 ;;
    --prefix)
      PREFIX_DIR="${2:-}"; shift 2 ;;
    --repo)
      LLAMA_REPO_URL="${2:-}"; shift 2 ;;
    --ref)
      LLAMA_REPO_REF="${2:-}"; shift 2 ;;
    --skip-deps)
      SKIP_DEPS=1; shift ;;
    --target)
      LLAMA_BUILD_TARGETS="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "unknown argument: $1" ;;
  esac
done

refresh_profile_paths() {
  PROFILE_FILE="$PROFILE_DIR/$PROFILE_NAME.env"
  PROFILE_EXAMPLE="$PROFILE_DIR/$PROFILE_NAME.env.example"
  STATE_DIR="$PREFIX_DIR/state/$PROFILE_NAME"
  SRC_DIR="${LLAMA_SRC_DIR:-$PREFIX_DIR/src/$PROFILE_NAME/llama.cpp}"
}

refresh_profile_paths

os_id=""
os_like=""
pkg_manager=""
install_cmd=""
NVCC_BIN=""

detect_os() {
  [ -f /etc/os-release ] || die "cannot detect OS: /etc/os-release is missing"
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="${ID:-}"
  os_like="${ID_LIKE:-}"

  case "$os_id" in
    arch|manjaro|endeavouros|artix)
      pkg_manager="pacman"
      install_cmd="sudo pacman -S --needed"
      ;;
    ubuntu|debian)
      pkg_manager="apt"
      install_cmd="sudo apt-get install -y"
      ;;
    *)
      case "$os_like" in
        *arch*)
          pkg_manager="pacman"
          install_cmd="sudo pacman -S --needed"
          ;;
        *debian*|*ubuntu*)
          pkg_manager="apt"
          install_cmd="sudo apt-get install -y"
          ;;
        *)
          die "unsupported distro: ${PRETTY_NAME:-$os_id}"
          ;;
      esac
      ;;
  esac
}

install_deps() {
  [ "$SKIP_DEPS" = "1" ] && return 0

  case "$pkg_manager" in
    pacman)
      log "installing base build dependencies for Arch"
      sudo pacman -S --needed git base-devel cmake
      ;;
    apt)
      log "installing base build dependencies for Ubuntu/Debian"
      sudo apt-get update
      sudo apt-get install -y git build-essential cmake
      ;;
    *)
      die "package manager not set"
      ;;
  esac
}

ensure_profile_file() {
  mkdir -p "$PROFILE_DIR"

  if [ ! -f "$PROFILE_FILE" ] && [ -f "$PROFILE_EXAMPLE" ]; then
    cp "$PROFILE_EXAMPLE" "$PROFILE_FILE"
    log "created profile file from example: $PROFILE_FILE"
  fi

  if [ ! -f "$PROFILE_FILE" ]; then
    cat >"$PROFILE_FILE" <<EOF
# Profile for $PROFILE_NAME
PROJECT_NAME="$PROFILE_NAME"
MODEL_ROOT="$ROOT_DIR/models/$PROFILE_NAME"
RUN_ROOT="$ROOT_DIR/$PROFILE_NAME"
LLAMA_EXTRA_ARGS=""
EOF
    log "created default profile file: $PROFILE_FILE"
  fi

  # shellcheck disable=SC1090
  . "$PROFILE_FILE"
}

detect_nvidia_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi -L >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

detect_compute_capability() {
  if ! detect_nvidia_gpu; then
    return 1
  fi

  local cc
  cc="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n 1 | tr -d '[:space:]' || true)"
  if [ -n "$cc" ]; then
    printf '%s\n' "$cc"
    return 0
  fi

  return 1
}

find_nvcc() {
  if [ -n "$CUDA_HOME" ] && [ -x "$CUDA_HOME/bin/nvcc" ]; then
    printf '%s\n' "$CUDA_HOME/bin/nvcc"
    return 0
  fi

  if [ -x /opt/cuda-12.9/bin/nvcc ]; then
    printf '%s\n' /opt/cuda-12.9/bin/nvcc
    return 0
  fi

  if [ -x /opt/cuda/bin/nvcc ]; then
    printf '%s\n' /opt/cuda/bin/nvcc
    return 0
  fi

  command -v nvcc 2>/dev/null || return 1
}

nvcc_supports_arch() {
  local arch="$1"
  [ -n "$NVCC_BIN" ] || NVCC_BIN="$(find_nvcc || true)"
  [ -n "$NVCC_BIN" ] || return 1
  "$NVCC_BIN" --list-gpu-arch 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -q "compute_${arch}"
}

maybe_install_cuda_toolkit() {
  NVCC_BIN="$(find_nvcc || true)"
  [ -n "$NVCC_BIN" ] && return 0

  case "$pkg_manager" in
    pacman)
      if detect_nvidia_gpu; then
        log "CUDA GPU detected but nvcc is missing; trying Arch cuda package"
        sudo pacman -S --needed cuda
      fi
      ;;
    apt)
      if detect_nvidia_gpu; then
        log "CUDA GPU detected but nvcc is missing; trying Ubuntu/Debian nvidia-cuda-toolkit"
        sudo apt-get install -y nvidia-cuda-toolkit || true
      fi
      ;;
  esac
}

choose_backend() {
  local requested="$BACKEND_MODE"
  local gpu_cc=""

  if [ "$requested" = "cpu" ]; then
    printf 'cpu\n'
    return 0
  fi

  if detect_nvidia_gpu; then
    maybe_install_cuda_toolkit
    NVCC_BIN="$(find_nvcc || true)"
    if [ -n "$NVCC_BIN" ]; then
      gpu_cc="$(detect_compute_capability || true)"
      if [ -n "$gpu_cc" ]; then
        if nvcc_supports_arch "${gpu_cc//./}"; then
          printf 'cuda:%s\n' "$gpu_cc"
          return 0
        fi
        die "nvcc does not support compute_${gpu_cc//./}; this matches the build failure you pasted. Install a CUDA toolkit that still supports this GPU architecture, or force --backend cpu."
      fi

      if [ "$requested" = "cuda" ]; then
        warn "CUDA backend requested but compute capability could not be queried; proceeding with native CUDA build"
        printf 'cuda:\n'
        return 0
      fi

      printf 'cuda:\n'
      return 0
    fi

    if [ "$requested" = "cuda" ]; then
      die "CUDA backend requested but nvcc is not installed"
    fi

    warn "NVIDIA GPU found but no CUDA toolkit available; falling back to CPU"
  fi

  printf 'cpu\n'
}

clone_or_update_llama() {
  mkdir -p "$PREFIX_DIR/src"

  if [ -d "$SRC_DIR/.git" ]; then
    log "updating llama.cpp source"
    git -C "$SRC_DIR" fetch --all --tags --prune
    git -C "$SRC_DIR" checkout "$LLAMA_REPO_REF"
    return 0
  fi

  log "cloning llama.cpp"
  git clone "$LLAMA_REPO_URL" "$SRC_DIR"
  git -C "$SRC_DIR" checkout "$LLAMA_REPO_REF"
}

build_llama() {
  local backend_spec="$1"
  local backend_name="${backend_spec%%:*}"
  local backend_arch="${backend_spec#*:}"
  local build_dir="$PREFIX_DIR/build/$PROFILE_NAME/$backend_name"
  local install_dir="$PREFIX_DIR/install/$PROFILE_NAME/$backend_name"

  mkdir -p "$build_dir" "$install_dir" "$STATE_DIR"

  local cmake_args=(
    -S "$SRC_DIR"
    -B "$build_dir"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$install_dir"
  )

  if [ "$backend_name" = "cuda" ]; then
    cmake_args+=(-DGGML_CUDA=ON -DGGML_NATIVE=OFF)
    cmake_args+=(-DCMAKE_CUDA_FLAGS="--allow-unsupported-compiler -Wno-deprecated-gpu-targets")
    if command -v gcc-14 >/dev/null 2>&1 && command -v g++-14 >/dev/null 2>&1; then
      cmake_args+=(-DCMAKE_C_COMPILER=gcc-14 -DCMAKE_CXX_COMPILER=g++-14 -DCMAKE_CUDA_HOST_COMPILER=g++-14)
    fi
    if [ -n "$NVCC_BIN" ]; then
      local cuda_root
      cuda_root="$(cd "$(dirname "$NVCC_BIN")/.." && pwd)"
      cmake_args+=(-DCMAKE_CUDA_COMPILER="$NVCC_BIN" -DCUDAToolkit_ROOT="$cuda_root")
    fi
    if [ -n "$backend_arch" ]; then
      cmake_args+=(-DCMAKE_CUDA_ARCHITECTURES="${backend_arch//./}")
    fi
  else
    cmake_args+=(-DGGML_CUDA=OFF -DGGML_NATIVE=ON)
  fi

  log "configuring llama.cpp for $backend_name"
  cmake "${cmake_args[@]}"

  local build_targets=()
  read -r -a build_targets <<<"$LLAMA_BUILD_TARGETS"
  if [ "${#build_targets[@]}" -eq 0 ]; then
    die "no CMake build targets requested"
  fi

  local target
  for target in "${build_targets[@]}"; do
    log "building llama.cpp target: $target"
    cmake --build "$build_dir" --config Release --target "$target" -j"$JOBS"
  done

  log "installing built runtime files to $install_dir"
  cmake --install "$build_dir" --component Runtime || warn "runtime install step failed; using build directory binaries"

  cat >"$STATE_DIR/runtime.env" <<EOF
LLAMERO_PROFILE="$PROFILE_NAME"
LLAMERO_BACKEND="$backend_name"
LLAMERO_INSTALL_DIR="$install_dir"
LLAMERO_BUILD_DIR="$build_dir"
LLAMERO_BIN_DIR="$build_dir/bin"
LLAMERO_LLAMA_CLI="$build_dir/bin/llama-cli"
LLAMERO_LLAMA_SERVER="$build_dir/bin/llama-server"
LLAMERO_LLAMA_MTMD_CLI="$build_dir/bin/llama-mtmd-cli"
LLAMERO_MODEL_ROOT="${MODEL_ROOT:-$ROOT_DIR/models/$PROFILE_NAME}"
LLAMERO_RUN_ROOT="${RUN_ROOT:-$ROOT_DIR/$PROFILE_NAME}"
LLAMERO_EXTRA_ARGS="${LLAMA_EXTRA_ARGS:-}"
LLAMERO_LD_LIBRARY_PATH="$build_dir/bin"
EOF

  log "wrote runtime state: $STATE_DIR/runtime.env"
}

main() {
  detect_os
  install_deps
  ensure_profile_file
  clone_or_update_llama
  local backend_spec
  backend_spec="$(choose_backend)"
  NVCC_BIN="$(find_nvcc || true)"
  build_llama "$backend_spec"
}

main "$@"
