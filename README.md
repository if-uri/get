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
--dry-run         Start the node in non-executing mode.
--no-start        Install and configure, but do not start the node.
--help            Show help.
```

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
