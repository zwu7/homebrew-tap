cask "classin" do
  version "6.0.7.3395"
  sha256 "71e9af98b4cbfed113d1f05fb11cf5bf4d9149d88bdfcb496c022205e34770d3"

  url "https://download.eeo.cn/client/classin_mac_install_#{version}_arm64.dmg",
      verified: "download.eeo.cn/client/"

  name "ClassIn"
  desc "Online classroom and hybrid learning platform"
  homepage "https://www.classin.com/download/"

  depends_on arch: :arm64

  app "ClassIn.app"
end
