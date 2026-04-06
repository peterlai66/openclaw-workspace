# 官方任務系統使用指南

## 原則：
**使用OpenClaw官方任務系統，不自己創造系統**

## 官方功能：

### 1. 任務列表和追蹤
```bash
# 列出所有任務
openclaw tasks list

# 列出運行中任務
openclaw tasks list --status running

# JSON格式輸出
openclaw tasks list --json

# 按運行時過濾
openclaw tasks list --runtime subagent
```

### 2. 任務審計和維護
```bash
# 審計任務狀態
openclaw tasks audit

# 應用維護
openclaw tasks maintenance --apply

# 取消任務
openclaw tasks cancel <task-id>
```

### 3. 創建良好標籤的任務
**使用sessions_spawn時必須**：
```bash
sessions_spawn \
  --label "清晰任務描述" \
  --task "具體任務內容" \
  --runtime subagent \
  --model ollama/qwen3.5:latest \
  --notifyPolicy done_only
```

## 我的使用承諾：

### 1. 創建任務時：
- ✅ **必須有label**：清晰描述任務目的
- ✅ **使用官方參數**：runtime, model, notifyPolicy
- ✅ **不創造ID系統**：使用官方id追蹤

### 2. 追蹤任務時：
- ✅ **使用官方命令**：`openclaw tasks list`
- ✅ **檢查狀態**：running, succeeded, failed
- ✅ **不自己創造追蹤工具**：使用官方功能

### 3. 維護任務時：
- ✅ **定期審計**：`openclaw tasks audit`
- ✅ **應用維護**：`openclaw tasks maintenance --apply`
- ✅ **清理卡住任務**：`openclaw tasks cancel`

## 立即應用：

### 檢查當前任務狀態：
```bash
# 運行中任務
openclaw tasks list --status running

# 最近完成任務
openclaw tasks list --status succeeded --json | jq '.tasks | length'
```

### 優化現有任務：
```bash
# 審計問題
openclaw tasks audit

# 應用維護建議
openclaw tasks maintenance --apply
```

## 我的改正：

**刪除自己創造的追蹤系統**：

```bash
# 刪除自創追蹤工具
rm /home/pclaw/.openclaw/workspace/scripts/delegation-tracker.sh
rm /home/pclaw/.openclaw/workspace/system/delegation-tracker.json
rm /home/pclaw/.openclaw/workspace/system/delegation-tracker.md
```

**使用官方任務系統追蹤所有工作**。