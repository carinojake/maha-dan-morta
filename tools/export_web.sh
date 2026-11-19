#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT_BIN" ]]; then
  echo "❌ Godot binary not found."
  exit 1
fi

TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  echo "📦 Web export template missing — running tools/fetch_web_template.py..."
  python3 tools/fetch_web_template.py
fi

mkdir -p build/web
echo "🌐 Exporting Godot 4 WebAssembly build (WebGL2 single-thread) -> build/web/index.html..."
"$GODOT_BIN" --headless --path . --export-release "Web" build/web/index.html

echo "----------------------------------------"
ls -lh build/web/
