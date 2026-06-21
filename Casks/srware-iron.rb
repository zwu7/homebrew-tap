cask "srware-iron" do
  arch = Hardware::CPU.arm? ? "macARM" : "mac"
  
  version "135.0.0.0"
  
  url "https://www.srware.net/downloads/iron-#{arch}.dmg"
  name "SRWare Iron"
  desc "Privacy-focused web browser based on Chromium"
  homepage "https://www.srware.net/iron/"
  
  livecheck do
    url :homepage
    regex(/macOS\s*Version:\s*(\d+(?:\.\d+)+)/i)
  end
  
  if Hardware::CPU.arm?
    sha256 "3c66c21a6e8fcb34853aecee49bf57f11df1f669deeda1f9f41d73e854efa453"
  else
    sha256 "8c649dc4016f504028f5ef6ad00e88bd25276e2e25dec4af8376f7aac1503a76"
  end
  
  depends_on macos: :catalina
  
  app "Iron.app"
  
  uninstall quit: "com.srware.iron"
  
  zap trash: [
    "~/Library/Application Support/com.srware.iron",
    "~/Library/Caches/com.srware.iron",
    "~/Library/Preferences/com.srware.iron.plist",
    "~/Library/Saved Application State/com.srware.iron.savedState",
  ]
  
  caveats do
    <<~EOS
      SRWare Iron is a privacy-focused browser that removes tracking features
      found in standard Chromium browsers.
      
      Note: This cask automatically detects your CPU architecture (ARM/Intel)
      and installs the appropriate version.
    EOS
  end
end
