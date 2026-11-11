cask "toki" do
  version "1.5.3"
  sha256 "bb87f40aecaa4cb4c7d92d057e3c4fba74fd705e92b05d90f1e7e87e4f35a46f"

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
