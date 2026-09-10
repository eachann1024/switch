#!/usr/bin/env bash
# Local ad-hoc Release build + replace /Applications/Switch.app
# Requires full Xcode (not only Command Line Tools).
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild unavailable. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

BUILD_DIR="$PROJECT_DIR/build/local"
APP_OUT="$BUILD_DIR/Build/Products/Release/Switch.app"
DEST="/Applications/Switch.app"

echo "==> xcodegen"
xcodegen generate

echo "==> xcodebuild Release (ad-hoc sign)"
rm -rf "$BUILD_DIR"
xcodebuild \
  -project Switch.xcodeproj \
  -scheme Switch \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  build

test -d "$APP_OUT"

echo "==> quit Switch if running"
osascript -e 'tell application "Switch" to quit' 2>/dev/null || true
sleep 1
pkill -x Switch 2>/dev/null || true

echo "==> backup + replace $DEST"
if [[ -d "$DEST" ]]; then
  rm -rf "/tmp/Switch.app.bak"
  ditto "$DEST" "/tmp/Switch.app.bak"
fi
rm -rf "$DEST"
ditto "$APP_OUT" "$DEST"
codesign --force --deep --sign - "$DEST" || true

VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist")
echo "==> installed Switch $VER ($BUILD) at $DEST"
echo "    previous copy (if any): /tmp/Switch.app.bak"
echo "    open with: open -a Switch"
