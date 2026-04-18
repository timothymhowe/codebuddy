#!/bin/bash
# Local test of the homebrew cask install flow — no github release needed.
# Creates a local brew tap, writes a cask pointing at the local zip via file://,
# then runs `brew install --cask` against it.
#
# Usage:  scripts/test-install.sh

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="0.0.0-test"
ZIP="dist/CodeBuddy-$VERSION.zip"
TAP="codebuddy-local/test"
TAP_DIR="$(brew --repository)/Library/Taps/codebuddy-local/homebrew-test"

echo "🔨 building test bundle"
./scripts/make-app.sh "$VERSION" >/dev/null

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
ABS_ZIP="$(pwd)/$ZIP"

# Clean slate: uninstall prior + drop any cached download + drop prior tap
brew uninstall --cask codebuddy 2>/dev/null || true
rm -f "$(brew --cache)"/*codebuddy* 2>/dev/null || true
rm -f "$(brew --cache)"/Cask/*codebuddy* 2>/dev/null || true
brew untap "$TAP" 2>/dev/null || true

# Create a minimal local tap (brew tap-new needs a git repo, so init one)
mkdir -p "$TAP_DIR/Casks"
if [ ! -d "$TAP_DIR/.git" ]; then
    (cd "$TAP_DIR" && git init -q && git commit -q --allow-empty -m init)
fi

cat > "$TAP_DIR/Casks/codebuddy.rb" << CASK
cask "codebuddy" do
  version "$VERSION"
  sha256 "$SHA"

  url "file://$ABS_ZIP"
  name "CodeBuddy"
  desc "Floating 3D desktop companion for Claude Code"
  homepage "https://github.com/timothymhowe/codebuddy"

  depends_on macos: ">= :ventura"

  app "CodeBuddy.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/CodeBuddy.app"],
                   sudo: false
  end

  zap trash: ["~/.codebuddy"]
end
CASK

echo "📦 installing via brew from local tap $TAP"
brew install --cask "$TAP/codebuddy"

echo ""
echo "✅ installed — /Applications/CodeBuddy.app"
echo ""
echo "Try it:         open /Applications/CodeBuddy.app"
echo "Uninstall:      brew uninstall --cask codebuddy"
echo "Drop local tap: brew untap $TAP"
