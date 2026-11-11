cask "toki" do
  version "1.5.2"
  sha256 "6c3c24b5df72ffb179e414f2a737fb893d94a0e230c9d72e09fec4d2194186f8"

  url "https://github.com/HeiTang/Toki/releases/download/v#{version}/Toki-macos-arm64.dmg"
  name "Toki"
  desc "Batch rename photos and videos using their capture date"
  homepage "https://github.com/HeiTang/Toki"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Toki.app"

  caveats <<~EOS
    Toki is not notarized by Apple. If macOS blocks the first launch,
    follow the installation instructions at https://github.com/HeiTang/Toki#下載與安裝
  EOS
end
