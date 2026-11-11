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

每個 App 的版本、SHA-256 與下載網址集中放在自己的 `Casks/<名稱>.rb`，安裝檔沿用各 App 的 GitHub Releases。

[Update Casks](.github/workflows/update-casks.yml) 每 6 小時掃描全部 `Casks/*.rb`，也可從 Actions 手動執行。
共用的 [更新腳本](scripts/update-casks.rb) 從各 Cask 的 URL 取得 repo 與安裝檔名稱，檢查最新正式 Release，
下載並核對所有新版安裝檔的 SHA-256 後，才更新版本與雜湊。
任一 App 的 API、下載或資料驗證失敗，該次不修改任何 Cask；沒有新版也不變更。
Workflow 通過測試與 Homebrew 格式檢查後，將同次更新集中到 `feature/update-casks` 分支的一張 PR，不會自動合併。

首次啟用需到 repo 的 **Settings → Actions → General → Workflow permissions**，
勾選 **Allow GitHub Actions to create and approve pull requests**。
Workflow 使用內建 `GITHUB_TOKEN`，不需要額外 PAT；只申請內容與 PR 寫入權限，不會批准或合併 PR。
排程需 workflow 已在預設分支，執行時間可能因 GitHub 排程延遲；公開 repo 長期無活動時也可能停用排程。

新增 App 時，只需加入 Cask，不必新增專用 workflow、腳本或另一份 App 清單。
目前共用更新器支援單一 `version`／`sha256`／`url` 的 GitHub Releases Cask：
版本為 `MAJOR.MINOR.PATCH`，tag 為相同版本或加上 `v` 前綴，下載 URL 的 tag 使用 `#{version}`。
安裝檔名稱可以固定，也可包含 `#{version}`。多架構分開雜湊或其他下載來源需先擴充更新器；不支援的格式會明確報錯。

若需在本機手動更新，先確認 `gh` 已登入，再於本 Tap 根目錄執行：

```sh
ruby scripts/update-casks.rb
```

此指令會下載、驗證並修改本機 Cask，輸出更新摘要；PR 由 workflow 建立。

提交前檢查：

```sh
ruby tests/update-casks-test.rb
brew style Casks/*.rb
```

App 完成 Apple 公證後，再移除對應 Cask 的公證提示，並同步更新安裝說明。
