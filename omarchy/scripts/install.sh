#!/usr/bin/env bash
# Install cursor-usage-waybar and wire it into Omarchy Waybar.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${CARGO_HOME:-$HOME/.cargo}/bin"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
MODULE_SRC="$ROOT/waybar/module-cursor-usage.json"
MODULE_DST="$WAYBAR_DIR/module-cursor-usage.json"
STYLE_SRC="$ROOT/waybar/cursor-usage.css"
STYLE_DST="$WAYBAR_DIR/cursor-usage.css"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need cargo
need install

echo "==> Building release binary"
cargo install --path "$ROOT" --force

if [[ ! -x "$BIN_DIR/cursor-usage-waybar" ]]; then
  echo "Binary not found at $BIN_DIR/cursor-usage-waybar" >&2
  echo "Ensure $BIN_DIR is on your PATH." >&2
  exit 1
fi

mkdir -p "$WAYBAR_DIR"
install -m 644 "$MODULE_SRC" "$MODULE_DST"
install -m 644 "$STYLE_SRC" "$STYLE_DST"

echo
echo "Installed:"
echo "  binary : $BIN_DIR/cursor-usage-waybar"
echo "  module : $MODULE_DST"
echo "  style  : $STYLE_DST"
echo
echo "Next steps for Omarchy:"
echo "  1. Ensure ~/.config/waybar/config.jsonc includes custom modules, e.g.:"
echo "       \"include\": [\"~/.config/waybar/module-*.json\"]"
echo "     (Omarchy’s modular Waybar setup already does this in many installs.)"
echo
echo "  2. Add \"custom/cursor-usage\" to modules-right, for example after tray:"
echo "       \"modules-right\": ["
echo "         \"group/tray-expander\","
echo "         \"custom/cursor-usage\","
echo "         \"bluetooth\","
echo "         \"network\","
echo "         \"pulseaudio\","
echo "         \"cpu\","
echo "         \"battery\""
echo "       ]"
echo
echo "  3. Import the CSS once in ~/.config/waybar/style.css:"
echo "       @import \"cursor-usage.css\";"
echo
echo "  4. Reload Waybar:"
echo "       pkill waybar && omarchy-restart-waybar 2>/dev/null || waybar &"
echo
echo "Smoke test:"
echo "  CURSOR_USAGE_FORCE_VISIBLE=1 cursor-usage-waybar --text"
echo "  CURSOR_USAGE_FORCE_VISIBLE=1 cursor-usage-waybar"
