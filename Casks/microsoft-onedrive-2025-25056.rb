cask "microsoft-onedrive-2025-25056" do
  version "25.056.0324.0003"
  sha256 "f3bbd264da8d72f7e95200d87b675028dfb65b16de4dc888a421cb0a156eaa76"

  url "https://oneclient.sfx.ms/Mac/Installers/25.056.0324.0003/universal/OneDrive.pkg",
      verified: "oneclient.sfx.ms/Mac/Installers/"
  name "Microsoft OneDrive 2025 25.056"
  desc "Cloud storage client pinned to OneDrive 2025 25.056"
  homepage "https://www.microsoft.com/en-us/microsoft-365/onedrive/online-cloud-storage"

  livecheck do
    skip "Pinned legacy OneDrive 2025 25.056 build"
  end

  auto_updates false
  conflicts_with cask: [
    "microsoft-office",
    "microsoft-office-businesspro",
    "onedrive",
  ]
  depends_on arch: :arm64
  depends_on :macos

  pkg "OneDrive.pkg"

  uninstall launchctl: [
              "com.microsoft.OneDriveStandaloneUpdater",
              "com.microsoft.OneDriveStandaloneUpdaterDaemon",
              "com.microsoft.OneDriveUpdaterDaemon",
              "com.microsoft.SyncReporter",
            ],
            quit:      [
              "com.microsoft.OneDrive",
              "com.microsoft.OneDrive.FinderSync",
              "com.microsoft.OneDriveUpdater",
            ],
            pkgutil:   "com.microsoft.OneDrive",
            delete:    [
              "/Applications/OneDrive.app",
              "/Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist",
              "/Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist",
              "/Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist",
              "/Library/Logs/Microsoft/OneDrive",
            ]

  caveats <<~EOS
    This cask intentionally pins OneDrive to #{version}.
    Homebrew auto-upgrades are disabled, but OneDrive has its own updater.

    Hard-freeze helper:
      bash "/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/microsoft-onedrive-2025-25056-freeze.sh"

    Re-enable updates before uninstalling or changing versions:
      bash "/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Scripts/microsoft-onedrive-2025-25056-unfreeze.sh"
  EOS
end
