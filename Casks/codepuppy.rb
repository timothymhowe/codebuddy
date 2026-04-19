cask "codepuppy" do
  version "0.2.0"
  sha256 "REPLACE_AFTER_RELEASE"

  url "https://github.com/timothymhowe/codebuddy/releases/download/v#{version}/CodePuppy-#{version}.zip"
  name "CodePuppy"
  desc "Floating 3D desktop companion for Claude Code"
  homepage "https://github.com/timothymhowe/codebuddy"

  depends_on macos: ">= :ventura"

  app "CodePuppy.app"

  postflight do
    # Ad-hoc signed binaries carry the quarantine bit from the zip download.
    # Strip it so macOS doesn't show the "unidentified developer" dialog on first launch.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/CodePuppy.app"],
                   sudo: false
  end

  zap trash: [
    "~/.codebuddy",
  ]
end
