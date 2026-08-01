cask "samsung-dex-macos-revived" do
  version "2.4.0.21,1"
  sha256 "6bf45739e81ad7970ae86147b64bc1df3392154b00672243fb666c62c983a9f6"

  # Keep a version-specific cache key while retaining SHA-256 verification.
  url "https://archive.org/download/samsung-dex-mac/SamsungDeXSetupMac.dmg?version=#{version.csv.first}",
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

  uninstall launchctl: "com.devguru.ssconnservice2",
            quit:      "com.samsung.DeXonPC",
            kext:      [
              "com.devguru.driver.SamsungACMControl",
              "com.devguru.driver.SamsungACMData",
              "com.devguru.driver.SamsungComposite",
              "com.devguru.driver.SamsungMTP",
              "com.devguru.driver.SamsungSerial",
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
    "~/Library/Saved Application State/com.samsung.DeXonPC.savedState",
  ]

  caveats <<~EOS
    This cask requires Rosetta 2. Install it first if needed:

      softwareupdate --install-rosetta --agree-to-license

    This cask installs Samsung's archived, discontinued DeX for Mac 2.4.0.21
    package, then creates a separate local application at:

      /Applications/Samsung DeX Revived.app

    The revived copy runs the x86_64 client under Rosetta 2 and changes only
    the TerminalInfo SinkType value from MAC to Windows at runtime. The
    original /Applications/Samsung DeX.app remains unchanged.

    The compatibility layer was validated on 2026-08-01 with a full DeX
    desktop and working Mac keyboard/mouse input. It does not disable SIP,
    lower Startup Security, or load the obsolete Samsung KEXT.

    Disconnect Samsung USB devices during installation if the vendor package
    asks you to do so. Launch "Samsung DeX Revived", not the original app.
  EOS
end
