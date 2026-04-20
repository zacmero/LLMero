#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_NAME="${1:-llmero-bonsai}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE_NAME.env"

die() {
  printf '[download-model] error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[download-model] %s\n' "$*" >&2
}

[ -f "$PROFILE_FILE" ] || die "profile not found: $PROFILE_FILE"
# shellcheck disable=SC1090
. "$PROFILE_FILE"

MODEL_ROOT="${MODEL_ROOT:-$ROOT_DIR/models/$PROFILE_NAME}"
case "$MODEL_ROOT" in
  /*) ;;
  *) MODEL_ROOT="$ROOT_DIR/$MODEL_ROOT" ;;
esac

LLAMA_MODEL_REPO="${LLAMA_MODEL_REPO:-}"
LLAMA_MODEL_FILE="${LLAMA_MODEL_FILE:-}"
LLAMA_MMPROJ_FILE="${LLAMA_MMPROJ_FILE:-}"

[ -n "$LLAMA_MODEL_REPO" ] || die "LLAMA_MODEL_REPO is not set in $PROFILE_FILE"
[ -n "$LLAMA_MODEL_FILE" ] || die "LLAMA_MODEL_FILE is not set in $PROFILE_FILE"

mkdir -p "$MODEL_ROOT"

ensure_huggingface_cli() {
  if command -v hf >/dev/null 2>&1; then
    command -v hf
    return 0
  fi

  if [ -x "$ROOT_DIR/.venv/bin/hf" ]; then
    printf '%s\n' "$ROOT_DIR/.venv/bin/hf"
    return 0
  fi

  command -v python3 >/dev/null 2>&1 || die "python3 is required to install huggingface_hub"
  log "creating .venv and installing huggingface_hub"
  python3 -m venv "$ROOT_DIR/.venv"
  "$ROOT_DIR/.venv/bin/python" -m pip install -U pip huggingface_hub
  printf '%s\n' "$ROOT_DIR/.venv/bin/hf"
}

HF_CLI="$(ensure_huggingface_cli)"

download_file() {
  local file="$1"
  [ -n "$file" ] || return 0
  if [ -f "$MODEL_ROOT/$file" ]; then
    log "already exists: $MODEL_ROOT/$file"
    return 0
  fi

  log "downloading $LLAMA_MODEL_REPO/$file"
  "$HF_CLI" download "$LLAMA_MODEL_REPO" "$file" --local-dir "$MODEL_ROOT"
}

download_file "$LLAMA_MODEL_FILE"
download_file "$LLAMA_MMPROJ_FILE"

log "model files are in $MODEL_ROOT"
