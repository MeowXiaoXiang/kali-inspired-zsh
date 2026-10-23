# 操作手冊

[回首頁](../README.md) · [設定手冊](configuration.md) · [疑難排解](troubleshooting.md)

以下指令與按鍵適用於已載入本設定的互動式 Zsh；一般腳本不會自動取得這些函式與 alias。

## 提示符資訊

第一行依序顯示使用者與主機、Python 環境（若有）、路徑、Git、時間、耗時、負載及失敗退出碼。第二行留給輸入指令；一般使用者預設顯示 `$`，root 顯示 `#`。

- 耗時達到 `COMMAND_TIMER_THRESHOLD`（預設 3 秒）才出現。
- 指令成功時不顯示退出碼；失敗時顯示如 `exit:1`。
- 負載超過處理器核心數 × 0.7 時顯示如 `load:4.2`。這是系統負載，不是 CPU 使用百分比。
- Python 提示依序檢查 venv、Conda（不顯示 `base`）、Pipenv。

### Git 符號

| 符號 | 意義 |
|---|---|
| `*` | 工作區有變更 |
| `+` | 暫存區有變更 |
| `?` | 有未追蹤檔案 |
| `$` | 有 stash |
| `↑1`／`↓1` | 相對追蹤分支超前／落後 1 個 commit，以本機已知資訊為準 |
| `~` | 工作區狀態查詢逾時，狀態未知 |
| `!` | 工作區狀態查詢失敗，狀態未知 |
| `[MERGE]` 等 | 正在進行 merge、rebase、cherry-pick、revert 或 bisect |

Git 結果預設快取 3 秒。工作區修改可能稍後才顯示；切換目錄、分支或 HEAD 會讓快取失效。只有工作區狀態查詢受逾時限制，其他 Git 查詢不在此限制內。裸儲存庫不顯示一般工作區資訊。

### 長路徑

依第一行其餘資訊占用的空間，省略中間層級，例如 `~/projects/…/services/payment`。這只改變顯示，不會改變目前目錄。

不切斷單一目錄名稱；終端機太窄或目錄名稱太長時，畫面仍可能自然換行。

## 常用指令

| 指令 | 實際行為 |
|---|---|
| `ll` | `ls -alF`，詳細列出含隱藏檔案的內容 |
| `la` | `ls -A`，列出隱藏檔案但不含 `.`、`..` |
| `l` | `ls -CF`，以欄位排列並標示類型 |
| `..`／`...` | `cd ..`／`cd ../..` |
| `mkcd DIRECTORY` | 建立並進入一個目錄，名稱可包含空白 |
| `extract ARCHIVE` | 解壓一個檔案到目前目錄 |
| `pkgup` | 更新套件資訊並升級 |
| `pkgclean` | 移除不再需要的相依套件，再清除已下載的套件快取 |
| `aptup` | 舊名稱，呼叫 `pkgup`；依系統選擇 APT／DNF |

`ls`、`grep` 保留 `--color=auto`。額外縮寫請放 `~/.zsh_aliases`。

```zsh
mkcd "projects/my project"
ll
```

## 按鍵

| 按鍵 | 行為 |
|---|---|
| Ctrl+R | 原生互動式反向歷史搜尋 |
| ↑／↓ | 預設依目前輸入的前綴搜尋歷史；可關閉智慧歷史開關 |
| Tab | 補全指令、路徑與參數 |
| → | 使用自動建議插件時，在游標位於行尾接受建議 |
| Ctrl+U | 刪除游標前的目前行內容 |
| Ctrl+←／Ctrl+→ | 依單字移動，須終端機送出對應按鍵序列 |
| Delete | 刪除游標位置的字元 |
| 空白鍵 | 展開可用的歷史替換後插入空白 |

預設使用 Emacs 按鍵配置；個人按鍵可在 `~/.zsh_local` 覆寫。設定會忽略以空白開頭的歷史紀錄，也會減少重複紀錄。

## 解壓縮

```zsh
extract "$HOME/Downloads/archive.zip"
```

支援 .tar、.tar.gz／.tgz、.tar.bz2／.tbz2、.tar.xz、.zip、.gz、.bz2、.xz。一次接受一個檔案，從目前目錄開始解壓；檔名可含空白或以 `-` 開頭。

| 格式 | 同名檔案處理 |
|---|---|
| tar 系列 | 不覆寫；發生衝突時回傳失敗，但其他檔案可能已解壓 |
| zip | 跳過同名檔案；略過檔案不一定代表指令失敗 |
| gz／bz2／xz 單檔 | 保留原壓縮檔，沿用工具原生的拒絕覆寫行為 |

缺少工具時會提示套件名稱及 APT／DNF 安裝指令，不會自動安裝。`extract` 不提供回滾或隔離環境；請先檢查不受信任的壓縮檔內容，並在適合的目錄操作。

## 套件升級與清理

依發行版與可用指令選擇 APT 或 DNF，只有手動呼叫時才會執行。

| 指令 | APT | DNF |
|---|---|---|
| `pkgup` | `sudo apt update` 成功後執行 `sudo apt upgrade` | `sudo dnf upgrade --refresh` |
| `pkgclean` | `sudo apt autoremove` 成功後執行 `sudo apt clean` | `sudo dnf autoremove` 成功後執行 `sudo dnf clean packages` |

這兩個指令不接受額外參數，也不加上自動確認的 `-y`。移除相依套件前，請確認套件管理器列出的變更；清除快取通常不會再詢問。前一步失敗就停止，不進行發行版升級。

`pkgup` 只更新系統套件，不會更新本專案設定或這裡手動安裝的插件。

## 更新設定

在專案目錄確認沒有需要保留的本地修改後，取得更新：

```sh
git pull --ff-only
```

再依 [README 的安裝步驟](../README.md#4-檢查備份並套用)檢查、備份並重新複製 `.zshrc`，然後重新開啟 Zsh。只更新專案目錄，不會自動更新家目錄裡的設定檔；三個個人設定檔也不需要一起複製。

需要更新插件時，確認對應目錄沒有本地修改，再分別執行：

```sh
git -C ~/.zsh/plugins/zsh-autosuggestions pull --ff-only
git -C ~/.zsh/plugins/zsh-syntax-highlighting pull --ff-only
```

沒有安裝某個插件就略過該行。若 Git 回報衝突或無法快轉，先檢查自己的修改，不要用強制覆蓋處理。
