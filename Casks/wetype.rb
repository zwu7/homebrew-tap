cask "wetype" do
  version "1.1.1,335"
  sha256 "8fb4868c7f9576da1ac0d1de2e07e8dddd2e373cd8f4f6bf3cede3d40f19464a"

  url "https://wetype.wxqcloud.qq.com/app/mac/#{version.csv.first}/WeTypeInstaller_#{version.csv.first}_#{version.csv.second}.zip"
  name "WeType"
  name "微信输入法"
  desc "Text input app from the WeChat team for Chinese users"
  homepage "https://z.weixin.qq.com/"

  livecheck do
    skip "Pinned to the last non-AI release after cross-device sync was introduced"
  end

  auto_updates true
  depends_on macos: :catalina

  installer manual: "WeTypeInstaller_#{version.csv.first}_#{version.csv.second}.app"

  uninstall delete: "/Library/Input Methods/WeType.app"

  zap trash: [
    "~/Library/Application Support/WeType",
    "~/Library/Caches/com.tencent.inputmethod.wetype",
    "~/Library/Caches/WeType",
    "~/Library/HTTPStorages/com.tencent.inputmethod.wetype",
    "~/Library/Preferences/com.tencent.inputmethod.wetype.plist",
  ]
end
