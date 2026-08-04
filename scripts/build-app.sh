#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Prefer Xcode (beta or release) over bare Command Line Tools so SwiftUI macros work.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  for candidate in \
    "/Applications/Xcode-beta.app/Contents/Developer" \
    "/Applications/Xcode.app/Contents/Developer"
  do
    if [[ -d "$candidate" ]]; then
      export DEVELOPER_DIR="$candidate"
      break
    fi
  done
fi

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "Using DEVELOPER_DIR=$DEVELOPER_DIR"
fi

CONFIG="${1:-release}"
DO_INSTALL=0
if [[ "$CONFIG" == "install" ]]; then
  CONFIG="release"
  DO_INSTALL=1
fi

BUILD_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/dist/CursorUsage.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
INSTALL_DIR="${HOME}/Applications/CursorUsage.app"

echo "Building CursorUsage ($CONFIG)…"
swift build -c "$CONFIG"

mkdir -p "$MACOS" "$RESOURCES"
rm -f "$MACOS/CursorUsage"
cp "$BUILD_DIR/CursorUsage" "$MACOS/CursorUsage"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

# Full-color Cursor mark for the menu bar (must not be templated).
if [[ -f "$ROOT/Sources/CursorUsage/Resources/CursorIcon.png" ]]; then
  cp "$ROOT/Sources/CursorUsage/Resources/CursorIcon.png" "$RESOURCES/CursorIcon.png"
elif [[ -f "/Applications/Cursor.app/Contents/Resources/Cursor.icns" ]]; then
  sips -s format png -z 64 64 \
    "/Applications/Cursor.app/Contents/Resources/Cursor.icns" \
    --out "$RESOURCES/CursorIcon.png" >/dev/null
fi

# Ad-hoc sign so Gatekeeper is happier for local runs.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "App bundle: $APP_DIR"

if [[ "$DO_INSTALL" -eq 1 ]] || [[ "${2:-}" == "install" ]]; then
  echo "Installing to $INSTALL_DIR …"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "$INSTALL_DIR"
  cp -R "$APP_DIR" "$INSTALL_DIR"
  codesign --force --deep --sign - "$INSTALL_DIR" >/dev/null 2>&1 || true

  # Replace any running instance, then launch the installed copy.
  killall CursorUsage 2>/dev/null || true
  open "$INSTALL_DIR"
  echo "Installed + launched. Open at Login is enabled on first launch."
else
  echo "Run with:        open '$APP_DIR'"
  echo "Install + login: ./scripts/build-app.sh install"
fi
