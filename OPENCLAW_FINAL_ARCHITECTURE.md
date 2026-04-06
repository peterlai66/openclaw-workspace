# OpenClaw Final Architecture
Version: v1.0
Date: 2026-04-06

---

## 1. 專案目標與核心原則

### 目標
建立一個「可控、可維護、可演進」的 AI 任務調度系統，而不是單一聊天工具。

### 核心定位
- 任務調度系統（Orchestrator）
- 多模型 routing 控制器
- 多 agent 分工系統
- 成本與風險可控的 AI runtime

### 核心原則
- 說完成 = 真的可重現
- 不依賴 runtime 狀態作為設計依據
- routing 決策必須可解釋
- 不讓 fallback 變成隨機亂跳
- 不使用未驗證 provider

---

## 2. Git / Source 與 Runtime 分離原則

### Source（Git Repo）
位置：
~/openclaw-pclaw

用途：
- 唯一設計真相來源（source of truth）
- 可版本控管
- 可重建整個系統

內容：
- 架構文件（docs）
- routing 設計
- agent 分工
- config template
- scripts（同步 / 驗證）

禁止：
- session
- auth
- logs
- cache
- runtime state

---

### Runtime（執行環境）
位置：
~/.openclaw

用途：
- OpenClaw 真正執行資料
- gateway 使用
- agent runtime state

內容：
- openclaw.json（實際使用版）
- auth-profiles.json
- sessions
- logs
- plugins
- local cache

原則：
- 不當作設計來源
- 可被重建
- 可被覆蓋

---

### Sync Layer（橋接層）

用途：
- repo → runtime 同步
- runtime → 安全備份
- 防止 config 漂移

未來腳本：
- scripts/apply-runtime.sh
- scripts/backup-runtime.sh
- scripts/diff-runtime.sh

---

## 3. 最終 Routing 設計

### 設計目標
- 穩定優先於多樣
- routing 必須 deterministic（可預期）
- fallback 必須安全且可控

---

### 四層 Routing

#### 1. FAST ROUTE
用途：
- intent classification
- 短問答
- 輕量任務

特性：
- 快
- 低成本
- 可容錯

---

#### 2. WORK ROUTE（主路徑）
用途：
- 一般任務
- 文件整理
- 技術分析
- 結構輸出

特性：
- 主力模型
- 穩定性優先

---

#### 3. DEEP ROUTE
用途：
- 系統設計
- 長推理
- 多步分析
- 高品質輸出

特性：
- 高成本
- 僅在必要時使用

---

#### 4. LOCAL ROUTE
用途：
- fallback
- 非關鍵任務
- 離線模式

特性：
- 不作為最終決策來源
- 僅作補助

---

## 4. Provider / Model 使用原則

### 原則

1. 未完成 auth 驗證的 provider：
→ 禁止進 routing

2. fallback 鏈：
→ 不可包含不穩定 provider

3. 不允許：
- 自動亂切 provider
- 無限制 fallback chain

---

### 模型角色分配（邏輯，不綁死品牌）

| Route | 角色 |
|------|------|
| FAST | 低成本快速模型 |
| WORK | 主力模型 |
| DEEP | 高推理模型 |
| LOCAL | 本機模型 |

---

## 5. Agent 分工設計

### 1. Orchestrator（主 Agent）
職責：
- 任務理解
- routing 決策
- 任務分派
- 結果整合
- 成本控制

---

### 2. Planner Agent
職責：
- 長期規劃
- 架構設計
- 任務拆解

---

### 3. Worker Agent
職責：
- 一般任務執行
- 文本處理
- 指令生成

---

### 4. Local Agent
職責：
- fallback
- 快速處理
- 非關鍵任務

---

## 6. Cron / Ingestion / Multi-Agent 擴充策略

### 原則
- 不直接寫死在 routing config
- 需模組化

---

### Cron System
- 真正 scheduler（非 heartbeat）
- 可控任務列表

---

### Data Ingestion
- API / crawler
- pipeline 分離
- 不與 agent 混寫

---

### Multi-Agent Specialization
- 每個 agent 有明確職責
- 不做萬能 agent

---

## 7. 實作 Phase 規劃

### Phase 1（現在）
- 架構定版
- routing 定版
- agent 定版

---

### Phase 2
- config 收斂
- runtime 清理
- provider 穩定化

---

### Phase 3
- sync scripts
- backup 機制
- config 驗證

---

### Phase 4
- cron system
- ingestion
- multi-agent specialization

---

## 8. 高風險錯誤（禁止再犯）

- runtime 當設計來源
- auth 決定 routing
- fallback 包含未驗證 provider
- SOUL.md 塞過多責任
- 多來源隨意修改 config

---

## 結論

OpenClaw 必須維持：

> 「設計在 repo，執行在 runtime，兩者透過 sync 控制」

否則系統最終會失控且不可維護。

## 9. 本機環境與硬體基線

### 目的
本章節作為 OpenClaw local route、模型 routing、agent specialization、runtime capacity 與後續擴充（如 cron / ingestion / local inference）的規劃依據。
所有本地模型可行性判斷，應以本章節記錄的實機環境為準，而不是憑印象或理論值估算。

---

### 主機環境（Host OS）
- Host Name: PCLAW
- OS: Microsoft Windows 10 專業教育版
- Version: 10.0.19045
- Architecture: x64-based PC
- Time Zone: UTC+08:00 台北

---

### WSL / Runtime Environment
- Runtime: WSL2
- Distro: Ubuntu 24.04.4 LTS
- Kernel: 6.6.87.2-microsoft-standard-WSL2
- Runtime role: OpenClaw / Ollama / development / local AI execution environment

---

### CPU / Memory / Storage Baseline
- CPU: Intel(R) Core(TM) i7-7700K CPU @ 4.20GHz
- Windows Physical RAM: 65,478 MB
- WSL visible memory at capture time: 31 GiB
- WSL visible swap at capture time: 8.0 GiB
- Disk seen in WSL:
  - main mounted disk approximately 1T
  - runtime root mounted under WSL environment

> 注意：WSL 可見資源不一定等於 Windows 主機總資源；OpenClaw 與本地模型規劃應優先考慮「WSL 實際可見 / 可分配資源」。

---

### GPU Baseline
- GPU: NVIDIA GeForce GTX 1080 Ti
- VRAM: 11,264 MiB
- Driver Version: 560.94
- CUDA Version: 12.6

觀察到執行當下 GPU 上已有：
- /ollama
- /Xwayland

> 這表示 GPU 資源已存在背景占用，規劃本地模型時不能把 11GB VRAM 當成完全可用淨空容量。

---

### Toolchain Baseline
- Node.js: v22.22.2
- npm: 10.9.7
- Ollama: 0.20.0
- OpenClaw runtime location: ~/.openclaw
- Git repo location: ~/openclaw-pclaw

---

### 對 OpenClaw 架構的直接影響

#### 1. Local Route 定位
此機器可支援本地模型作為：
- fallback route
- utility route
- 非關鍵摘要 / 分類 / 初步整理
- 部分本地 agent 測試用途

但不應預設作為：
- 高品質最終判斷主路由
- 長上下文高負載深度推理核心
- 多大型模型並行執行基座

---

#### 2. 本地模型規劃原則
在 GTX 1080 Ti 11GB VRAM 的條件下：
- 應優先考慮中小型、量化後可穩定執行的模型
- 本地模型以穩定與可持續運行為優先，不以理論最大模型尺寸為目標
- Local model 應以「保底可用」而非「最佳品質」角色納入 routing

---

#### 3. Routing 設計含義
因此最終 routing 必須維持：
- FAST / WORK / DEEP 以穩定雲端模型為主
- LOCAL 僅作 fallback / utility / offline assistance
- 不將本地模型視為核心決策來源
- 不把多 agent specialization 建立在高 VRAM 幻想上

---

#### 4. Runtime Capacity 管理
後續若加入：
- embedding
- rerank
- crawler
- ingestion
- cron jobs
- multi-agent parallel execution

必須評估與 Ollama / GPU 使用之間的競爭關係，避免：
- VRAM 擠爆
- swap 壓力升高
- WSL 記憶體回收導致模型不穩
- gateway latency 異常增加

---

### 規劃結論
這台機器適合：
- OpenClaw 開發
- Runtime 驗證
- 本地 fallback 模型
- 中低負載 agent 分工測試

這台機器不應被預設為：
- 重型本地推理主機
- 多大型模型穩定並行平台
- 完全取代雲端主模型的核心推理節點

## 10. 開發與實作規範

### 官方文件優先原則
後續凡涉及以下內容：
- 程式撰寫
- 設定修改
- 參數使用
- function 呼叫
- API 整合
- plugin 設定
- gateway / agent / runtime config 修改

都必須先查閱官方文件，並以官方文件為唯一實作依據。

---

### 強制規範

1. 不可自行猜測參數用途  
2. 不可自行發明 function 用法  
3. 不可自行發明官方不存在的設定欄位  
4. 不可把「看起來合理」當成可用依據  
5. 若官方文件未明示，必須標註不確定，而不是直接假設  
6. 若版本差異可能影響行為，需先核對當前版本支援狀況  
7. 任何 OpenClaw / Ollama / systemd / JSON / JSONC / JSON5 / plugin / agent config 修改，都必須先確認官方格式

---

### 實作驗證原則
所有修改完成後，至少要做以下驗證：

- 格式驗證：設定檔可被正確解析
- 啟動驗證：服務可正常啟動
- 執行驗證：routing / agent / provider 可依預期工作
- 邊界驗證：未引入未驗證 provider 或未支援欄位
- 回歸驗證：既有主流程未被破壞

---

### 禁止事項
禁止以下行為：

- 憑印象修改設定
- 用 AI 自己猜的參數直接落地
- 未查官方文件就改 function / API 行為
- 把臨時 workaround 寫成正式架構
- 把 runtime 現況誤當成官方支援能力

---

### 完成定義
本專案中，說「完成」必須同時代表：

- 依官方文件實作
- 格式正確
- 可實際啟動
- 可實際執行
- 未引入未驗證 provider / 未知參數 / 猜測用法