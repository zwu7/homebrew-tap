cask "android-platform-tools-stable" do
  version "37.0.0"
  sha256 "094a1395683c509fd4d48667da0d8b5ef4d42b2abfcd29f2e8149e2f989357c7"

  url "https://dl.google.com/android/repository/platform-tools_r#{version}-darwin.zip",
      verified: "google.com/android/repository/"
  name "Android SDK Platform-Tools Stable"
  desc "Pinned non-Canary Android command-line platform tools"
  homepage "https://developer.android.com/tools/releases/platform-tools"

  no_autobump! because: "Pinned to the latest non-Canary Platform-Tools release"

  conflicts_with cask: "android-platform-tools"

  binary "platform-tools/adb"
  binary "platform-tools/etc1tool"
  binary "platform-tools/fastboot"
  binary "platform-tools/hprof-conv"
  binary "platform-tools/make_f2fs"
  binary "platform-tools/make_f2fs_casefold"
  binary "platform-tools/mke2fs"

  # No zap stanza required
end
