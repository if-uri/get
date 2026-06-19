#!/usr/bin/env bash
set -Eeuo pipefail

URIRUN_REF="${URIRUN_REF:-v0.3.12}"
URIRUN_GIT_URL="${URIRUN_GIT_URL:-git+https://github.com/tellmesh/urirun.git@${URIRUN_REF}#subdirectory=adapters/python}"
INSTALL_DIR="${URIRUN_NODE_DIR:-$HOME/.urirun-node}"
NODE_NAME="${URIRUN_NODE_NAME:-$(hostname 2>/dev/null || echo node)}"
PORT="${URIRUN_NODE_PORT:-8765}"
BIND="${URIRUN_NODE_BIND:-0.0.0.0}"
PYTHON_BIN="${PYTHON:-python3}"
START_NODE=1
BACKGROUND=0
EXECUTE=1
PORT_EXPLICIT=0
UPGRADE=0

usage() {
  cat <<'USAGE'
Install and run an urirun node.

Usage:
  curl -fsSL https://get.ifuri.com/node.sh | bash
  curl -fsSL https://get.ifuri.com/node.sh | bash -s -- --name laptop --port 8765 --background

Options:
  --name NAME       Node name used as URI target. Default: hostname.
  --port PORT       HTTP port. Default: 8765.
  --bind ADDRESS    Bind address. Default: 0.0.0.0.
  --dir PATH        Install directory. Default: ~/.urirun-node.
  --python PATH     Python executable. Default: python3.
  --background      Start node with nohup and return.
  --dry-run         Start node without executing command routes.
  --no-start        Install and configure, but do not start the node.
  --upgrade         Reuse existing venv: upgrade urirun, recompile, restart if running.
  --help            Show this help.

Environment:
  URIRUN_REF        Git tag or branch for the default urirun source. Default: v0.3.12.
  URIRUN_GIT_URL    Git source for urirun Python package.
  URIRUN_NODE_DIR   Install directory.
  URIRUN_NODE_NAME  Node name.
  URIRUN_NODE_PORT  Node HTTP port.
  URIRUN_NODE_BIND  Node bind address.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

sanitize_name() {
  tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_.-' '-' | sed 's/^-//; s/-$//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || die "--name requires a value"
      NODE_NAME="$2"
      shift 2
      ;;
    --port)
      [ "$#" -ge 2 ] || die "--port requires a value"
      PORT="$2"
      PORT_EXPLICIT=1
      shift 2
      ;;
    --bind)
      [ "$#" -ge 2 ] || die "--bind requires a value"
      BIND="$2"
      shift 2
      ;;
    --dir)
      [ "$#" -ge 2 ] || die "--dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --python)
      [ "$#" -ge 2 ] || die "--python requires a value"
      PYTHON_BIN="$2"
      shift 2
      ;;
    --background)
      BACKGROUND=1
      shift
      ;;
    --dry-run)
      EXECUTE=0
      shift
      ;;
    --no-start)
      START_NODE=0
      shift
      ;;
    --upgrade)
      UPGRADE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$PORT" in
  ''|*[!0-9]*) die "port must be a number" ;;
esac

NODE_NAME="$(printf '%s' "$NODE_NAME" | sanitize_name)"
[ -n "$NODE_NAME" ] || NODE_NAME="node"

need "$PYTHON_BIN"
need git

PYTHON_PATH="$(command -v "$PYTHON_BIN")"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
VENV_DIR="$INSTALL_DIR/.venv"
BINDINGS="$INSTALL_DIR/bindings.v2.json"
REGISTRY="$INSTALL_DIR/registry.json"
NODE_CONFIG="$INSTALL_DIR/node.json"
RUNNER="$INSTALL_DIR/run-node.sh"
LOG_FILE="$INSTALL_DIR/node.log"

if [ "$UPGRADE" -eq 1 ]; then
  [ -d "$VENV_DIR" ] || die "no existing install at $INSTALL_DIR (run without --upgrade first)"
  printf '==> Upgrading urirun node at %s\n' "$INSTALL_DIR"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null
  "$VENV_DIR/bin/python" -m pip install --upgrade "$URIRUN_GIT_URL"
  if [ -f "$BINDINGS" ]; then
    "$VENV_DIR/bin/urirun" validate "$BINDINGS" >/dev/null
    "$VENV_DIR/bin/urirun" compile "$BINDINGS" --out "$REGISTRY" >/dev/null
  fi
  VER="$("$VENV_DIR/bin/python" -c 'import importlib.metadata as m; print(m.version("urirun"))' 2>/dev/null || echo '?')"
  printf '==> urirun is now %s\n' "$VER"
  SERVE_MATCH="urirun node serve --config $NODE_CONFIG"
  if pgrep -f "$SERVE_MATCH" >/dev/null 2>&1; then
    pkill -f "$SERVE_MATCH" || true
    sleep 1
    nohup "$RUNNER" > "$LOG_FILE" 2>&1 &
    printf '==> Restarted running node, pid=%s (log: %s)\n' "$!" "$LOG_FILE"
  else
    printf '==> Node is not running; start it with: %s\n' "$RUNNER"
  fi
  exit 0
fi

port_is_free() {
  "$PYTHON_PATH" - "$BIND" "$1" <<'PY' >/dev/null 2>&1
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((host, port))
PY
}

if ! port_is_free "$PORT"; then
  if [ "$PORT_EXPLICIT" -eq 1 ]; then
    die "port $PORT is already in use; pass a different --port"
  fi
  START_PORT="$PORT"
  FOUND_PORT=""
  for CANDIDATE in $(seq "$START_PORT" "$((START_PORT + 50))"); do
    if port_is_free "$CANDIDATE"; then
      FOUND_PORT="$CANDIDATE"
      break
    fi
  done
  [ -n "$FOUND_PORT" ] || die "no free port found in range $START_PORT-$((START_PORT + 50))"
  PORT="$FOUND_PORT"
  printf '==> Default port %s is busy, using %s\n' "$START_PORT" "$PORT"
fi

printf '==> Installing urirun node "%s" in %s\n' "$NODE_NAME" "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

"$PYTHON_PATH" -m venv "$VENV_DIR" || die "python venv failed; install python3-venv and retry"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install --upgrade "$URIRUN_GIT_URL"

cat > "$BINDINGS" <<JSON
{
  "version": "urirun.bindings.v2",
  "bindings": {
    "env://$NODE_NAME/runtime/query/health": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {}
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import json,platform,socket; print(json.dumps({'hostname':socket.gethostname(),'platform':platform.platform(),'python':platform.python_version()}))"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Node runtime health" }
    },
    "proc://$NODE_NAME/process/query/list": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "limit": { "type": "integer", "default": 12, "minimum": 1, "maximum": 50 }
        }
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import json,subprocess,sys; limit=int(sys.argv[1]); cmd=['ps','-eo','pid=,comm=,pcpu=,pmem=','--sort=-pcpu']; out=subprocess.check_output(cmd, text=True).splitlines()[:limit]; print(json.dumps({'processes':out}))",
        "{limit}"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "List top local processes" }
    },
    "shell://$NODE_NAME/command/date": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {}
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import datetime; print(datetime.datetime.now().astimezone().isoformat())"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Print local date" }
    },
    "shell://$NODE_NAME/command/uname": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {}
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import platform; print(platform.platform())"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Print platform name" }
    },
    "shell://$NODE_NAME/command/which": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "required": ["binary"],
        "properties": {
          "binary": { "type": "string", "minLength": 1 }
        }
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import shutil,sys; print(shutil.which(sys.argv[1]) or '')",
        "{binary}"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Find executable path" }
    },
    "log://$NODE_NAME/session/command/write": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "required": ["text"],
        "properties": {
          "text": { "type": "string", "minLength": 1 }
        }
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import json,pathlib,sys,time; p=pathlib.Path.home()/'.urirun-node'/'notes.jsonl'; p.parent.mkdir(parents=True, exist_ok=True); rec={'at':time.time(),'text':sys.argv[1]}; p.open('a', encoding='utf-8').write(json.dumps(rec)+'\\\\n'); print(json.dumps(rec))",
        "{text}"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Write local node log entry" }
    },
    "log://$NODE_NAME/session/query/recent": {
      "kind": "command",
      "adapter": "argv-template",
      "inputSchema": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "limit": { "type": "integer", "default": 20, "minimum": 1, "maximum": 200 }
        }
      },
      "argv": [
        "$PYTHON_PATH",
        "-c",
        "import json,pathlib,sys; p=pathlib.Path.home()/'.urirun-node'/'notes.jsonl'; limit=int(sys.argv[1]); print(json.dumps({'logs': p.read_text(encoding='utf-8').splitlines()[-limit:] if p.exists() else []}))",
        "{limit}"
      ],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Read local node log entries" }
    }
  }
}
JSON

"$VENV_DIR/bin/urirun" validate "$BINDINGS" >/dev/null
"$VENV_DIR/bin/urirun" compile "$BINDINGS" --out "$REGISTRY" >/dev/null

INIT_ARGS=(node init --config "$NODE_CONFIG" --name "$NODE_NAME" --registry "$REGISTRY" --host "$BIND" --port "$PORT")
if [ "$EXECUTE" -eq 1 ]; then
  INIT_ARGS+=(--execute)
fi
"$VENV_DIR/bin/urirun" "${INIT_ARGS[@]}" >/dev/null

if [ "$EXECUTE" -eq 1 ]; then
  cat > "$RUNNER" <<SH
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$VENV_DIR/bin/urirun" node serve --config "$NODE_CONFIG" --execute
SH
else
  cat > "$RUNNER" <<SH
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$VENV_DIR/bin/urirun" node serve --config "$NODE_CONFIG"
SH
fi
chmod +x "$RUNNER"

NODE_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
[ -n "$NODE_IP" ] || NODE_IP="NODE_IP"

printf '\n==> Node config written\n'
printf 'bindings: %s\nregistry: %s\nconfig:   %s\nrunner:   %s\n' "$BINDINGS" "$REGISTRY" "$NODE_CONFIG" "$RUNNER"
printf '\n==> On the host computer, register this node:\n'
printf 'urirun host add-node %s http://%s:%s\n\n' "$NODE_NAME" "$NODE_IP" "$PORT"

if [ "$START_NODE" -eq 0 ]; then
  printf '==> Not starting node because --no-start was used.\n'
  exit 0
fi

if [ "$BACKGROUND" -eq 1 ]; then
  nohup "$RUNNER" > "$LOG_FILE" 2>&1 &
  printf '==> urirun node started in background, pid=%s\n' "$!"
  printf 'log: %s\n' "$LOG_FILE"
  "$VENV_DIR/bin/python" - "$PORT" "$NODE_IP" "$REGISTRY" "$LOG_FILE" <<'PY'
import json, sys, time, urllib.request
port, ip, registry, log = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
for _ in range(20):
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1).read()
        break
    except Exception:
        time.sleep(0.5)
else:
    print(f"==> Warning: node not healthy yet; check {log}")
    sys.exit(0)
try:
    doc = json.load(open(registry, encoding="utf-8"))
    routes = list((doc.get("routes") or doc.get("index") or doc.get("bindings") or {}).keys())
except Exception:
    routes = []
print(f"==> Node healthy: {len(routes)} URI route(s)")
for r in routes[:12]:
    print("  ", r)
print(f"LAN: http://{ip}:{port}/  (health: /health)")
PY
else
  printf '==> Starting urirun node in foreground on %s:%s\n' "$BIND" "$PORT"
  printf 'Press Ctrl-C to stop.\n\n'
  exec "$RUNNER"
fi
