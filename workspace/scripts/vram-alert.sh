#!/bin/bash

# VRAM使用警報腳本
# 監控GPU VRAM使用情況，超過閾值時發出警報

set -e

ALERT_THRESHOLD=80  # VRAM使用率超過80%時警報
LOG_FILE="$HOME/.openclaw/workspace/logs/vram-alert.log"
mkdir -p "$(dirname "$LOG_FILE")"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 檢查nvidia-smi是否可用
if ! command -v nvidia-smi &> /dev/null; then
    echo "[$TIMESTAMP] INFO: nvidia-smi not available, skipping VRAM monitoring" >> "$LOG_FILE"
    echo "⚠️  nvidia-smi不可用，跳過VRAM監控"
    exit 0
fi

# 獲取VRAM使用情況
VRAM_USAGE=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
VRAM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)

if [ -z "$VRAM_USAGE" ] || [ -z "$VRAM_TOTAL" ]; then
    echo "[$TIMESTAMP] ERROR: Failed to get VRAM usage" >> "$LOG_FILE"
    echo "❌ 無法獲取VRAM使用情況"
    exit 1
fi

# 計算使用百分比
VRAM_PERCENT=$((VRAM_USAGE * 100 / VRAM_TOTAL))

# 獲取GPU型號和溫度
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 | sed 's/ /_/g')
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | head -1)

# 獲取正在使用GPU的進程
GPU_PROCESSES=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | head -5)

# 記錄監控數據
echo "[$TIMESTAMP] VRAM_MONITOR: gpu=$GPU_NAME, vram_used=${VRAM_USAGE}MB, vram_total=${VRAM_TOTAL}MB, vram_percent=${VRAM_PERCENT}%, temp=${GPU_TEMP}°C" >> "$LOG_FILE"

if [ -n "$GPU_PROCESSES" ]; then
    echo "[$TIMESTAMP] GPU_PROCESSES: $GPU_PROCESSES" >> "$LOG_FILE"
fi

# 檢查是否需要警報
if [ "$VRAM_PERCENT" -gt "$ALERT_THRESHOLD" ]; then
    ALERT_MESSAGE="🚨 VRAM警報: 使用率 ${VRAM_PERCENT}% > ${ALERT_THRESHOLD}%"
    echo "[$TIMESTAMP] ALERT: $ALERT_MESSAGE" >> "$LOG_FILE"
    
    # 輸出警報信息
    echo "========================================="
    echo "🚨 **VRAM使用警報** 🚨"
    echo "========================================="
    echo "🕐 時間: $TIMESTAMP"
    echo "🖥️ GPU: $GPU_NAME"
    echo "🌡️ 溫度: ${GPU_TEMP}°C"
    echo "💾 VRAM使用: ${VRAM_USAGE}MB / ${VRAM_TOTAL}MB"
    echo "📊 使用率: ${VRAM_PERCENT}% (閾值: ${ALERT_THRESHOLD}%)"
    echo ""
    
    if [ -n "$GPU_PROCESSES" ]; then
        echo "🔍 **正在使用GPU的進程**:"
        echo "$GPU_PROCESSES" | while IFS= read -r line; do
            echo "   $line"
        done
    fi
    
    echo ""
    echo "💡 **建議行動**:"
    echo "1. 檢查是否有異常進程佔用VRAM"
    echo "2. 考慮停止未使用的模型"
    echo "3. 優化模型加載策略"
    echo "4. 監控系統資源使用情況"
    echo "========================================="
    
    # 這裡可以添加發送Discord/Telegram警報的邏輯
    # 例如: openclaw message send --channel discord --to "channel:XXX" --message "$ALERT_MESSAGE"
    
else
    # 正常狀態輸出
    echo "✅ VRAM監控 [$TIMESTAMP]"
    echo "🖥️ GPU: $GPU_NAME"
    echo "🌡️ 溫度: ${GPU_TEMP}°C"
    echo "💾 VRAM使用: ${VRAM_USAGE}MB / ${VRAM_TOTAL}MB"
    echo "📊 使用率: ${VRAM_PERCENT}% (安全範圍)"
    
    if [ -n "$GPU_PROCESSES" ]; then
        echo "🔍 使用GPU的進程:"
        echo "$GPU_PROCESSES" | while IFS= read -r line; do
            echo "   $line"
        done
    fi
fi

# 檢查GPU溫度是否過高
if [ "$GPU_TEMP" -gt 85 ]; then
    echo "[$TIMESTAMP] WARNING: GPU temperature ${GPU_TEMP}°C > 85°C" >> "$LOG_FILE"
    echo "⚠️  GPU溫度警告: ${GPU_TEMP}°C (建議檢查散熱)"
fi