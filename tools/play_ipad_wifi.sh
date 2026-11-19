#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "build/web/index.html" ]]; then
  ./tools/export_web.sh
fi

exec python3 -u tools/serve_lan_qr.py --port "${PORT:-8089}" --mode "${MODE:-tunnel}"
