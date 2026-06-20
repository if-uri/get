#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/ifuri-get-smoke-$$"
PORT="${IFURI_GET_SMOKE_PORT:-}"
NODE_NAME="smoke-$$"

cleanup() {
  if [ -n "${RUNNER_PID:-}" ]; then
    kill "$RUNNER_PID" >/dev/null 2>&1 || true
    wait "$RUNNER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

if [ -z "$PORT" ]; then
  PORT="$(
    python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
  )"
fi

LOCAL_URIRUN="$ROOT/../../tellmesh/urihandler/adapters/python"
if [ -z "${URIRUN_GIT_URL:-}" ] && [ -f "$LOCAL_URIRUN/pyproject.toml" ]; then
  export URIRUN_GIT_URL="$LOCAL_URIRUN"
fi

bash -n "$ROOT/node.sh"
bash "$ROOT/node.sh" \
  --name "$NODE_NAME" \
  --port "$PORT" \
  --bind 127.0.0.1 \
  --dir "$TMP/node" \
  --no-start

test -s "$TMP/node/bindings.v2.json"
test -s "$TMP/node/registry.json"
test -x "$TMP/node/run-node.sh"

"$TMP/node/.venv/bin/urirun" list "$TMP/node/registry.json" | grep -q "env://$NODE_NAME/runtime/query/health"

"$TMP/node/run-node.sh" > "$TMP/node/node.log" 2>&1 &
RUNNER_PID="$!"

python3 - "$PORT" <<'PY'
import json
import sys
import time
import urllib.request

port = sys.argv[1]
last_error = None
for _ in range(40):
    try:
        data = urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1).read()
        payload = json.loads(data)
        if payload.get("ok") is True:
            print(f"node health ok on 127.0.0.1:{port}")
            raise SystemExit(0)
    except Exception as exc:  # noqa: BLE001 - smoke reports the last failure
        last_error = exc
        time.sleep(0.25)
raise SystemExit(f"node did not become healthy: {last_error}")
PY

echo "smoke ok: $NODE_NAME on 127.0.0.1:$PORT"
