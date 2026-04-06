#!/bin/bash
# 超級穩定版投資分析系統

LOG_FILE="/home/pclaw/.openclaw/workspace/logs/super-stable-investment.log"
DISCORD_CHANNEL="1488016233713500283"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ETF列表
ETFS=("0050" "0056" "00878")
index=0

# 無限重試循環
while true; do
    log "🔄 啟動投資分析循環"
    
    # 檢查Ollama
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "❌ Ollama服務不可用，等待30秒"
        sleep 30
        continue
    fi
    
    # 當前ETF
    current_etf="${ETFS[$index]}"
    index=$(( (index + 1) % ${#ETFS[@]} ))
    
    # 簡單分析任務
    log "📈 分析ETF: $current_etf"
    
    response=$(curl -s --max-time 10 http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"qwen2.5:latest\",
            \"prompt\": \"用一句話分析 $current_etf 投資價值\",
            \"stream\": false,
            \"options\": {\"num_predict\": 50}
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ]; then
        # 發送最簡通知到Discord群組
        message="投資分析 $current_etf: $response"
        
        /home/pclaw/.npm-global/bin/openclaw message send \
            --channel discord \
            --target "$DISCORD_CHANNEL" \
            --message "$message" 2>/dev/null && log "✅ Discord通知發送成功" || log "⚠️ Discord通知發送失敗"
    else
        log "⚠️ 分析任務失敗"
    fi
    
    # 固定間隔
    log "⏸️ 等待15分鐘"
    sleep 900
done