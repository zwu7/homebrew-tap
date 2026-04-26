cask "buzz-captions" do
  version "1.4.4"

  on_arm do
    sha256 "956d74ec3db341e04867a4dd727ed22fa8ec629762e505624dcce85a78eb94f8"

    url "https://sourceforge.net/projects/buzz-captions/files/Buzz-#{version}-mac-ARM64.dmg/download",
        verified: "sourceforge.net/projects/buzz-captions/files/"
  end
  on_intel do
    sha256 "514edaa47841069c9f8953bdb0f3619167ed7a19e93427ec35014a89828d2fbb"

    url "https://sourceforge.net/projects/buzz-captions/files/Buzz-#{version}-mac-X64.dmg/download",
        verified: "sourceforge.net/projects/buzz-captions/files/"
  end

  name "Buzz"
  desc "Offline audio transcription and translation app powered by Whisper"
  homepage "https://github.com/chidiwilliams/buzz"

  depends_on macos: ">= :catalina"

  app "Buzz.app"

  zap trash: [
    "~/Library/Application Support/Buzz",
    "~/Library/Caches/Buzz",
    "~/Library/Logs/Buzz",
    "~/Library/Preferences/com.chidiwilliams.buzz.plist",
    "~/Library/Saved Application State/com.chidiwilliams.buzz.savedState",
  ]
end
