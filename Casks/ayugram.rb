brew tap zwu7/tap

TAP_DIR="$(brew --repository zwu7/tap)"
VERSION="7.2.9"
DMG="/tmp/AyuGram-${VERSION}.dmg"

curl -fL --retry 3 \
  "https://github.com/AyuGram/AyuGramDesktop/releases/download/v${VERSION}/AyuGram.dmg" \
  -o "$DMG"

if [[ -s "$DMG" ]]; then
  SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

  mkdir -p "$TAP_DIR/Casks"

  cat > "$TAP_DIR/Casks/ayugram.rb" <<EOF
cask "ayugram" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "https://github.com/AyuGram/AyuGramDesktop/releases/download/v#{version}/AyuGram.dmg"
  name "AyuGram"
  desc "Telegram client with ghost mode and message history"
  homepage "https://github.com/AyuGram/AyuGramDesktop"

  depends_on :macos

  app "AyuGram.app"

  zap trash: [
    "~/Library/Application Support/AyuGram Desktop",
    "~/Library/Saved Application State/one.ayugram.AyuGramDesktop.savedState",
  ]
end
EOF

  rm -f "$DMG"
  echo "Created: $TAP_DIR/Casks/ayugram.rb"
else
  echo "Download failed; no cask created."
fi
