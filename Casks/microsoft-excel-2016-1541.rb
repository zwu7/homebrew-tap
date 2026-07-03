cask "microsoft-excel-2016-1541" do
  version "15.41.17120500"
  sha256 "69de1ce658ab75fc0a7223ff1c9298e1099b5018ce5678d98f646d7bb494c9f4"

  url "https://officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/Microsoft_Excel_#{version}_Updater.pkg",
    verified: "officecdn-microsoft-com.akamaized.net/pr/C1297A47-86C4-4C1F-97FA-950631F94777/OfficeMac/"
  name "Microsoft Excel 2016 15.41"
  desc "Spreadsheet software pinned to Office 2016 15.41"
  homepage "https://www.microsoft.com/en-US/microsoft-365/excel"

  livecheck do
    skip "Pinned legacy Office 2016 15.41 build"
  end

  auto_updates false

  conflicts_with cask: [
    "microsoft-excel",
    "microsoft-office",
    "microsoft-office-businesspro",
  ]

  pkg "Microsoft_Excel_#{version}_Updater.pkg"

  uninstall quit:    [
              "com.microsoft.Excel",
              "com.microsoft.autoupdate2",
            ],
            pkgutil: "com.microsoft.package.Microsoft_Excel.app",
            delete:  "/Applications/Microsoft Excel.app"
end
