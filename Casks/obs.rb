cask "obs" do
  arch arm: "apple", intel: "intel"

  version "32.2.1"
  sha256 arm:   "6120c995614be17ecd0ee0877514a88b121249e6261cde46d1440b87d7ffd70c",
         intel: "6900a7a6d4422956114cac3c148d871307fdb0530160c2cbb4e97f624c9f85a5"

  url "https://cdn-fastly.obsproject.com/downloads/obs-studio-#{version}-macos-#{arch}.dmg"
  name "OBS"
  desc "Open-source software for live streaming and screen recording"
  homepage "https://obsproject.com/"

  livecheck do
    skip "Pinned to OBS Studio 32.2.1 stable"
  end

  auto_updates true
  depends_on macos: :monterey

  app "OBS.app"
  command_wrapper "obs",
                  executable: "#{appdir}/OBS.app/Contents/MacOS/OBS"

  uninstall delete: "/Library/CoreMediaIO/Plug-Ins/DAL/obs-mac-virtualcam.plugin"

  zap trash: [
    "~/Library/Application Support/obs-studio",
    "~/Library/HTTPStorages/com.obsproject.obs-studio",
    "~/Library/Preferences/com.obsproject.obs-studio.plist",
    "~/Library/Saved Application State/com.obsproject.obs-studio.savedState",
  ]
end
