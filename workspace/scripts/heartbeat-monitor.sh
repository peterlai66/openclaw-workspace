#!/bin/bash
# Heartbeat System Monitor - 簡化版用於HEARTBEAT檢查

echo "🖥️ 系統資源檢查 [$(date '+%H:%M')]"

# 獲取基本系統資訊
UPTIME=$(uptime -p 2>/dev/null || echo "未知")
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //' | tr -d ',')

# 記憶體使用
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

# 磁碟使用
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

# 檢查閾值並設置狀態
STATUS="✅"
NOTES=""

# CPU檢查 (簡單檢查)
LOAD_1=$(echo $LOAD | awk '{print $1}')
CPU_CORES=$(nproc 2>/dev/null || echo 4)
if (( $(echo "$LOAD_1 > $CPU_CORES" | bc -l 2>/dev/null || echo "0") )); then
    STATUS="⚠️"
    NOTES="${NOTES}CPU負載偏高 "
fi

# 記憶體檢查
if [ $MEM_PERCENT -gt 80 ]; then
    STATUS="🚨"
    NOTES="${NOTES}記憶體使用${MEM_PERCENT}% "
elif [ $MEM_PERCENT -gt 60 ]; then
    STATUS="⚠️"
    NOTES="${NOTES}記憶體使用${MEM_PERCENT}% "
fi

# 磁碟檢查
if [ $DISK_PERCENT -gt 80 ]; then
    STATUS="🚨"
    NOTES="${NOTES}磁碟使用${DISK_PERCENT}% "
elif [ $DISK_PERCENT -gt 60 ]; then
    STATUS="⚠️"
    NOTES="${NOTES}磁碟使用${DISK_PERCENT}% "
fi

# 輸出結果
echo "${STATUS} 系統狀態: ${STATUS#* }"
echo "📊 資源使用: CPU ${LOAD_1}, 記憶體 ${MEM_PERCENT}%, 磁碟 ${DISK_PERCENT}%"
echo "🔄 運行時間: ${UPTIME#up }"

if [ -n "$NOTES" ]; then
    echo "⚠️ 注意事項: $NOTES"
fi

echo ""