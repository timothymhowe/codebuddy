cask "codebuddy" do
  version "0.1.0"
  sha256 "2190affa8e127555f6a13812af929dc66783c20d39d32091306937f3c5896c17"

  url "https://github.com/timothymhowe/codebuddy/releases/download/v#{version}/CodeBuddy-#{version}.zip"
  name "CodeBuddy"
  desc "Floating 3D desktop companion for Claude Code"
  homepage "https://github.com/timothymhowe/codebuddy"

  depends_on macos: ">= :ventura"

  app "CodeBuddy.app"

  postflight do
    # Ad-hoc signed binaries carry the quarantine bit from the zip download.
    # Strip it so macOS doesn't show the "unidentified developer" dialog on first launch.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/CodeBuddy.app"],
                   sudo: false
  end

  zap trash: [
    "~/.codebuddy",
  ]
end
