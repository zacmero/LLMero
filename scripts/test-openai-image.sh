#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_NAME="${1:-llmero-gemma4}"
IMAGE_URL="${2:-https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/cats.png}"
PROMPT="${3:-Describe this image in one concise paragraph.}"
MAX_TOKENS="${MAX_TOKENS:-512}"
PROFILE_FILE="$ROOT_DIR/profiles/$PROFILE_NAME.env"

die() {
  printf '[test-openai-image] error: %s\n' "$*" >&2
  exit 1
}

[ -f "$PROFILE_FILE" ] || die "profile not found: $PROFILE_FILE"
# shellcheck disable=SC1090
. "$PROFILE_FILE"

HOST="${LLAMA_SERVER_HOST:-127.0.0.1}"
PORT="${LLAMA_SERVER_PORT:-8080}"
ALIAS="${LLAMA_SERVER_ALIAS:-$PROFILE_NAME}"

curl "http://$HOST:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "model": "$ALIAS",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "$PROMPT"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "$IMAGE_URL"
          }
        }
      ]
    }
  ],
  "max_tokens": $MAX_TOKENS
}
EOF
