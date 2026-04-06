#!/bin/bash
# 智能投資分析守護進程 (Discord群組版本)

set -e

LOG_FILE="/home/pclaw/.openclaw/workspace/logs/investment-analysis-dc.log"
PID_FILE="/tmp/investment-analysis-dc.pid"
OUTPUT_DIR="/home/pclaw/.openclaw/workspace/investment-analysis-output"
DISCORD_CHANNEL="1488016233713500283"  # Discord群組頻道

# 防止重複運行
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 投資分析系統(DC版)已在運行" >> "$LOG_FILE"
        exit 0
    fi
fi

echo $$ > "$PID_FILE"

# 日誌函數
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 清理函數
cleanup() {
    log "🧹 清理投資分析系統(DC版)"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 重點ETF列表
ETF_TARGETS=(
    "0050 元大台灣50"
    "0056 元大高股息"
    "00878 國泰永續高股息"
    "00919 群益台灣精選高息"
    "00929 復華台灣科技優息"
)

# 發送Discord群組通知
send_discord_notification() {
    local title="$1"
    local content="$2"
    local etf_symbol="$3"
    
    message="📈 **$title**
🕐 $(date '+%H:%M:%S')
🎯 $etf_symbol
📊 $content
📝 詳細報告已保存至投資分析輸出目錄"
    
    log "📤 發送Discord群組通知: $title - $etf_symbol"
    
    /home/pclaw/.npm-global/bin/openclaw message send \
        --channel discord \
        --target "$DISCORD_CHANNEL" \
        --message "$message" 2>/dev/null || log "⚠️ Discord群組通知發送失敗"
}

# 執行市場趨勢分析
analyze_market_trend() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local output_file="$OUTPUT_DIR/trend_${timestamp}.md"
    
    log "📊 分析市場趨勢 (DC群組)"
    
    prompt="簡要分析當前台股市場趨勢，提供3個具體投資建議。"
    
    response=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"jcai/llama3-taide-lx-8b-chat-alpha1:q4_K_M\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.6,
                \"top_p\": 0.85,
                \"num_predict\": 500
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ]; then
        echo "# 市場趨勢快報 (Discord群組)" > "$output_file"
        echo "**時間**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
        echo "**頻道**: Discord群組" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 趨勢分析" >> "$output_file"
        echo "$response" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 🎯 投資建議" >> "$output_file"
        echo "1. **建議關注**: " >> "$output_file"
        echo "2. **操作策略**: " >> "$output_file"
        echo "3. **風險提示**: " >> "$output_file"
        
        log "✅ 市場趨勢分析完成 (DC群組)"
        
        # 發送Discord群組通知
        send_discord_notification "台股市場趨勢分析" "已更新市場分析報告" "大盤趨勢"
            
        return 0
    else
        log "❌ 市場趨勢分析失敗"
        return 1
    fi
}

# 分析單一ETF
analyze_single_etf() {
    local etf_info="$1"
    local etf_symbol=$(echo "$etf_info" | awk '{print $1}')
    local etf_name=$(echo "$etf_info" | cut -d' ' -f2-)
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local output_file="$OUTPUT_DIR/${etf_symbol}_${timestamp}.md"
    
    log "🔍 分析ETF (DC群組): $etf_name"
    
    prompt="分析 $etf_name ($etf_symbol) 的投資價值，提供買入/持有/賣出建議。"
    
    response=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"qwen3.5:latest\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.6,
                \"top_p\": 0.85,
                \"num_predict\": 400
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ]; then
        echo "# ETF分析報告 (Discord群組)" > "$output_file"
        echo "**標的**: $etf_name ($etf_symbol)" >> "$output_file"
        echo "**時間**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
        echo "**頻道**: Discord群組" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 分析摘要" >> "$output_file"
        echo "$response" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 💡 操作建議" >> "$output_file"
        echo "- 建議動作: " >> "$output_file"
        echo "- 理由: " >> "$output_file"
        echo "- 風險等級: " >> "$output_file"
        
        log "✅ ETF分析完成 (DC群組): $etf_symbol"
        
        # 發送Discord群組通知
        send_discord_notification "ETF深度分析" "$etf_name 分析完成" "$etf_symbol"
            
        return 0
    else
        log "❌ ETF分析失敗: $etf_symbol"
        return 1
    fi
}

# 主函數
main() {
    log "🚀 啟動智能投資分析系統 (Discord群組版)"
    
    mkdir -p "$OUTPUT_DIR"
    
    local etf_index=0
    
    while true; do
        # 1. 分析市場趨勢 (每輪都執行)
        analyze_market_trend
        
        # 2. 分析1個ETF (輪流)
        etf_info="${ETF_TARGETS[$etf_index]}"
        analyze_single_etf "$etf_info"
        
        # 更新索引
        etf_index=$(( (etf_index + 1) % ${#ETF_TARGETS[@]} ))
        
        # 等待間隔 (20-40分鐘)
        sleep_time=$((RANDOM % 1200 + 1200))  # 20-40分鐘
        log "⏸️ 等待 $(($sleep_time/60)) 分鐘後進行下一次分析"
        sleep "$sleep_time"
    done
}

main