# if-uri/get

Static installer endpoint for `urirun` nodes.

The goal is intentionally simple: a node computer should be able to install and
start an `urirun node` with one command from `get.ifuri.com`.

## Node one-liner

Foreground:

```bash
curl -fsSL https://get.ifuri.com/node.sh | bash
```

Background:

```bash
curl -fsSL https://get.ifuri.com/node.sh | bash -s -- --background
```

Custom name and port:

```bash
curl -fsSL https://get.ifuri.com/node.sh | bash -s -- --name laptop --port 8765 --background
```

Boot service (Linux `systemd --user` / macOS `launchd`), survives reboot:

```bash
curl -fsSL https://get.ifuri.com/node.sh | bash -s -- --name laptop --service
```

Upgrade an existing install in place (reuses the venv, restarts if running):

```bash
curl -fsSL https://get.ifuri.com/node.sh | bash -s -- --upgrade
```

Windows (PowerShell):

```powershell
irm https://get.ifuri.com/node.ps1 | iex
# named node + boot service (logon Scheduled Task):
# powershell -ExecutionPolicy Bypass -File node.ps1 -Name laptop -Service
```

The installer creates:

- `~/.urirun-node/.venv` with the `urirun` CLI installed from GitHub,
- `~/.urirun-node/bindings.v2.json`,
- `~/.urirun-node/registry.json`,
- `~/.urirun-node/node.json`,
- `~/.urirun-node/run-node.sh`.

## Register the node on a host

On the host computer:

```bash
urirun host init --name host
urirun host add-node laptop http://NODE_IP:8765
urirun host nodes
urirun host routes
urirun host agents
```

Run a natural-language request through the available URI routes:

```bash
urirun host ask "sprawdz stan laptopa i zapisz notatke" --execute
```

Without an LLM key, `urirun host ask --no-llm` uses the built-in heuristic
planner. With LiteLLM configured, set the model and provider environment
variables before running host commands, for example:

```bash
export URIRUN_LLM_MODEL=openai/gpt-4.1-mini
export OPENAI_API_KEY=...
```

## Useful node commands

```bash
~/.urirun-node/run-node.sh
~/.urirun-node/.venv/bin/urirun node routes --config ~/.urirun-node/node.json
~/.urirun-node/.venv/bin/urirun run env://$(hostname)/runtime/query/health \
  --registry ~/.urirun-node/registry.json --execute
```

## Installer options

```txt
--name NAME       Node name used as URI target. Default: hostname.
--port PORT       HTTP port. Default: 8765.
--bind ADDRESS    Bind address. Default: 0.0.0.0.
--dir PATH        Install directory. Default: ~/.urirun-node.
--python PATH     Python executable. Default: python3.
--background      Start node with nohup and return.
--service         Install + enable a boot service (systemd --user / launchd) and start it.
--dry-run         Start the node in non-executing mode.
--no-start        Install and configure, but do not start the node.
--upgrade         Reuse existing venv: upgrade urirun, recompile, restart if running.
--help            Show help.
```

After starting (`--background` or `--service`), the installer health-checks
`http://127.0.0.1:PORT/health` and prints the LAN URL and URI routes.

Service name can be changed without editing the script:

```bash
curl -fsSL https://get.ifuri.com/node.sh | \
  URIRUN_NODE_SERVICE_NAME=urirun-node-laptop bash -s -- --name laptop --service
```

Local smoke test:

```bash
make smoke
make service-smoke  # Linux only: creates a temporary systemd --user unit, then removes it
```

## Pinned urirun version

`node.sh` pins the installed `urirun` to a released tag (default `v0.3.14`) for
reproducible installs rather than tracking `@main`. Override it with the
`URIRUN_REF` environment variable (a git tag or branch), or `URIRUN_GIT_URL` for
a custom source:

```bash
curl -fsSL https://get.ifuri.com/node.sh | URIRUN_REF=v0.3.14 bash
```

The Windows installer (`node.ps1`) pins the same default and accepts `-Ref` (or
`URIRUN_REF`).

## Fallback URL

If DNS for `get.ifuri.com` is not ready yet, use the raw GitHub URL:

```bash
curl -fsSL https://raw.githubusercontent.com/if-uri/get/main/node.sh | bash
```

## Domain setup

GitHub Pages is configured for `get.ifuri.com` from the repository root.
The DNS record for `get.ifuri.com` must point to GitHub Pages:

```txt
get.ifuri.com. CNAME if-uri.github.io.
```

or, if the DNS provider does not support CNAME on this host, use GitHub Pages A
records:

```txt
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

## Verify the installer (optional)

```bash
curl -fsSLO https://get.ifuri.com/node.sh
curl -fsSL  https://get.ifuri.com/node.sh.sha256 | sha256sum -c -   # expects: node.sh: OK
bash node.sh --help            # inspect before running; use --no-start / --dry-run to preview
bash scripts/smoke-node.sh     # local install + health smoke; uses local urirun checkout if present
bash scripts/smoke-service.sh  # optional Linux systemd --user smoke
```

Short link: **https://get.ifuri.com/app** → latest desktop release.
