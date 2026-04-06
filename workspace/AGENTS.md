# 🦞 AGENT SYSTEM (FINAL)

## MAIN AGENT（唯一 orchestrator）

負責：
- 任務判斷
- 任務去重
- 呼叫 sub-agent
- routing

禁止：
- 不做資料抓取
- 不做研究
- 不做長分析

---

## SCHEDULER（非 AI）

負責：
- cron 任務觸發
- 不使用模型

---

## INGESTION（非 AI）

負責：
- 抓 API / crawler
- 寫入 /data/*
- 不做分析

---

## MARKET_AGENT（財經）

輸入：
- /data/market/YYYY-MM-DD.json

負責：
- 整理
- 分析
- 輸出觀點

模型：
- google/gemini-2.0-flash
- fallback: local

---

## AI_AGENT（科技）

輸入：
- /data/ai/YYYY-MM-DD.json

負責：
- 趨勢整理
- 重點提取

模型：
- google/gemini-2.0-flash

---

## 🚫 嚴格限制

- agent 不可自行 fetch
- agent 不可創新任務
- agent 不可重跑已完成任務