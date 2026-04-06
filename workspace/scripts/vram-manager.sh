#!/bin/bash

# VRAM管理腳本
# 持續監控和優化VRAM使用

set -e

LOG_FILE="$HOME/.openclaw/workspace/logs/vram-manager.log"
mkdir -p "$(dirname "$LOG_FILE")"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
VRAM_THRESHOLD=80  # VRAM使用超過80%時採取行動

echo "[$TIMESTAMP] VRAM管理啟動" >> "$LOG_FILE"

# 檢查VRAM使用
check_vram_usage() {
    if ! command -v nvidia-smi &> /dev/null; then
        echo "⚠️  nvidia-smi不可用"
        return 1
    fi
    
    local vram_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    local vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    local vram_percent=$((vram_used * 100 / vram_total))
    
    echo "[$TIMESTAMP] VRAM檢查: ${vram_used}MB/${vram_total}MB (${vram_percent}%)" >> "$LOG_FILE"
    
    if [ $vram_percent -gt $VRAM_THRESHOLD ]; then
        echo "[$TIMESTAMP] VRAM警報: ${vram_percent}% > ${VRAM_THRESHOLD}%" >> "$LOG_FILE"
        return 1  # 超過閾值
    fi
    
    return 0  # 正常
}

# 清理VRAM
cleanup_vram() {
    echo "[$TIMESTAMP] 開始清理VRAM" >> "$LOG_FILE"
    
    # 1. 停止所有運行中模型
    echo "🔄 停止運行中模型..."
    local running_models=$(ollama ps 2>/dev/null | tail -n +2 | awk '{print $2}')
    
    if [ -n "$running_models" ]; then
        for model in $running_models; do
            echo "  停止: $model"
            ollama stop "$model" 2>/dev/null || true
        done
        sleep 3
    else
        echo "  無運行中模型"
    fi
    
    # 2. 檢查並殺死異常進程
    echo "🔍 檢查異常GPU進程..."
    local gpu_processes=$(nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader 2>/dev/null | head -5)
    
    if [ -n "$gpu_processes" ]; then
        echo "  發現GPU進程:"
        echo "$gpu_processes" | while read pid name; do
            echo "    PID $pid: $name"
            # 只殺死非Ollama進程
            if [[ "$name" != *"ollama"* ]] && [[ "$name" != *"Ollama"* ]]; then
                echo "    殺死異常進程: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # 3. 等待VRAM釋放
    echo "⏳ 等待VRAM釋放..."
    sleep 5
    
    # 4. 檢查清理結果
    local vram_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1)
    local vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    local vram_percent=$((vram_used * 100 / vram_total))
    
    echo "[$TIMESTAMP] 清理完成: ${vram_used}MB/${vram_total}MB (${vram_percent}%)" >> "$LOG_FILE"
    
    if [ $vram_percent -lt 50 ]; then
        echo "✅ VRAM清理成功: ${vram_percent}%"
        return 0
    else
        echo "⚠️  VRAM清理不完全: ${vram_percent}%"
        return 1
    fi
}

# 優化模型加載策略
optimize_model_loading() {
    echo "[$TIMESTAMP] 優化模型加載策略" >> "$LOG_FILE"
    
    # 檢查當前配置
    local config_file="$HOME/.ollama/config.json"
    if [ ! -f "$config_file" ]; then
        echo "⚠️  Ollama配置檔案不存在"
        return 1
    fi
    
    # 確保配置正確
    local keep_alive=$(grep -o '"OLLAMA_KEEP_ALIVE":[[:space:]]*"[^"]*"' "$config_file" | cut -d'"' -f4)
    local max_models=$(grep -o '"OLLAMA_MAX_LOADED_MODELS":[[:space:]]*[0-9]*' "$config_file" | cut -d':' -f2 | tr -d ' ,')
    
    echo "📋 當前配置:"
    echo "  KEEP_ALIVE: $keep_alive"
    echo "  MAX_LOADED_MODELS: $max_models"
    
    # 建議配置
    if [[ "$keep_alive" != "30s" ]]; then
        echo "💡 建議: KEEP_ALIVE改為30s"
    fi
    
    if [[ "$max_models" != "1" ]]; then
        echo "💡 建議: MAX_LOADED_MODELS改為1"
    fi
    
    echo "[$TIMESTAMP] 配置檢查完成" >> "$LOG_FILE"
}

# 主管理函數
manage_vram() {
    echo "========================================="
    echo "💾 **VRAM管理系統**"
    echo "========================================="
    echo "🕐 時間: $TIMESTAMP"
    echo "🎯 目標: VRAM使用 < ${VRAM_THRESHOLD}%"
    echo ""
    
    # 檢查VRAM使用
    if check_vram_usage; then
        echo "✅ VRAM使用正常"
        echo "💾 當前狀態: 無需清理"
    else
        echo "⚠️  VRAM使用過高，開始清理..."
        echo ""
        
        # 清理VRAM
        if cleanup_vram; then
            echo ""
            echo "✅ VRAM清理成功"
        else
            echo ""
            echo "⚠️  VRAM清理不完全，需要進一步檢查"
        fi
    fi
    
    echo ""
    
    # 優化模型加載策略
    echo "🔧 **模型加載優化**:"
    optimize_model_loading
    
    echo ""
    echo "📝 日誌檔案: $LOG_FILE"
    echo "========================================="
}

# 執行管理
manage_vram

# 如果是持續監控模式
if [ "${1:-}" = "continuous" ]; then
    echo ""
    echo "🚀 **啟動持續VRAM監控**"
    echo "監控間隔: 60秒"
    
    local cycle=1
    while true; do
        echo ""
        echo "🔄 監控週期 #$cycle ($(date "+%H:%M:%S"))"
        manage_vram
        echo "⏳ 等待60秒..."
        sleep 60
        cycle=$((cycle + 1))
    done
fi