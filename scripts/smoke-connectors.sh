#!/usr/bin/env bash
# Author: Tom Sapletta · https://tom.sapletta.com
# Part of the ifURI solution.

# Smoke test: install a node with connectors and verify the node serves the
# connector routes plus the MCP tools and A2A card projections.
#
# Installs a node via node.sh with --connectors http-check,time-tools, then
# checks /routes, /mcp/tools and /a2a/card on the running node. Connector
# install needs network (GitHub); when it is unavailable the node still comes
# up with its base routes and the endpoint checks still run.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/ifuri-get-conn-smoke-$$"
PORT="${IFURI_GET_SMOKE_PORT:-}"
NODE_NAME="conn-smoke-$$"
CONNECTORS="${IFURI_GET_SMOKE_CONNECTORS:-http-check,time-tools}"

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

# Use a local urirun checkout when present so the test runs offline.
LOCAL_URIRUN="${LOCAL_URIRUN:-$ROOT/../urirun/adapters/python}"
if [ -z "${URIRUN_GIT_URL:-}" ] && [ -f "$LOCAL_URIRUN/pyproject.toml" ]; then
  export URIRUN_GIT_URL="$LOCAL_URIRUN"
fi

bash -n "$ROOT/node.sh"
bash "$ROOT/node.sh" \
  --name "$NODE_NAME" \
  --port "$PORT" \
  --bind 127.0.0.1 \
  --dir "$TMP/node" \
  --connectors "$CONNECTORS" \
  --no-start

test -s "$TMP/node/registry.json"

# Did the connectors install? (network-dependent)
CONN_OK=0
if "$TMP/node/.venv/bin/urirun" list "$TMP/node/registry.json" | grep -qE 'httpcheck://|time://'; then
  CONN_OK=1
  echo "connector routes present in registry"
else
  echo "note: connector routes absent (offline install?); verifying base endpoints"
fi

"$TMP/node/run-node.sh" > "$TMP/node/node.log" 2>&1 &
RUNNER_PID="$!"

python3 - "$PORT" "$CONN_OK" <<'PY'
import json, sys, time, urllib.request

port, conn_ok = sys.argv[1], sys.argv[2] == "1"
base = f"http://127.0.0.1:{port}"

def get(path):
    return json.loads(urllib.request.urlopen(base + path, timeout=2).read())

# Wait for health.
for _ in range(40):
    try:
        if get("/health").get("ok") is True:
            break
    except Exception:
        time.sleep(0.25)
else:
    raise SystemExit("node did not become healthy")
print(f"health ok on {base}")

# /routes must respond and list routes.
routes_doc = get("/routes")
routes = routes_doc if isinstance(routes_doc, list) else (
    routes_doc.get("routes") or routes_doc.get("uris") or list(routes_doc.keys()))
assert routes, "/routes returned no routes"
print(f"/routes ok: {len(routes)} route(s)")

# MCP tools projection.
mcp = get("/mcp/tools")
tools = mcp.get("tools") if isinstance(mcp, dict) else mcp
assert tools, "/mcp/tools returned no tools"
print(f"/mcp/tools ok: {len(tools)} tool(s)")

# A2A agent card.
card = get("/a2a/card")
assert isinstance(card, dict) and card, "/a2a/card returned no card"
print("/a2a/card ok")

# When connectors installed, their routes must show up in the projections.
if conn_ok:
    blob = json.dumps(routes) + json.dumps(tools)
    assert "httpcheck" in blob or "time" in blob, "connector routes missing from projections"
    print("connector routes present in MCP/route projections")
PY

echo "smoke ok: $NODE_NAME on 127.0.0.1:$PORT (connectors: $CONNECTORS)"
