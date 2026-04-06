# HEARTBEAT.md
版本: v2.0 | 2026-04-05

## 目的
Heartbeat 只做狀態巡檢，不建立任務，不執行研究，不取代外部 scheduler。

---

## 每次只做以下檢查

### 1. Gateway
檢查 gateway 是否可用。

### 2. Dispatcher 狀態
讀取：
- `/home/pclaw/.openclaw/runtime/state/tasks.json`
- `/home/pclaw/.openclaw/runtime/logs/dispatcher.log`

只看：
- 今日 market 是否 done
- 今日 tech 是否 done
- 是否有 pending / failed 任務
- 是否有最近錯誤

### 3. 靜默規則
23:00 - 08:00 不主動回報，除非：
- gateway 掛掉
- 任務連續失敗
- target 未配置導致所有任務無法送出

---

## 嚴格禁止
- 不建立新任務
- 不呼叫 sub-agent
- 不做搜尋
- 不做研究
- 不補跑 dispatcher
- 不自行分析市場
- 不自行分析 AI 新聞
- 不使用 DeepSeek / OpenAI

---

## 回報格式

🫀 HEARTBEAT [時間]
✅ Gateway: 正常 / ❌ 異常
📦 Dispatcher: 正常 / ❌ 異常
📋 任務狀態: 無 / [pending|failed 列表]
📊 今日市場: 完成 / 未完成
🤖 今日AI: 完成 / 未完成
⚠️ 風險: 無 / [一句話]

若無異常且無未完成任務：
- 簡短回報即可
- 不延伸