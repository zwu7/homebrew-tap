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

  command_wrapper "scrcpy", content: <<~SH
    #!/bin/sh
    bundle_dir='#{bundle_dir}'
    export SCRCPY_SERVER_PATH="$bundle_dir/scrcpy-server"

    if command -v adb >/dev/null 2>&1; then
      export ADB="$(command -v adb)"
    else
      export ADB="$bundle_dir/adb"
    fi

    exec "$bundle_dir/scrcpy" "$@"
  SH

  manpage "#{bundle_dir}/scrcpy.1"

  # No zap stanza required
end
