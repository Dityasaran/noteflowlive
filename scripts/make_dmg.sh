#!/bin/bash
set -e

APP_NAME="NoteFlow"
VERSION=$(cd NoteFlow && swift package dump-package 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','1.0.0'))" 2>/dev/null || echo "1.0.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "📦 Packaging $APP_NAME v$VERSION..."

# Check app exists
if [ ! -d "$APP_PATH" ]; then
  echo "❌ App not found at $APP_PATH. Run build_swift_app.sh first."
  exit 1
fi

# Create staging
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -r "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Copy assets if present
if [ -f "assets/dmg-background.png" ]; then
  mkdir -p "$STAGING_DIR/.background"
  cp assets/dmg-background.png "$STAGING_DIR/.background/background.png"
fi

# Create DMG
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "✅ DMG created: $DMG_PATH"

# Optional notarization
if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_APP_PASSWORD" ]; then
  echo "🔏 Notarizing..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  echo "✅ Notarized and stapled"
fi
