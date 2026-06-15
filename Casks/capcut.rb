cask "capcut" do
  version "5.9.0,2172"
  sha256 "5faae8a48b7ecd03f5f198c2f55ac3548fa4a025f275f827c1d3cacdbcd4e0f9"

  url "https://lf16-capcut.faceulv.com/obj/capcutpc-packages-sg/packages/CapCut_#{version.csv.first.tr(".", "_")}_#{version.csv.second}_capcutpc_0_creatortool.dmg",
      verified: "lf16-capcut.faceulv.com/"

  name "CapCut"
  desc "Video editing and image design platform"
  homepage "https://www.capcut.com/"

  conflicts_with cask: "capcut"

  livecheck do
    skip "No reliable public version source for the current direct package URL"
  end

  app "CapCut.app"

  zap trash: [
    "~/Library/Application Scripts/com.lemon.lvoverseas",
    "~/Library/Containers/com.lemon.lvoverseas",
    "~/Library/Group Containers/22MMUN2RN5.lv",
    "~/Library/Group Containers/22MMUN2RN5.ve",
  ]
end
