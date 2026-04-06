# run command

## input
run {task}

## behavior

你是主 agent，只負責 orchestration。

當收到：

run market
→ 執行：

1. 檢查 memory 今日是否已完成
2. 若未完成：
   - 呼叫 ingestion(market)
   - 呼叫 market_agent
   - 寫入 memory
   - 發送到 Discord server
3. 若已完成：
   - 回傳已有結果（不重跑）

---

run ai
→ 同樣流程（使用 ai_agent）