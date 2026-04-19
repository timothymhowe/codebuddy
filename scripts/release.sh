#!/bin/bash
# End-to-end release: tag, build, and create a github release with the zip attached.
# Requires `gh` cli logged in.
#
# Usage:  scripts/release.sh <version>
#   e.g.  scripts/release.sh 0.1.0

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>}"
TAG="v$VERSION"
ZIP="dist/CodePuppy-$VERSION.zip"

# Ensure clean working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ uncommitted changes — commit or stash first"
    exit 1
fi

echo "🔨 Building $TAG"
./scripts/make-app.sh "$VERSION"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')

echo "🏷  tagging $TAG"
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

echo "📤 uploading to github release"
gh release create "$TAG" "$ZIP" \
    --title "CodePuppy $TAG" \
    --notes "sha256: \`$SHA\`

Install:
\`\`\`
brew install --cask timothymhowe/codebuddy/codepuppy
\`\`\`"

echo ""
echo "✅ released $TAG"
echo ""
echo "Now bump the cask in your tap repo:"
echo "  version \"$VERSION\""
echo "  sha256  \"$SHA\""
