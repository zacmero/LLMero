# n8n Setup for LLMero

This repo exposes each model through an OpenAI-style `llama-server` endpoint.
For n8n, keep the server running and point the workflow at the right `base URL`.

## Endpoints

- Gemma 4: `http://127.0.0.1:8082/v1`
- Bonsai: `http://127.0.0.1:8081/v1`

If n8n runs on another machine, replace `127.0.0.1` with the host IP or hostname.

## Model Names

- Gemma 4: `gemma-4-e4b`
- Bonsai: `bonsai-8b`

## What Goes In The API Call

For workflow tasks, send only the messages you want the model to see.
If you do not want a persona, do not send a `system` message.

Example user-only payload:

```json
{
  "model": "gemma-4-e4b",
  "messages": [
    {
      "role": "user",
      "content": "Summarize this task in one sentence."
    }
  ],
  "max_tokens": 256
}
```

## n8n OpenAI Node

Use the OpenAI-compatible node when you only need text.

Set:

- API Key: `local` or any dummy value accepted by your node setup
- Base URL: `http://127.0.0.1:8082/v1` for Gemma, or `http://127.0.0.1:8081/v1` for Bonsai
- Model: `gemma-4-e4b` or `bonsai-8b`

Recommended workflow pattern:

1. Trigger node starts the workflow.
2. Prepare the task text in a Set node or Function node.
3. OpenAI node sends the prompt to `llama-server`.
4. Downstream nodes consume the returned text.

## n8n HTTP Request Node

Use a raw HTTP Request node if you want full control over the payload or if you need multimodal input.

Request:

- Method: `POST`
- URL: `http://127.0.0.1:8082/v1/chat/completions`
- Headers: `Content-Type: application/json`
- Body: JSON

Example:

```json
{
  "model": "gemma-4-e4b",
  "messages": [
    {
      "role": "user",
      "content": "Classify the task and return only the result."
    }
  ],
  "max_tokens": 256
}
```

For Gemma image input, send `content` as an array with `text` and `image_url` parts.

## Server Mode

The model should stay in serving mode.

For manual testing, run a server in the foreground:

```bash
./scripts/serve.sh llmero-gemma4
./scripts/serve.sh llmero-bonsai
```

The foreground command keeps the terminal occupied. Stop it with `Ctrl+C`.

For n8n, use user systemd services so the APIs keep running after the terminal command exits.

Start Gemma 4:

```bash
systemd-run --user --unit=llmero-gemma4 \
  --working-directory=/home/zacmero/projects/LLMero \
  /home/zacmero/projects/LLMero/scripts/serve.sh llmero-gemma4
```

Start Bonsai:

```bash
systemd-run --user --unit=llmero-bonsai \
  --working-directory=/home/zacmero/projects/LLMero \
  /home/zacmero/projects/LLMero/scripts/serve.sh llmero-bonsai
```

Check status:

```bash
systemctl --user status llmero-gemma4 --no-pager
systemctl --user status llmero-bonsai --no-pager
```

Stop services:

```bash
systemctl --user stop llmero-gemma4
systemctl --user stop llmero-bonsai
```

Check listening ports:

```bash
ss -ltnp sport = :8082
ss -ltnp sport = :8081
```

Then point n8n to the correct endpoint for each workflow. If `serve.sh` says it cannot bind the socket, the model is already running on that port.

## Notes

- The WebUI `systemMessage` is a UI setting, not something n8n uses unless you send it.
- Conversations in the WebUI are browser-side state.
- The API only sees what your workflow sends in the request body.
- `systemd-run` creates transient user services. They survive terminal exit, but they are not permanent boot services.
