#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_NAME="${1:-llmero-bonsai}"
BACKEND="${BACKEND:-cuda}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE_NAME.env"
RUNTIME_FILE="$ROOT_DIR/.llmero/state/$PROFILE_NAME/runtime.env"

die() {
  printf '[serve] error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[serve] %s\n' "$*"
}

abs_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$ROOT_DIR/$path" ;;
  esac
}

[ -f "$PROFILE_FILE" ] || die "profile not found: $PROFILE_FILE"
# shellcheck disable=SC1090
. "$PROFILE_FILE"

if [ -f "$RUNTIME_FILE" ]; then
  # shellcheck disable=SC1090
  . "$RUNTIME_FILE"
  BACKEND="${LLAMERO_BACKEND:-$BACKEND}"
fi

BIN_DIR="${LLAMERO_BIN_DIR:-$ROOT_DIR/.llmero/build/$PROFILE_NAME/$BACKEND/bin}"
LLAMA_SERVER="${LLAMERO_LLAMA_SERVER:-$BIN_DIR/llama-server}"

[ -x "$LLAMA_SERVER" ] || die "llama-server not found or not executable: $LLAMA_SERVER. Build it with: LLAMA_BUILD_TARGETS=\"llama-cli llama-server\" ./install.sh --profile $PROFILE_NAME --backend $BACKEND"

HOST="${LLAMA_SERVER_HOST:-127.0.0.1}"
PORT="${LLAMA_SERVER_PORT:-8080}"
ALIAS="${LLAMA_SERVER_ALIAS:-$PROFILE_NAME}"
CTX_SIZE="${LLAMA_CONTEXT_SIZE:-4096}"
GPU_LAYERS="${LLAMA_GPU_LAYERS:-}"
MODEL_MODE="${LLAMA_MODEL_MODE:-local}"

args=(
  --host "$HOST"
  --port "$PORT"
  --alias "$ALIAS"
  -c "$CTX_SIZE"
)

if [ -n "$GPU_LAYERS" ]; then
  args+=(-ngl "$GPU_LAYERS")
fi

case "$MODEL_MODE" in
  hf)
    [ -n "${LLAMA_MODEL_REPO:-}" ] || die "LLAMA_MODEL_REPO is required for LLAMA_MODEL_MODE=hf"
    args+=(-hf "$LLAMA_MODEL_REPO")
    ;;
  local)
    MODEL_PATH="$(abs_path "${LLAMA_MODEL_PATH:-${MODEL_ROOT:-models/$PROFILE_NAME}/${LLAMA_MODEL_FILE:-}}")"
    [ -f "$MODEL_PATH" ] || die "model not found: $MODEL_PATH. Run: ./scripts/download-model.sh $PROFILE_NAME"
    args+=(-m "$MODEL_PATH")
    if [ -n "${LLAMA_MMPROJ_PATH:-}" ]; then
      MMPROJ_PATH="$(abs_path "$LLAMA_MMPROJ_PATH")"
      [ -f "$MMPROJ_PATH" ] || die "mmproj not found: $MMPROJ_PATH. Run: ./scripts/download-model.sh $PROFILE_NAME"
      args+=(--mmproj "$MMPROJ_PATH")
    fi
    ;;
  *)
    die "unsupported LLAMA_MODEL_MODE=$MODEL_MODE"
    ;;
esac

if [ -n "${LLAMA_SERVER_EXTRA_ARGS:-}" ]; then
  # Intentional word splitting: profile values are local trusted shell config.
  # shellcheck disable=SC2206
  extra_args=($LLAMA_SERVER_EXTRA_ARGS)
  args+=("${extra_args[@]}")
fi

if [ -z "${CUDA_HOME:-}" ] && [ -d /opt/cuda-12.9/targets/x86_64-linux/lib ]; then
  CUDA_HOME="/opt/cuda-12.9"
fi

export LD_LIBRARY_PATH="$BIN_DIR${CUDA_HOME:+:$CUDA_HOME/targets/x86_64-linux/lib}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

log "starting $PROFILE_NAME on http://$HOST:$PORT/v1 as model '$ALIAS'"
exec "$LLAMA_SERVER" "${args[@]}"
