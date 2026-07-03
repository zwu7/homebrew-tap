cask "microsoft-word-2016-1541" do
  version "15.41.17120500"
  sha256 "61d2e8dbc14e9418a566937bcbc883b4ef3ed06e54932a78cbe30352fac1b978"

  url "https://officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_Word_#{version}_Updater.pkg",
      verified: "officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/"
  name "Microsoft Word 2016 15.41"
  desc "Word processor pinned to Office 2016 15.41 for legacy EndNote CWYW compatibility"
  homepage "https://www.microsoft.com/en-US/microsoft-365/word"

  livecheck do
    skip "Pinned legacy Office 2016 15.41 build"
  end

  auto_updates false

  conflicts_with cask: [
    "microsoft-word",
    "microsoft-office",
    "microsoft-office-businesspro",
  ]

  pkg "Microsoft_Word_#{version}_Updater.pkg"

  uninstall quit:    [
              "com.microsoft.Word",
              "com.microsoft.autoupdate2",
            ],
            pkgutil: "com.microsoft.package.Microsoft_Word.app",
            delete:  "/Applications/Microsoft Word.app"
end
