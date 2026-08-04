cask "pdf-expert" do
  version "2,764"
  sha256 :no_check

  url "https://downloads.pdfexpert.com/versions/#{version.csv.second}/PDFExpert.zip",
      verified: "downloads.pdfexpert.com/versions/"
  name "PDF Expert"
  desc "PDF reader, editor and annotator"
  homepage "https://pdfexpert.com/"

  livecheck do
    skip "Pinned legacy PDF Expert 2 build before PDF Expert 3 account/subscription line"
  end

  auto_updates false
  conflicts_with cask: [
    "homebrew/cask-versions/pdf-expert-beta",
    "homebrew/cask/pdf-expert",
  ]
  depends_on :macos

  app "PDF Expert.app"

  zap trash: [
    "~/Library/Application Support/com.readdle.PDFExpert-Mac",
    "~/Library/Application Support/PDF Expert",
    "~/Library/Caches/com.readdle.PDFExpert-Mac",
    "~/Library/HTTPStorages/com.readdle.PDFExpert-Mac",
    "~/Library/HTTPStorages/com.readdle.PDFExpert-Mac.binarycookies",
    "~/Library/PDF Expert",
    "~/Library/Preferences/com.readdle.PDFExpert-Mac.plist",
    "~/Library/Saved Application State/com.readdle.PDFExpert-Mac.savedState",
  ]
end
