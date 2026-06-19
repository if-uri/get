#!/usr/bin/env bash
# Publish get.ifuri.com (static installer landing).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${IFURI_DEPLOY_HOST:-ifuri@ifuri.com}"
DOCROOT="${IFURI_GET_DOCROOT:-/var/www/vhosts/ifuri.com/get.ifuri.com}"
echo "== deploy get.ifuri.com =="
rsync -az --delete --exclude '.git' --exclude 'scripts' --exclude 'Makefile' --exclude 'CNAME' --exclude 'node.sh.sha256' \
  "${ROOT}/" "${REMOTE}:${DOCROOT}/"
ssh "${REMOTE}" "cd '${DOCROOT}' && find . -type d -exec chmod 755 {} + && find . -type f -exec chmod 644 {} + && sha256sum node.sh > node.sh.sha256 && chmod 644 node.sh.sha256"
curl -fsSI "https://get.ifuri.com/" | head -3 || true
echo done
