#!/bin/bash
# Local test of the homebrew cask install flow — no github release needed.
# Creates a local brew tap, writes a cask pointing at the local zip via file://,
# then runs `brew install --cask` against it.
#
# Usage:  scripts/test-install.sh

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="0.0.0-test"
ZIP="dist/CodePuppy-$VERSION.zip"
TAP="codepuppy-local/test"
TAP_DIR="$(brew --repository)/Library/Taps/codepuppy-local/homebrew-test"

echo "🔨 building test bundle"
./scripts/make-app.sh "$VERSION" >/dev/null

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
ABS_ZIP="$(pwd)/$ZIP"

# Clean slate
brew uninstall --cask codepuppy 2>/dev/null || true
rm -f "$(brew --cache)"/*codepuppy* 2>/dev/null || true
rm -f "$(brew --cache)"/Cask/*codepuppy* 2>/dev/null || true
brew untap "$TAP" 2>/dev/null || true

mkdir -p "$TAP_DIR/Casks"
if [ ! -d "$TAP_DIR/.git" ]; then
    (cd "$TAP_DIR" && git init -q && git commit -q --allow-empty -m init)
fi

cat > "$TAP_DIR/Casks/codepuppy.rb" << CASK
cask "codepuppy" do
  version "$VERSION"
  sha256 "$SHA"

  url "file://$ABS_ZIP"
  name "CodePuppy"
  desc "Floating 3D desktop companion for Claude Code"
  homepage "https://github.com/timothymhowe/codebuddy"

  depends_on macos: ">= :ventura"

  app "CodePuppy.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/CodePuppy.app"],
                   sudo: false
  end

  zap trash: ["~/.codebuddy"]
end
CASK

echo "📦 installing via brew from local tap $TAP"
brew install --cask "$TAP/codepuppy"

echo ""
echo "✅ installed — /Applications/CodePuppy.app"
echo ""
echo "Try it:         open /Applications/CodePuppy.app"
echo "Uninstall:      brew uninstall --cask codepuppy"
echo "Drop local tap: brew untap $TAP"
