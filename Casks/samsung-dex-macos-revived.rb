cask "samsung-dex-macos-revived" do
  version "2.4.0.21,4"
  # The archived vendor URL is unversioned, so Homebrew requires :no_check.
  # The postflight installer independently verifies the exact installed app,
  # including its binary hash, Info.plist hash, code signature, and Team ID.
  sha256 :no_check

  url "https://archive.org/download/samsung-dex-mac/SamsungDeXSetupMac.dmg",
      verified: "archive.org/download/samsung-dex-mac/"
  name "Samsung DeX for Mac Revived"
  desc "Legacy DeX client with a local protocol compatibility shim"
  homepage "https://github.com/zwu7/homebrew-tap/blob/main/docs/samsung-dex-macos-revived.md"

  livecheck do
    skip "Discontinued vendor client with a tap-maintained compatibility revision"
  end

  depends_on arch: :arm64
  depends_on macos: :big_sur

  pkg "Install Samsung DeX.pkg"

  preflight do
    revival_installer = Pathname(__dir__).parent/"Scripts/samsung-dex-revived-installer.sh"
    system_command "/bin/bash",
                   args: [
                     revival_installer.to_s,
                     "assert-phone-disconnected",
                   ]
  end

  postflight do
    revival_installer = Pathname(__dir__).parent/"Scripts/samsung-dex-revived-installer.sh"
    system_command "/bin/bash",
                   args: [
                     revival_installer.to_s,
                     "install",
                     "--target-app",
                     "/Applications/Samsung DeX Revived.app",
                     "--no-launch",
                   ]
  end

  uninstall_preflight do
    revival_installer = Pathname(__dir__).parent/"Scripts/samsung-dex-revived-installer.sh"
    system_command "/bin/bash",
                   args: [
                     revival_installer.to_s,
                     "assert-phone-disconnected",
                   ]
  end

  uninstall launchctl: "com.devguru.ssconnservice2",
            quit:      [
              "com.samsung.DeXonPC",
              "com.zwu7.SamsungDeXRevived",
            ],
            pkgutil:   [
              "com.samsung.pkg.dexonpc",
              "com.samsung.pkg.mss_connectivity2",
              "com.samsung.pkg.ssud",
            ],
            delete:    [
              "/Applications/Samsung DeX Revived.app",
              "/Library/Extensions/ssuddrv.kext",
            ]

  zap trash: [
    "~/Library/Application Support/SamsungDeX",
    "~/Library/Caches/com.samsung.DeXonPC",
    "~/Library/HTTPStorages/com.samsung.DeXonPC",
    "~/Library/Logs/Samsung DeX Revived",
    "~/Library/Preferences/com.samsung.DeXonPC.plist",
    "~/Library/Preferences/com.zwu7.SamsungDeXRevived.plist",
    "~/Library/Saved Application State/com.samsung.DeXonPC.savedState",
    "~/Library/Saved Application State/com.zwu7.SamsungDeXRevived.savedState",
  ]

  caveats <<~EOS
    This cask installs Rosetta 2 through Apple's softwareupdate when Rosetta
    is not already available. macOS may request an administrator password.

    It installs Samsung's archived, discontinued DeX for Mac 2.4.0.21
    package, verifies the exact vendor application and Samsung code signature,
    then creates a separate launcher at:

      /Applications/Samsung DeX Revived.app

    Revision 4 uses a unique launcher bundle identifier and directly starts an
    embedded x86_64 runtime. This prevents LaunchServices from activating the
    unmodified original DeX application. Installation also restarts Samsung's
    connectivity service so the first launch can detect the phone.

    The runtime changes only the TerminalInfo SinkType value from MAC to
    Windows. The original /Applications/Samsung DeX.app remains unchanged.

    The compatibility layer was validated on 2026-08-01 with a full DeX
    desktop and working Mac keyboard/mouse input. It does not disable SIP,
    lower Startup Security, or load the obsolete Samsung KEXT.

    Disconnect Samsung phones before install, reinstall, or uninstall. The cask
    checks before any destructive uninstall step and exits without changing the
    existing installation when a Samsung USB device is connected. Reconnect the
    phone after installation completes.

    Launch "Samsung DeX Revived", not the original app.
  EOS
end
