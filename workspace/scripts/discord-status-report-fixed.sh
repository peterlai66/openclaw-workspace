#!/bin/bash

# Discord系統狀態自動報告腳本（修正版）
# 用於在HEARTBEAT檢查時自動發送狀態報告到Discord

set -e

# 輔助函數：獲取今日重要事件
get_today_events() {
    TODAY=$(date "+%Y-%m-%d")
    EVENTS=""
    
    # 檢查是否有新技能安裝
    if [ -f ~/.openclaw/workspace/memory/$TODAY.md ]; then
        if grep -q "技能安裝" ~/.openclaw/workspace/memory/$TODAY.md; then
            EVENTS="$EVENTS• 🎯 新技能安裝完成\n"
        fi
        if grep -q "系統恢復" ~/.openclaw/workspace/memory/$TODAY.md; then
            EVENTS="$EVENTS• 🔄 系統恢復正常\n"
        fi
        if grep -q "任務完成" ~/.openclaw/workspace/memory/$TODAY.md; then
            EVENTS="$EVENTS• ✅ 重要任務完成\n"
        fi
    fi
    
    if [ -z "$EVENTS" ]; then
        echo "• 📝 無特別重要事件"
    else
        echo -e "$EVENTS"
    fi
}

# 輔助函數：獲取警告事項
get_warnings() {
    WARNINGS=""
    
    # 檢查CPU負載
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    CPU_CORES=$(nproc)
    if (( $(echo "$CPU_LOAD > $CPU_CORES" | bc -l) )); then
        WARNINGS="$WARNINGS• ⚠️ CPU負載偏高 ($CPU_LOAD > $CPU_CORES核心)\n"
    fi
    
    # 檢查記憶體使用
    MEM_PERCENT=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$MEM_PERCENT > 80" | bc -l) )); then
        WARNINGS="$WARNINGS• ⚠️ 記憶體使用超過80%\n"
    fi
    
    # 檢查磁碟使用
    DISK_PERCENT=$(df /home/pclaw | tail -1 | awk '{print $5}' | tr -d '%')
    if [ "$DISK_PERCENT" -gt 80 ]; then
        WARNINGS="$WARNINGS• ⚠️ 磁碟使用超過80%\n"
    fi
    
    if [ -z "$WARNINGS" ]; then
        echo "• ✅ 無異常警告"
    else
        echo -e "$WARNINGS"
    fi
}

# 設定變數
CHANNEL_ID="1488038362815266836"
TIMESTAMP=$(date "+%H:%M")
UPTIME=$(uptime -p | sed 's/up //')
SYSTEM_MONITOR_OUTPUT=$(bash ~/.openclaw/workspace/scripts/heartbeat-monitor.sh 2>/dev/null || echo "系統監控暫時不可用")

# 檢查Gateway服務狀態
GATEWAY_STATUS=$(systemctl --user is-active openclaw-gateway 2>/dev/null || echo "unknown")
if [ "$GATEWAY_STATUS" = "active" ]; then
    GATEWAY_UPTIME=$(systemctl --user status openclaw-gateway | grep "Active:" | awk '{print $6" "$7" "$8" "$9" "$10}')
    GATEWAY_STATUS_EMOJI="✅"
else
    GATEWAY_STATUS_EMOJI="❌"
    GATEWAY_UPTIME="服務停止"
fi

# 檢查Ollama服務
OLLAMA_PID=$(ps aux | grep "ollama serve" | grep -v grep | awk '{print $2}' | head -1)
if [ -n "$OLLAMA_PID" ]; then
    OLLAMA_STATUS="✅ 運行中 (PID: $OLLAMA_PID)"
else
    OLLAMA_STATUS="❌ 未運行"
fi

# 檢查模型數量
MODEL_COUNT=$(ollama list 2>/dev/null | wc -l || echo "0")
MODEL_COUNT=$((MODEL_COUNT - 1))  # 減去標題行

# 獲取今日事件和警告
TODAY_EVENTS=$(get_today_events)
WARNINGS=$(get_warnings)

# 生成報告訊息
REPORT_MESSAGE="## 🖥️ **系統狀態自動報告** ($TIMESTAMP)

### 📊 **系統資源**
$SYSTEM_MONITOR_OUTPUT

### 🔧 **服務狀態**
- **OpenClaw Gateway**: $GATEWAY_STATUS_EMOJI $GATEWAY_UPTIME
- **Ollama服務**: $OLLAMA_STATUS
- **本地模型**: $MODEL_COUNT 個可用

### 📈 **今日重要事件**
$TODAY_EVENTS

### ⚠️ **注意事項**
$WARNINGS

---

*此報告由PClaw AI自動生成，每小時更新一次*"

# 發送到Discord
echo "$REPORT_MESSAGE" | head -c 2000 | openclaw message send --channel discord --target "$CHANNEL_ID" --message - 2>/dev/null || echo "Discord發送失敗，請檢查配置"

# 記錄到日誌
echo "[$(date)] Discord狀態報告已發送" >> ~/.openclaw/workspace/logs/discord-status.log