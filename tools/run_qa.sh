#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT_BIN" ]]; then
  echo "❌ Godot binary not found. Install Godot 4.3+ or set GODOT_BIN."
  exit 1
fi

TESTS=(
  "tests/test_ui_layout_regression.gd"
  "tests/test_ipad_touch_e2e.gd"
  "tests/test_bai_yueling_cutin_e2e.gd"
  "tests/test_combat_depth_e2e.gd"
  "tests/test_dark_jade_e2e.gd"
  "tests/test_7heroes_costumes_e2e.gd"
  "tests/test_ch3_and_meta_e2e.gd"
  "tests/test_100_floors_e2e.gd"
  "tests/test_p1_progression_e2e.gd"
  "tests/test_p3_polish_e2e.gd"
  "tests/test_hd2d_prototype_e2e.gd"
  "tests/test_quality_mission_e2e.gd"
)

if [[ ! -d ".godot/imported" ]]; then
  echo "📦 Importing Godot assets (first-time setup)..."
  "$GODOT_BIN" --headless --path . --import --quit >/dev/null 2>&1 || true
fi

FAILED=0
PASSED=0

echo "🚀 Running ${#TESTS[@]} Godot Headless QA Suites ($("$GODOT_BIN" --version | head -n 1))..."
for t in "${TESTS[@]}"; do
  OUT="$("$GODOT_BIN" --headless --path . -s "res://$t" 2>&1)" || RC=$?
  RC="${RC:-0}"
  if [[ "$RC" -ne 0 ]] || echo "$OUT" | grep -qE "(SCRIPT ERROR|Parse Error|Assertion failed|FAIL:)"; then
    echo "❌ FAILED: $t (exit=$RC)"
    echo "$OUT" | grep -E "(SCRIPT ERROR|Parse Error|Assertion failed|FAIL:)" | head -n 15
    FAILED=$((FAILED + 1))
  else
    SUMMARY="$(echo "$OUT" | grep -E "PASSED" | tail -n 1 || echo "OK")"
    echo "✅ PASS: $t — $SUMMARY"
    PASSED=$((PASSED + 1))
  fi
  unset RC
done

echo "----------------------------------------"
echo "QA Summary: $PASSED passed, $FAILED failed (total ${#TESTS[@]})"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
