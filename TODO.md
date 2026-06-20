# TODO

## Installer roadmap

- [ ] Implement IFURI-019: add host/node install bundles and a `doctor` command
      that checks Python, service status, LAN reachability, hub access,
      Docker/noVNC prerequisites and firewall hints.
- [ ] Add a bundle for "demo lab" that installs the connector set used by the
      full host-node Docker matrix.
- [x] Add an explicit `--connectors` option to install selected connector
      packages during node bootstrap. (node.sh `--connectors`, bindings merged)
- [x] Print a ready-to-copy `urirun host add-node ...` command after a
      successful node install. (node.sh prints it after config is written)
- [x] Add a host installer one-liner next to `node.sh`. (`host.sh`)
- [x] Add a smoke scenario that installs a node, installs `http-check` and
      `time-tools`, then verifies `/routes`, MCP tools and A2A card output.
      (`scripts/smoke-connectors.sh`, `make connector-smoke`; verified live)
- [x] Add a documented laptop-to-host LAN setup flow linked from `docs.ifuri.com`.
      (README "Laptop-to-host LAN flow" + docs.ifuri.com/host-node-lan.html)
- [x] Keep the default `URIRUN_REF` aligned with the latest tested runtime
      release tag. (`v0.3.14`)

## Related resources

- Runtime: https://github.com/if-uri/urirun
- App/host: https://github.com/if-uri/app
- Examples: https://github.com/if-uri/examples
- Connector hub: https://connect.ifuri.com
- Work summary: https://github.com/if-uri/docs/blob/main/work-summary-2026-06-20.md
