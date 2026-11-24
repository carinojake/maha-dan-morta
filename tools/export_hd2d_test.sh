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

BACKUP_PROJECT="$(mktemp)"
cp project.godot "$BACKUP_PROJECT"

restore_project() {
  if [[ -f "$BACKUP_PROJECT" ]]; then
    cp "$BACKUP_PROJECT" project.godot
    rm -f "$BACKUP_PROJECT"
    echo "🔒 Restored project.godot to original main_scene."
  fi
}
trap restore_project EXIT

python3 - <<'PY'
import pathlib, re

p = pathlib.Path("project.godot")
text = p.read_text(encoding="utf-8")
patched, n = re.subn(
    r'^run/main_scene=".*"$',
    'run/main_scene="res://scenes/test_hd2d_prototype.tscn"',
    text,
    flags=re.MULTILINE,
)
if n == 0:
    raise SystemExit("Failed to locate run/main_scene in project.godot")
p.write_text(patched, encoding="utf-8")
print("🔧 Temporarily set run/main_scene -> res://scenes/test_hd2d_prototype.tscn")
PY

mkdir -p build/hd2d_web
echo "🌐 Exporting HD-2D Prototype (WebGL2 Compatibility) -> build/hd2d_web/index.html..."
"$GODOT_BIN" --headless --path . --export-release "Web" build/hd2d_web/index.html

python3 - <<'PY'
import json, pathlib

web_dir = pathlib.Path("build/hd2d_web")
manifest_path = web_dir / "index.manifest.json"
if manifest_path.exists():
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    data["name"] = "มหาแดนพันภพ HD-2D Prototype"
    data["short_name"] = "HD-2D Test"
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

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")"
echo "----------------------------------------"
ls -lh build/hd2d_web/
echo "----------------------------------------"
echo "✅ HD-2D WebGL2 Export Complete!"
echo "📡 Mac LAN IP: $LAN_IP"
echo "▶️  Run local web server:"
echo "   python3 -m http.server 8090 -d build/hd2d_web"
echo "📱 Open on iPad / iPhone Safari:"
echo "   http://${LAN_IP}:8090/"
