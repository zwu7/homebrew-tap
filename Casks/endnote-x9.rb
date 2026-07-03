cask "endnote-x9" do
  version "19.3.3.15659,X9"
  sha256 "7266d87c42c5ed57f7ab1d929cc8004737e2ba5ada2e4a5cd60c9e127b52514b"

  url "https://download.endnote.com/downloads/#{version.csv.second}/EndNote#{version.csv.second}Installer.dmg",
      verified: "download.endnote.com/downloads/#{version.csv.second}/"
  name "EndNote X9"
  desc "Reference manager"
  homepage "https://endnote.com/"

  livecheck do
    skip "Pinned to EndNote X9 for legacy license compatibility"
  end

  conflicts_with cask: "endnote"

  container nested: "Install EndNote #{version.csv.second}.app/Contents/Resources/EndNote.zip"

  suite "EndNote"

  postflight do
    [
      "#{appdir}/EndNote/Spell/Dictionary Converter.app",
      "#{appdir}/EndNote/Services/ENService.app",
      "#{appdir}/EndNote/ENService.app",
      "#{Dir.home}/Library/Services/ENService.app",

      # Old Word CWYW bundles. Word 2008 contains EndNoteCwywHelper.app,
      # which can appear separately in Launchpad.
      "#{appdir}/EndNote/Cite While You Write/EndNote CWYW Word 2008.bundle",
      "#{appdir}/EndNote/Cite While You Write/EndNote CWYW Word 2011.bundle",
    ].each do |path|
      FileUtils.rm_rf(path) if File.exist?(path)
    end
  end

  zap trash: [
    "/Library/Application Support/ResearchSoft/EndNote",
    "~/Library/Application Support/EndNote",
    "~/Library/Caches/com.ThomsonResearchSoft.EndNote",
    "~/Library/Cookies/com.ThomsonResearchSoft.EndNote.binarycookies",
    "~/Library/HTTPStorages/com.ThomsonResearchSoft.EndNote",
    "~/Library/HTTPStorages/com.ThomsonResearchSoft.EndNote.binarycookies",
    "~/Library/Preferences/com.ThomsonResearchSoft.EndNote.plist",
    "~/Library/Preferences/com.ThomsonReuters.EndNoteCustomizer.plist",
    "~/Library/Services/ENService.app",
    "~/Library/Spotlight/EndNote.mdimporter",
    "~/Library/WebKit/com.ThomsonResearchSoft.EndNote",
  ]
end
