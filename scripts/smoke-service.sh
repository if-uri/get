#!/usr/bin/env bash
# Author: Tom Sapletta · https://tom.sapletta.com
# Part of the ifURI solution.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$(uname -s 2>/dev/null || true)" != "Linux" ]; then
  echo "service smoke skipped: Linux/systemd user test only"
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user is-system-running >/dev/null 2>&1; then
  echo "service smoke skipped: systemd --user is not running"
  exit 0
fi

TMP="${TMPDIR:-/tmp}/ifuri-get-service-smoke-$$"
PORT="${IFURI_GET_SERVICE_SMOKE_PORT:-}"
NODE_NAME="service-smoke-$$"
SERVICE_NAME="urirun-node-service-smoke-$$"
SERVICE_UNIT="$SERVICE_NAME.service"

cleanup() {
  systemctl --user disable --now "$SERVICE_UNIT" >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/$SERVICE_UNIT"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
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

LOCAL_URIRUN="${LOCAL_URIRUN:-$ROOT/../urirun/adapters/python}"
if [ -z "${URIRUN_GIT_URL:-}" ] && [ -f "$LOCAL_URIRUN/pyproject.toml" ]; then
  export URIRUN_GIT_URL="$LOCAL_URIRUN"
fi

URIRUN_NODE_SERVICE_NAME="$SERVICE_NAME" \
  bash "$ROOT/node.sh" \
    --name "$NODE_NAME" \
    --port "$PORT" \
    --bind 127.0.0.1 \
    --dir "$TMP/node" \
    --service

systemctl --user is-active --quiet "$SERVICE_UNIT"

python3 - "$PORT" <<'PY'
import json
import sys
import urllib.request

port = sys.argv[1]
payload = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2).read())
if payload.get("ok") is not True:
    raise SystemExit(payload)
print(f"service health ok on 127.0.0.1:{port}")
PY

echo "service smoke ok: $SERVICE_UNIT"
