# 設定手冊

[回首頁](../README.md) · [操作手冊](usage.md) · [疑難排解](troubleshooting.md)

## 個人設定檔

| 檔案 | 載入時機與用途 |
|---|---|
| `~/.zsh_config` | 確認為互動式 Shell 後、初始化前；設定功能開關、參數與主機專屬設定 |
| `~/.zsh_aliases` | 預設函式、按鍵與提示符函式定義後；放個人 alias |
| `~/.zsh_local` | 接著載入；放個人按鍵、函式與最後覆寫 |

兩個插件在個人設定後載入，讓語法高亮能處理自訂的輸入元件。這些個人檔案不需要提交，也不會被 README 的複製步驟覆蓋。

這些檔案會執行其中的 Zsh 程式碼，請當成自己的 Shell 設定管理。初始化選項應放 `~/.zsh_config`；載入完成後才關閉開關，不會撤銷已執行的設定。

例如自行建立 `~/.zsh_config`，填入：

```zsh
PROMPT_HOST_SYMBOL="㉿"
ENABLE_AUTOSUGGESTIONS="Y"
ENABLE_SYNTAX_HIGHLIGHTING="Y"
ENABLE_SYSTEM_LOAD="N"
PATH_MAX_LENGTH=0
```

儲存後重新開啟 Zsh。可用 `zsh -n ~/.zsh_config` 先檢查語法。

沒有個人設定檔時會沿用預設值，不需要建立空檔案。

## 功能開關

使用字串 `"Y"` 開啟、`"N"` 關閉。

| 名稱 | 預設 | 用途 |
|---|---|---|
| `ENABLE_GIT_INFO` | Y | 顯示 Git 分支與狀態 |
| `ENABLE_GIT_OPERATIONS` | Y | 顯示 merge、rebase 等操作；需同時開啟 Git 資訊 |
| `ENABLE_TIMESTAMP` | Y | 顯示日期與時間 |
| `ENABLE_SYSTEM_LOAD` | Y | 負載超過門檻時顯示數值 |
| `ENABLE_VIRTUAL_ENV` | Y | 顯示 Python 環境 |
| `ENABLE_PATH_SHORTENING` | Y | 按可用寬度縮短長路徑 |
| `ENABLE_COMMAND_TIMER` | Y | 顯示達到門檻的指令耗時 |
| `ENABLE_EXIT_STATUS` | Y | 顯示非零退出碼 |
| `ENABLE_IGNORE_HOME_GIT` | N | 忽略以家目錄本身為頂層的 Git 儲存庫 |
| `ENABLE_SMART_HISTORY` | Y | 方向鍵依目前輸入前綴搜尋歷史 |
| `ENABLE_EXTENDED_GLOB` | Y | 啟用 Zsh 延伸檔名比對 |
| `ENABLE_COMMAND_CORRECTION` | N | 啟用指令拼字修正 |
| `ENABLE_ARGUMENT_CORRECTION` | N | 啟用參數拼字修正 |
| `ENABLE_PERFORMANCE_DEBUG` | N | 載入效能分析並提供 `benchmark_prompt` |
| `ENABLE_AUTOSUGGESTIONS` | Y | 檔案存在時載入自動建議插件 |
| `ENABLE_SYNTAX_HIGHLIGHTING` | Y | 檔案存在時載入語法高亮插件 |

關閉自動建議不會關閉語法高亮，反之亦然。修改插件開關後請重新開啟 Zsh；在同一個行程再次載入設定不會卸載已載入的插件。

## 設定參數

| 名稱 | 預設 | 說明 |
|---|---|---|
| `GIT_CACHE_TIMEOUT` | 3 | Git 快取保留秒數；0 表示每次重新查詢 |
| `GIT_STATUS_TIMEOUT` | 0.35 | 工作區狀態查詢逾時秒數；缺少 timeout 指令時不限制 |
| `PATH_MAX_LENGTH` | 0 | 0 為依第一行剩餘寬度調整，正整數再加長度上限 |
| `HISTORY_SIZE` | 5000 | 記憶體中的歷史數量 |
| `HISTORY_SAVE_SIZE` | 10000 | 歷史檔儲存數量 |
| `COMMAND_TIMER_THRESHOLD` | 3 | 指令耗時顯示門檻，單位為秒 |

路徑長度上限不會切斷單一目錄名稱，因此不是保證不換行的硬限制。請使用合理的數值；目前沒有完整的設定值驗證機制。

歷史紀錄預設存放在 `~/.zsh_history`，不同 Zsh 工作階段會共用歷史。以空白開頭的指令不寫入歷史。

## 提示符與 Git 符號

| 名稱 | 預設 |
|---|---|
| `PROMPT_HOST_SYMBOL` | `@` |
| `PROMPT_ROOT_SYMBOL` | `#` |
| `PROMPT_USER_SYMBOL` | `$` |
| `GIT_DIRTY_SYMBOL` | `*` |
| `GIT_STAGED_SYMBOL` | `+` |
| `GIT_UNTRACKED_SYMBOL` | `?` |
| `GIT_STASH_SYMBOL` | `$` |
| `GIT_TIMEOUT_SYMBOL` | `~` |
| `GIT_ERROR_SYMBOL` | `!` |

㉿、λ、◆ 等符號可依字型喜好調整。自訂符號會依 Zsh 提示符語法解讀；若要顯示 %，請寫成 `%%`。

## 自訂 alias 與按鍵

在 `~/.zsh_aliases` 放額外縮寫，例如：

```zsh
alias c='clear'
alias gs='git status'
```

在 `~/.zsh_local` 放按鍵覆寫，例如：

```zsh
bindkey '^R' history-incremental-search-backward
```

本專案不自動安裝套件、不自動更改登入 Shell，也不在啟動時執行升級或清理。
