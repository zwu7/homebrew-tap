cask "microsoft-powerpoint-2016-1541" do
  version "15.41.17120500"
  sha256 "b531382a013a6846e8ce1943fe9828a11865ada584b3e98b2065258a5d0c3875"

  url "https://officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/Microsoft_PowerPoint_#{version}_Updater.pkg",
      verified: "officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/"
  name "Microsoft PowerPoint 2016 15.41"
  desc "Presentation software pinned to Office 2016 15.41"
  homepage "https://www.microsoft.com/en-US/microsoft-365/powerpoint"

  livecheck do
    skip "Pinned legacy Office 2016 15.41 build"
  end

  auto_updates false

  conflicts_with cask: [
    "microsoft-powerpoint",
    "microsoft-office",
    "microsoft-office-businesspro",
  ]

  pkg "Microsoft_PowerPoint_#{version}_Updater.pkg"

  uninstall quit:    [
              "com.microsoft.Powerpoint",
              "com.microsoft.autoupdate2",
            ],
            pkgutil: "com.microsoft.package.Microsoft_PowerPoint.app",
            delete:  "/Applications/Microsoft PowerPoint.app"
end
