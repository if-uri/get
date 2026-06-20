#!/usr/bin/env bash
# Author: Tom Sapletta · https://tom.sapletta.com
# Part of the ifURI solution.

set -Eeuo pipefail

# Install urirun for the host role: the machine that registers and drives URI
# nodes on the LAN. Pairs with node.sh (which installs a node).

URIRUN_REF="${URIRUN_REF:-v0.3.14}"
URIRUN_GIT_URL="${URIRUN_GIT_URL:-git+https://github.com/tellmesh/urirun.git@${URIRUN_REF}#subdirectory=adapters/python}"
INSTALL_DIR="${URIRUN_HOST_DIR:-$HOME/.urirun-host}"
HOST_NAME="${URIRUN_HOST_NAME:-$(hostname 2>/dev/null || echo host)}"
PYTHON_BIN="${PYTHON:-python3}"
DASHBOARD=0
DASH_PORT="${URIRUN_HOST_DASHBOARD_PORT:-8194}"
ADD_NODES=()

usage() {
  cat <<'USAGE'
Install and configure an urirun host (controls URI nodes on the LAN).

Usage:
  curl -fsSL https://get.ifuri.com/host.sh | bash
  curl -fsSL https://get.ifuri.com/host.sh | bash -s -- --name studio --add-node laptop=http://192.168.1.20:8765

Options:
  --name NAME        Host name. Default: hostname.
  --dir PATH         Install directory. Default: ~/.urirun-host.
  --python PATH      Python executable. Default: python3.
  --add-node NAME=URL Register a node now (repeatable).
  --dashboard        Start the operator dashboard after setup.
  --dashboard-port N Dashboard port. Default: 8194.
  --help             Show this help.

Environment:
  URIRUN_REF         Git tag or branch for the default urirun source. Default: v0.3.14.
  URIRUN_GIT_URL     Git source for urirun Python package.
  URIRUN_HOST_DIR    Install directory.
  URIRUN_HOST_NAME   Host name.
USAGE
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
sanitize_name() { tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_.-' '-' | sed 's/^-//; s/-$//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) [ "$#" -ge 2 ] || die "--name requires a value"; HOST_NAME="$2"; shift 2 ;;
    --dir) [ "$#" -ge 2 ] || die "--dir requires a value"; INSTALL_DIR="$2"; shift 2 ;;
    --python) [ "$#" -ge 2 ] || die "--python requires a value"; PYTHON_BIN="$2"; shift 2 ;;
    --add-node) [ "$#" -ge 2 ] || die "--add-node requires NAME=URL"; ADD_NODES+=("$2"); shift 2 ;;
    --dashboard) DASHBOARD=1; shift ;;
    --dashboard-port) [ "$#" -ge 2 ] || die "--dashboard-port requires a value"; DASH_PORT="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$DASH_PORT" in ''|*[!0-9]*) die "dashboard port must be a number" ;; esac

HOST_NAME="$(printf '%s' "$HOST_NAME" | sanitize_name)"
[ -n "$HOST_NAME" ] || HOST_NAME="host"

need "$PYTHON_BIN"
need git

PYTHON_PATH="$(command -v "$PYTHON_BIN")"
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
VENV_DIR="$INSTALL_DIR/.venv"
MESH_CONFIG="$INSTALL_DIR/mesh.json"
URIRUN="$VENV_DIR/bin/urirun"

printf '==> Installing urirun host "%s" in %s\n' "$HOST_NAME" "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

"$PYTHON_PATH" -m venv "$VENV_DIR" || die "python venv failed; install python3-venv and retry"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install --upgrade "$URIRUN_GIT_URL"

"$URIRUN" host init --name "$HOST_NAME" --config "$MESH_CONFIG" >/dev/null
printf '==> Host mesh config: %s\n' "$MESH_CONFIG"

for pair in ${ADD_NODES[@]+"${ADD_NODES[@]}"}; do
  name="${pair%%=*}"
  url="${pair#*=}"
  if [ -z "$name" ] || [ -z "$url" ] || [ "$name" = "$pair" ]; then
    printf '    warning: ignoring --add-node "%s" (expected NAME=URL)\n' "$pair" >&2
    continue
  fi
  name="$(printf '%s' "$name" | sanitize_name)"
  "$URIRUN" host add-node "$name" "$url" --config "$MESH_CONFIG" >/dev/null
  printf '    registered node: %s -> %s\n' "$name" "$url"
done

printf '\n==> Host ready. Next steps:\n'
printf '  %s host add-node NAME http://NODE_IP:PORT --config %s\n' "$URIRUN" "$MESH_CONFIG"
printf '  %s host nodes  --config %s\n' "$URIRUN" "$MESH_CONFIG"
printf '  %s host routes --config %s\n' "$URIRUN" "$MESH_CONFIG"
printf '  %s host agents --config %s\n' "$URIRUN" "$MESH_CONFIG"
printf '\nInstall a node on another machine: curl -fsSL https://get.ifuri.com/node.sh | bash\n'

if [ "$DASHBOARD" -eq 1 ]; then
  printf '\n==> Starting operator dashboard on http://127.0.0.1:%s ...\n' "$DASH_PORT"
  exec "$URIRUN" host dashboard serve --config "$MESH_CONFIG" --host 127.0.0.1 --port "$DASH_PORT"
fi
