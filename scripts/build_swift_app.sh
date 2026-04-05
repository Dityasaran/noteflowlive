#!/bin/bash
set -e

APP_NAME="NoteFlow"
SCHEME="NoteFlow"
BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build release
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  archive

# Export app
xcodebuild \
  -exportArchive \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  -exportPath "$BUILD_DIR" \
  -exportOptionsPlist scripts/ExportOptions.plist

echo "✅ Build complete: $APP_PATH"

# Optional code signing (set env vars to enable)
if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "🔐 Code signing..."
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_PATH"
  echo "✅ Signed with: $CODESIGN_IDENTITY"
fi
