cask "scrcpy-static" do
  arch arm: "aarch64", intel: "x86_64"

  version "4.1"
  sha256 arm:   "20fd47c9014dd5e0fa77091f3cb7adbda8445a360c4584aeaa0150b5b3988ff3",
         intel: "ee2a7223bc8dbdc4f482db1134bcf441178dafb833492b71ca4c22090c58ce72"

  url "https://github.com/Genymobile/scrcpy/releases/download/v#{version}/scrcpy-macos-#{arch}-v#{version}.tar.gz",
      verified: "github.com/Genymobile/scrcpy/"
  name "scrcpy Official Static Build"
  desc "Display and control Android devices using the upstream static build"
  homepage "https://github.com/Genymobile/scrcpy"

  livecheck do
    url :homepage
    regex(/^v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  bundle_dir = "#{staged_path}/scrcpy-macos-#{arch}-v#{version}"

  # The upstream macOS archive is a portable bundle. Launch the real binary
  # from inside that bundle so it deterministically uses the colocated adb,
  # scrcpy-server, icons, and statically linked libraries.
  command_wrapper "scrcpy", content: <<~SH
    #!/bin/sh
    exec "#{bundle_dir}/scrcpy" "$@"
  SH
  manpage "#{bundle_dir}/scrcpy.1"

  # No zap stanza required
end
