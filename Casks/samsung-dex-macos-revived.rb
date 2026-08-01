cask "samsung-dex-macos-revived" do
  version "2.4.0.21,6"
  # The archived vendor URL is unversioned, so Homebrew requires :no_check.
  # The postflight installer independently verifies the exact vendor app,
  # executable hash, Info.plist hash, code signature, and Samsung Team ID.
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
            quit:      "com.samsung.DeXonPC",
            pkgutil:   [
              "com.samsung.pkg.dexonpc",
              "com.samsung.pkg.mss_connectivity2",
              "com.samsung.pkg.ssud",
            ],
            delete:    [
              "/Applications/Samsung DeX Revived.app",
              "/Applications/Samsung DeX.app",
              "/Library/Application Support/Samsung DeX Revived",
            ]

  zap trash: [
    "~/Library/Application Support/SamsungDeX",
    "~/Library/Caches/com.samsung.DeXonPC",
    "~/Library/HTTPStorages/com.samsung.DeXonPC",
    "~/Library/Logs/Samsung DeX Revived",
    "~/Library/Preferences/com.samsung.DeXonPC.plist",
    "~/Library/Saved Application State/com.samsung.DeXonPC.savedState",
  ]

  caveats <<~EOS
    This cask installs Rosetta 2 through Apple's softwareupdate when Rosetta
    is not already available. macOS may request an administrator password.

    It installs Samsung's archived DeX for Mac 2.4.0.21 package, verifies the
    exact vendor application and Samsung code signature, and creates one visible
    application:

      /Applications/Samsung DeX Revived.app

    Revision 6 uses the fully validated top-level bundle layout. It preserves
    Samsung's original icon, resources, bundle identifier, and user interface;
    replaces the top-level executable with a wrapper; runs the vendor x86_64
    executable under Rosetta 2; and injects the compatibility shim from the same
    top-level bundle. There is no nested runtime application and no second visible
    Samsung DeX application.

    The shim changes only TerminalInfo SinkType from MAC to Windows. PcVer and
    SinkOSVersion are not spoofed. The validated session produced a full DeX
    desktop, working Mac keyboard/mouse input, and a successful second normal
    Finder/open launch.

    Disconnect Samsung phones before install, reinstall, or uninstall. Reconnect
    the phone only after Homebrew reports that installation has completed.

    macOS may require one-time Accessibility approval for Samsung DeX Revived:
      System Settings -> Privacy & Security -> Accessibility

    Launch "Samsung DeX Revived" from Applications after installation.
  EOS
end
