#!/bin/bash
# Build CodeBuddy.app bundle + zip for homebrew cask distribution.
# Outputs:  dist/CodeBuddy.app  and  dist/CodeBuddy-<version>.zip
#
# Usage:  scripts/make-app.sh [version]
#   version defaults to $CODEBUDDY_VERSION or "0.1.0"

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-${CODEBUDDY_VERSION:-0.1.0}}"
APP_NAME="CodeBuddy"
BUNDLE_ID="com.ailette.codebuddy"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "🔨 Building $APP_NAME $VERSION (universal)"

# Clean
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary — build arm64 + x86_64, lipo together
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>        <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>              <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>       <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>NSHumanReadableCopyright</key>  <string>MIT License</string>
</dict>
</plist>
PLIST

# Copy resources into bundle
cp -R models   "$APP/Contents/Resources/models"
cp -R sounds   "$APP/Contents/Resources/sounds"
cp -R hooks    "$APP/Contents/Resources/hooks"

# Ad-hoc sign (users still need to right-click-open first time; see README)
codesign --force --deep --sign - "$APP"

# Zip for release (ditto preserves symlinks / extended attrs)
ZIP="$DIST/$APP_NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo ""
echo "✅ Built $APP"
echo "📦 $ZIP"
echo "🔑 sha256: $SHA"
echo ""
echo "Next: upload $ZIP to a github release, then update Casks/codebuddy.rb with:"
echo "   version \"$VERSION\""
echo "   sha256  \"$SHA\""
