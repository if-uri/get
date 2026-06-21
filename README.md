# get-ifuri-com

Download page for the **ifURI desktop app** and Python package, published to
get.ifuri.com.

The urirun node/host installers moved to get.urirun.com (see if-uri/get-urirun-com);
`/node.sh` and `/host.sh` here 301-redirect there.

```bash
./scripts/deploy-plesk.sh   # or: make deploy (Plesk, get.ifuri.com)
```

## License

Released under the terms in [LICENSE](LICENSE).

## What it serves
- Desktop builds of the ifURI app (resolved from `if-uri/app` GitHub Releases) and the pip install command.
- A 301 redirect for `/node.sh`, `/host.sh`, `/node.ps1` to [get.urirun.com](https://get.urirun.com).

## Development
```bash
make serve    # preview locally
make test     # validate the page (scripts/check_site.py)
make deploy   # publish + post-deploy "download & run the app" test
```

## Ecosystem
[ifuri.com](https://ifuri.com) · [docs.ifuri.com](https://docs.ifuri.com) · [urirun.com](https://urirun.com) · [connect.ifuri.com](https://connect.ifuri.com)
