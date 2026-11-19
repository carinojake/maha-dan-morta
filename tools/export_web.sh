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
echo "🌐 Exporting มหาแดนพันภพ (PWA Landscape WebGL2) -> build/web/index.html..."
"$GODOT_BIN" --headless --path . --export-release "Web" build/web/index.html

python3 - <<'PY'
import json, pathlib

web_dir = pathlib.Path("build/web")
manifest_path = web_dir / "index.manifest.json"
if manifest_path.exists():
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    data["name"] = "มหาแดนพันภพ"
    data["short_name"] = "มหาแดนพันภพ"
    data["orientation"] = "landscape"
    data["display"] = "standalone"
    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("📱 Patched PWA manifest:", manifest_path)

(web_dir / ".nojekyll").write_text("", encoding="utf-8")
(web_dir / "_headers").write_text(
    "/*\n"
    "  X-Content-Type-Options: nosniff\n"
    "  Referrer-Policy: strict-origin-when-cross-origin\n"
    "/index.manifest.json\n"
    "  Content-Type: application/manifest+json; charset=utf-8\n"
    "  Cache-Control: no-cache\n"
    "/index.service.worker.js\n"
    "  Cache-Control: no-cache\n",
    encoding="utf-8",
)
PY

echo "----------------------------------------"
ls -lh build/web/
