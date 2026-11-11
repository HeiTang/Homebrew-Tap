<div align="center">
  <h1>HeiTang Homebrew Tap</h1>
  <p>透過 Homebrew 安裝 HeiTang 的 macOS 工具。</p>
  <p><a href="https://github.com/HeiTang/Toki">Toki 專案與使用說明</a></p>
</div>

## 安裝 Toki

需要已安裝 Homebrew，使用 Apple Silicon（M1 或更新）與 macOS 13 以上。

```sh
brew install --cask heitang/tap/toki
```

安裝完成後，從「應用程式」開啟 Toki。App 已內附 ExifTool，無須額外安裝。

Toki 目前尚未完成 Apple 公證。若首次開啟被 macOS 阻擋，請依照
[Toki 安裝說明](https://github.com/HeiTang/Toki#下載與安裝)，到「系統設定 → 隱私權與安全性」允許開啟。

## 更新與移除

Toki 可從 App 選單「Toki → 檢查更新」更新。
若要透過 Homebrew 更新，因 Cask 已標記 App 可自行更新，請加上 `--greedy`：

```sh
brew update
brew upgrade --cask --greedy heitang/tap/toki
```

移除 App：

```sh
brew uninstall --cask heitang/tap/toki
```

## 維護 Cask

下載來源固定使用 [Toki GitHub Releases](https://github.com/HeiTang/Toki/releases)，不重新建置或另存安裝檔。

Toki 發布新版本後，在本 Tap 根目錄執行：

```sh
gh api repos/HeiTang/Toki/releases/latest \
  --jq '{tag: .tag_name, dmg: [.assets[] | select(.name == "Toki-macos-arm64.dmg") | {url: .browser_download_url, digest}]}'
```

將 `Casks/toki.rb` 的 `version` 改為不含 `v` 的版本號，`sha256` 改為 DMG 的 digest（去除 `sha256:` 前綴）。
`livecheck` 只負責偵測新版，不會自動修改或推送 Cask。

提交前檢查：

```sh
brew style Casks/toki.rb
```

完成 Apple 公證後，再移除 Cask 的公證提示，並同步更新本文件。
