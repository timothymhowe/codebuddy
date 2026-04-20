#!/bin/bash
# Build CodePuppy.app bundle + zip for homebrew cask distribution.
# Outputs:  dist/CodePuppy.app  and  dist/CodePuppy-<version>.zip
#
# Usage:  scripts/make-app.sh [version]

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-${CODEBUDDY_VERSION:-0.2.0}}"
APP_NAME="CodePuppy"
BIN_NAME="CodeBuddy"   # SPM target name (stays CodeBuddy internally)
BUNDLE_ID="com.ailette.codepuppy"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "🔨 Building $APP_NAME $VERSION (universal)"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Regenerate the app icon if source script is newer, or if the icon is missing
if [ ! -f Resources/AppIcon.icns ] || [ scripts/render-icon.swift -nt Resources/AppIcon.icns ]; then
    echo "🎨 rendering AppIcon.icns"
    swift scripts/render-icon.swift >/dev/null
fi

# Universal binary — build arm64 + x86_64, lipo together
swift build -c release --arch arm64 --arch x86_64
BIN_PATH=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
cp "$BIN_PATH/$BIN_NAME" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>        <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>              <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>       <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
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
cp    Resources/AppIcon.icns  "$APP/Contents/Resources/AppIcon.icns"
cp -R models                  "$APP/Contents/Resources/models"
cp -R sounds                  "$APP/Contents/Resources/sounds"
cp -R hooks                   "$APP/Contents/Resources/hooks"
cp -R .claude/commands        "$APP/Contents/Resources/claude-commands"

# Ad-hoc sign
codesign --force --deep --sign - "$APP"

# Zip for release
ZIP="$DIST/$APP_NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
echo ""
echo "✅ Built $APP"
echo "📦 $ZIP"
echo "🔑 sha256: $SHA"
echo ""
echo "Next: update tap's Casks/codepuppy.rb with:"
echo "   version \"$VERSION\""
echo "   sha256  \"$SHA\""
