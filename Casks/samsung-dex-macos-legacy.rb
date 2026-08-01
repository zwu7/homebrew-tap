cask "samsung-dex-macos-legacy" do
  version "2.4.0.21"
  sha256 "6bf45739e81ad7970ae86147b64bc1df3392154b00672243fb666c62c983a9f6"

  url "https://archive.org/download/samsung-dex-mac/SamsungDeXSetupMac.dmg",
      verified: "archive.org/download/samsung-dex-mac/"
  name "Samsung DeX for Mac"
  desc "Legacy discontinued Samsung DeX desktop client"
  homepage "https://www.samsung.com/us/apps/dex/"

  livecheck do
    skip "Discontinued by Samsung"
  end

  depends_on :macos

  pkg "Install Samsung DeX.pkg"

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
            delete:    "/Library/Extensions/ssuddrv.kext"

  zap trash: [
    "~/Library/Application Support/SamsungDeX",
    "~/Library/Caches/com.samsung.DeXonPC",
    "~/Library/HTTPStorages/com.samsung.DeXonPC",
    "~/Library/Preferences/com.samsung.DeXonPC.plist",
    "~/Library/Saved Application State/com.samsung.DeXonPC.savedState",
  ]

  caveats <<~EOS
    Samsung ended support, updates, and official downloads for DeX for Mac in
    January 2022. This cask installs an archived, unsupported vendor package.

    Disconnect Samsung phones and tablets before installation. The vendor
    installer refuses to continue while a Samsung USB device is attached.

    The main DeX app and connectivity service contain native Apple silicon
    code. The package also installs an obsolete Intel-only Samsung USB kernel
    extension. That extension cannot load on Apple silicon and may cause the
    installer to request a restart. Do not weaken macOS security settings to
    force the legacy extension to load.
  EOS
end
