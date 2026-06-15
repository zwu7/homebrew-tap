# Homebrew Tap 维护经验记录：ClassIn 与 CapCut

日期：2026-06-15
仓库：`zwu7/homebrew-tap`
适用范围：以后维护自托管 Homebrew cask / formula 时复用

## 1. 总体原则

以后制作或更新 Homebrew cask / formula 时，优先使用本次成功流程：

1. 不直接相信网页按钮、`blob:` URL、跳转页或 downloader URL。
2. 先确认真实可复现下载 artifact，例如 `.dmg`、`.pkg`、`.zip`、`.tar.gz`。
3. 本地下载 artifact，计算 `sha256`。
4. 挂载或解包 artifact，确认实际安装内容。
5. 从 `Info.plist` 或二进制元数据确认真实版本号。
6. 按现有 tap 结构做最小修改。
7. 使用 `brew style` 和本地安装测试。
8. 顺手修复 Homebrew 在当前 tap 中暴露出的 DSL deprecation warning。
9. 记录版本、checksum、URL、artifact 名称、测试命令和后续更新方法。

## 2. ClassIn cask 经验

### 已确认信息

下载地址：

```bash
https://download.eeo.cn/client/classin_mac_install_6.0.7.3395_arm64.dmg
```

SHA-256：

```bash
71e9af98b4cbfed113d1f05fb11cf5bf4d9149d88bdfcb496c022205e34770d3
```

建议 cask 文件：

```text
Casks/classin.rb
```

关键写法：

```ruby
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
```

### 可复用经验

ClassIn 的 URL 比较干净，版本号直接出现在文件名中：

```text
classin_mac_install_6.0.7.3395_arm64.dmg
```

因此可以直接用：

```ruby
version "6.0.7.3395"
url "..._#{version}_arm64.dmg"
```

维护成本低，只需要更新：

1. `version`
2. `sha256`
3. 必要时确认 `app "ClassIn.app"` 是否变化

## 3. CapCut cask 经验

### 最终文件名

本 tap 中最终使用：

```text
Casks/capcut.rb
```

而不是：

```text
Casks/capcut-latest.rb
```

因此 cask token 应为：

```ruby
cask "capcut" do
```

安装时为了避免和 Homebrew 官方 cask 混淆，优先使用 fully-qualified token：

```bash
brew install --cask zwu7/tap/capcut
```

### 关键发现

CapCut 官方页面：

```bash
https://www.capcut.com/download-guidance
```

会触发浏览器下载，但页面拿到的链接可能是：

```text
blob:https://www.capcut.com/...
```

这个不能用于 Homebrew cask。

原因：`blob:` URL 是浏览器运行时生成的本地对象 URL，不是可被 Homebrew、`curl` 或其他机器复现的真实 HTTP 下载地址。

### 第一阶段下载器

Firefox Network 中抓到的真实 HTTP 下载链接是：

```bash
https://sf16-web-tos-buz.capcutcdn-us.com/obj/capcut-web-buz-tx/installer/capcut_capcutpc_0_1.2.67_installer.dmg
```

本地验证：

```bash
curl -fL --retry 3 -o /tmp/capcut.dmg "$url"
file /tmp/capcut.dmg
ls -lh /tmp/capcut.dmg
shasum -a 256 /tmp/capcut.dmg
```

结果显示该文件只有约 3.5MB，且挂载后是：

```text
/Volumes/CapCut Downloader/CapCut-Downloader.app
```

因此它只是 downloader / installer，不是最终应该写进 cask 的主程序包。

### 重要排错经验：DMG 挂载点带空格

一开始使用：

```bash
hdiutil attach -nobrowse -readonly /tmp/capcut.dmg | awk '/\/Volumes\// {print $3; exit}'
```

会把：

```text
/Volumes/CapCut Downloader
```

截断成：

```text
/Volumes/CapCut
```

导致：

```text
find: /Volumes/CapCut: No such file or directory
```

以后优先使用固定 mountpoint：

```bash
rm -rf /tmp/capcut_mount
mkdir -p /tmp/capcut_mount

hdiutil attach -nobrowse -readonly -mountpoint /tmp/capcut_mount /tmp/capcut.dmg
```

如果 DMG 已经挂载，则用：

```bash
hdiutil info | grep -A20 -B5 -i capcut
```

确认真实挂载点。

### 从 downloader 中挖出真实大包 URL

挂载 downloader 后检查 URL：

```bash
INSTALLER_APP="$(find "/Volumes/CapCut Downloader" -maxdepth 4 -name "*.app" -print -quit)"

find "$INSTALLER_APP/Contents" -maxdepth 6 -type f -print0 \
  | xargs -0 strings -a 2>/dev/null \
  | grep -Eo 'https?://[^"'\'' <>)\\]+' \
  | sort -u
```

成功找到真实大包：

```bash
https://lf16-capcut.faceulv.com/obj/capcutpc-packages-sg/packages/CapCut_5_9_0_2172_capcutpc_0_creatortool.dmg
```

### 真实大包验证结果

下载：

```bash
url='https://lf16-capcut.faceulv.com/obj/capcutpc-packages-sg/packages/CapCut_5_9_0_2172_capcutpc_0_creatortool.dmg'

curl -fL --retry 3 -o /tmp/capcut-real.dmg "$url"

file /tmp/capcut-real.dmg
ls -lh /tmp/capcut-real.dmg
shasum -a 256 /tmp/capcut-real.dmg
```

确认信息：

```text
文件大小：约 979M
sha256：5faae8a48b7ecd03f5f198c2f55ac3548fa4a025f275f827c1d3cacdbcd4e0f9
```

挂载检查：

```bash
rm -rf /tmp/capcut_real_mount
mkdir -p /tmp/capcut_real_mount

hdiutil attach -nobrowse -readonly -mountpoint /tmp/capcut_real_mount /tmp/capcut-real.dmg

find /tmp/capcut_real_mount -maxdepth 4 \( -name "*.app" -o -name "*.pkg" \) -print

APP="$(find /tmp/capcut_real_mount -maxdepth 4 -name "CapCut.app" -print -quit)"

echo "App path: $APP"

/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"

hdiutil detach /tmp/capcut_real_mount
```

确认结果：

```text
/tmp/capcut_real_mount/CapCut.app
CFBundleShortVersionString: 5.9.0
CFBundleVersion: 5.9.0
```

URL 文件名中有 `2172`，但 bundle version 是 `5.9.0`。为了保持 URL 模板化，cask 中使用：

```ruby
version "5.9.0,2172"
```

其中：

```ruby
version.csv.first  # 5.9.0
version.csv.second # 2172
```

### CapCut cask 最终模板

文件：

```text
Casks/capcut.rb
```

内容：

```ruby
cask "capcut" do
  version "5.9.0,2172"
  sha256 "5faae8a48b7ecd03f5f198c2f55ac3548fa4a025f275f827c1d3cacdbcd4e0f9"

  url "https://lf16-capcut.faceulv.com/obj/capcutpc-packages-sg/packages/CapCut_#{version.csv.first.tr(".", "_")}_#{version.csv.second}_capcutpc_0_creatortool.dmg",
      verified: "lf16-capcut.faceulv.com/"

  name "CapCut"
  desc "Video editing and image design platform"
  homepage "https://www.capcut.com/"

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
```

如果本地也安装了 Homebrew 官方 `capcut`，建议安装时明确指定 tap：

```bash
brew install --cask zwu7/tap/capcut
```

## 4. Homebrew DSL 维护经验

运行：

```bash
brew update -f && brew outdated -g
```

时发现 tap 中旧 cask 有 deprecation warning：

```text
Warning: Calling string comparison format for `depends_on macos:` is deprecated!
/opt/homebrew/Library/Taps/zwu7/homebrew-tap/Casks/buzz-captions.rb:21
```

旧写法可能是：

```ruby
depends_on macos: ">= :catalina"
```

应改为：

```ruby
depends_on macos: :catalina
```

以后遇到 Homebrew 输出 “Please report this issue to the zwu7/homebrew-tap tap” 时，优先检查自己 tap 中的 cask DSL，而不是 Homebrew 官方仓库。

## 5. 标准操作流程

### 5.1 下载真实 artifact

```bash
url='REAL_DOWNLOAD_URL'

curl -fL --retry 3 -o /tmp/package.dmg "$url"

file /tmp/package.dmg
ls -lh /tmp/package.dmg
shasum -a 256 /tmp/package.dmg
```

### 5.2 挂载 DMG

```bash
rm -rf /tmp/package_mount
mkdir -p /tmp/package_mount

hdiutil attach -nobrowse -readonly -mountpoint /tmp/package_mount /tmp/package.dmg

find /tmp/package_mount -maxdepth 4 \( -name "*.app" -o -name "*.pkg" \) -print
```

### 5.3 检查 app 版本

```bash
APP="$(find /tmp/package_mount -maxdepth 4 -name "*.app" -print -quit)"

echo "App path: $APP"

/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" 2>/dev/null || true
```

### 5.4 卸载 DMG

```bash
hdiutil detach /tmp/package_mount
```

如果 busy：

```bash
lsof +D /tmp/package_mount
hdiutil detach -force /tmp/package_mount
```

### 5.5 写 cask

基础模板：

```ruby
cask "TOKEN" do
  version "VERSION"
  sha256 "SHA256"

  url "REAL_DOWNLOAD_URL",
      verified: "DOWNLOAD_HOST/"

  name "APP_NAME"
  desc "SHORT_DESCRIPTION"
  homepage "HOMEPAGE_URL"

  app "APP_NAME.app"
end
```

如果 URL 中需要 build number：

```ruby
version "5.9.0,2172"

url "https://example.com/App_#{version.csv.first.tr(".", "_")}_#{version.csv.second}.dmg",
    verified: "example.com/"
```

如果没有可靠 livecheck：

```ruby
livecheck do
  skip "No reliable public version source for the current direct package URL"
end
```

### 5.6 本地测试

```bash
brew style --cask Casks/TOKEN.rb
brew install --cask ./Casks/TOKEN.rb
```

如果和官方 cask 同名：

```bash
brew install --cask zwu7/tap/TOKEN
```

### 5.7 提交

```bash
git add Casks/TOKEN.rb
git commit -m "Add TOKEN cask"
git push
```

## 6. 判断 URL 是否适合写进 cask

### 可以写入 cask 的 URL

适合：

```text
https://.../Something_1_2_3.dmg
https://.../Something_1.2.3.pkg
https://.../Something-1.2.3.zip
```

要求：

1. `curl -fL` 可以直接下载。
2. 文件大小合理。
3. `shasum -a 256` 可复现。
4. artifact 中有明确 `.app` 或 `.pkg`。
5. app 版本可从 `Info.plist` 读取。

### 不适合写入 cask 的 URL

不适合：

```text
blob:https://...
https://example.com/download
https://example.com/download-guidance
https://.../installer.dmg
```

原因：

1. `blob:` 是浏览器临时对象 URL。
2. HTML 引导页不是 artifact。
3. 小型 installer/downloader 不等于正式 app。
4. downloader 可能二次联网，Homebrew 无法稳定复现安装。
5. 未来 checksum 和行为不可控。

## 7. CapCut 后续更新流程

以后更新 CapCut 时：

1. 打开 `https://www.capcut.com/download-guidance`。
2. 用 Firefox Network 抓真实 downloader DMG。
3. 下载 downloader。
4. 挂载 downloader。
5. 对 downloader app 运行 `strings`，找真实大包 URL。
6. 下载真实大包。
7. 计算 SHA-256。
8. 挂载真实大包，确认 `CapCut.app` 和 `Info.plist` 版本。
9. 更新 `Casks/capcut.rb` 中的：

   * `version`
   * `sha256`
   * `url`
   * 必要时 `verified`
10. 运行：

* `brew style --cask Casks/capcut.rb`
* `brew install --cask ./Casks/capcut.rb`

11. 提交并 push。

## 8. 当前已确认的 CapCut 信息

```text
cask 文件：Casks/capcut.rb
cask token：capcut
版本：5.9.0,2172
App bundle：CapCut.app
真实大包 URL：https://lf16-capcut.faceulv.com/obj/capcutpc-packages-sg/packages/CapCut_5_9_0_2172_capcutpc_0_creatortool.dmg
SHA-256：5faae8a48b7ecd03f5f198c2f55ac3548fa4a025f275f827c1d3cacdbcd4e0f9
Downloader URL：https://sf16-web-tos-buz.capcutcdn-us.com/obj/capcut-web-buz-tx/installer/capcut_capcutpc_0_1.2.67_installer.dmg
Downloader app：CapCut-Downloader.app
Downloader version：1.0 / 1
```

## 9. 下次复用提醒

下次制作 Homebrew cask 或 formula 时，不要先写模板；先验证真实 artifact。

优先顺序：

1. 官方或页面实际下载的真实文件。
2. 可复现的 URL。
3. 本地 checksum。
4. 解包后的真实 app/pkg。
5. 版本元数据。
6. 最小 cask/formula 修改。
7. `brew style`。
8. 本地安装测试。
9. 再提交。
