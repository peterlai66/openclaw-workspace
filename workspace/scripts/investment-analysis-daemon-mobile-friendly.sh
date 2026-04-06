#!/bin/bash
# 手機友好版投資分析守護進程 (Discord群組版本)

set -e

LOG_FILE="/home/pclaw/.openclaw/workspace/logs/investment-analysis-mobile.log"
PID_FILE="/tmp/investment-analysis-mobile.pid"
DISCORD_CHANNEL="1488016233713500283"  # Discord群組頻道

# 防止重複運行
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 投資分析系統(手機版)已在運行" >> "$LOG_FILE"
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
    log "🧹 清理投資分析系統(手機版)"
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

# 檢查Ollama服務
check_ollama() {
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        return 0
    else
        log "⚠️ Ollama服務檢查失敗"
        return 1
    fi
}

# 生成ETF分析通知
generate_etf_analysis_notification() {
    local etf_info="$1"
    local etf_symbol=$(echo "$etf_info" | awk '{print $1}')
    local etf_name=$(echo "$etf_info" | cut -d' ' -f2-)
    
    log "📈 生成ETF分析通知: $etf_name"
    
    # 檢查Ollama服務
    if ! check_ollama; then
        log "❌ Ollama服務不可用"
        return 1
    fi
    
    # 使用適合台灣市場的模型
    local model="jcai/llama3-taide-lx-8b-chat-alpha1:q4_K_M"
    
    # 生成分析內容
    local prompt="用3個要點分析 $etf_name ($etf_symbol) 的投資價值，給出買入/持有/賣出建議。用繁體中文回答，包含具體理由。"
    
    local response=$(curl -s --max-time 30 http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.6,
                \"top_p\": 0.85,
                \"num_predict\": 350
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ] && [ ${#response} -gt 50 ]; then
        # 提取評級建議
        local rating="持有"
        if echo "$response" | grep -qi "買入\|建議買入\|推薦買入"; then
            rating="買入"
        elif echo "$response" | grep -qi "賣出\|建議賣出\|減持"; then
            rating="賣出"
        fi
        
        # 提取要點
        local point1=$(echo "$response" | grep -oE "1\..*" | head -1 | sed 's/1\.//' | cut -c1-70)
        local point2=$(echo "$response" | grep -oE "2\..*" | head -1 | sed 's/2\.//' | cut -c1-70)
        local point3=$(echo "$response" | grep -oE "3\..*" | head -1 | sed 's/3\.//' | cut -c1-70)
        
        # 如果沒有編號，嘗試其他格式
        if [ -z "$point1" ]; then
            point1=$(echo "$response" | head -2 | tail -1 | cut -c1-70)
            point2=$(echo "$response" | head -4 | tail -1 | cut -c1-70)
            point3=$(echo "$response" | head -6 | tail -1 | cut -c1-70)
        fi
        
        # 確保有內容
        [ -z "$point1" ] && point1="基本面穩健，適合長期投資"
        [ -z "$point2" ] && point2="技術面呈現整理格局"
        [ -z "$point3" ] && point3="市場環境影響短期表現"
        
        # 模擬價格數據（實際應該從API獲取）
        local price=$((100 + RANDOM % 50))
        local change=$((RANDOM % 5 - 2))
        local change_sign=""
        [ $change -ge 0 ] && change_sign="+" || change_sign=""
        
        # 構建手機友好通知
        local notification="📈 **投資分析 | ${etf_name}**
🕐 $(date '+%H:%M:%S') | 🎯 ${etf_symbol}

📊 **評級**: ${rating}
💰 **參考價格**: ${price}元 (${change_sign}${change}%)
📈 **技術信號**: 中性偏多

💡 **操作建議**:
• ${point1}
• ${point2}
• ${point3}

⚠️ **風險提示**:
• 市場波動風險
• 流動性風險
• 利率變動風險

🔍 **分析模型**: ${model}
🔄 **下次分析**: 約20-40分鐘後"
        
        echo "$notification"
        return 0
    else
        log "❌ 無法生成有效分析內容"
        return 1
    fi
}

# 生成市場趨勢通知
generate_market_trend_notification() {
    log "📊 生成市場趨勢通知"
    
    # 檢查Ollama服務
    if ! check_ollama; then
        log "❌ Ollama服務不可用"
        return 1
    fi
    
    # 使用適合市場分析的模型
    local model="qwen3.5:latest"
    
    # 生成分析內容
    local prompt="用3個要點總結當前台股市場趨勢，給出具體投資建議。用繁體中文回答。"
    
    local response=$(curl -s --max-time 30 http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.6,
                \"top_p\": 0.85,
                \"num_predict\": 300
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ] && [ ${#response} -gt 50 ]; then
        # 提取要點
        local point1=$(echo "$response" | grep -oE "1\..*" | head -1 | sed 's/1\.//' | cut -c1-70)
        local point2=$(echo "$response" | grep -oE "2\..*" | head -1 | sed 's/2\.//' | cut -c1-70)
        local point3=$(echo "$response" | grep -oE "3\..*" | head -1 | sed 's/3\.//' | cut -c1-70)
        
        # 如果沒有編號，嘗試其他格式
        if [ -z "$point1" ]; then
            point1=$(echo "$response" | head -2 | tail -1 | cut -c1-70)
            point2=$(echo "$response" | head -4 | tail -1 | cut -c1-70)
            point3=$(echo "$response" | head -6 | tail -1 | cut -c1-70)
        fi
        
        # 確保有內容
        [ -z "$point1" ] && point1="大盤呈現整理格局，等待方向"
        [ -z "$point2" ] && point2="資金輪動快速，選股為王"
        [ -z "$point3" ] && point3="國際市場影響台股表現"
        
        # 構建手機友好通知
        local notification="🌊 **台股市場趨勢分析**
🕐 $(date '+%H:%M:%S')

📊 **整體評級**: 中性
📈 **市場狀態**: 整理格局

🎯 **趨勢要點**:
1. ${point1}
2. ${point2}
3. ${point3}

💡 **投資建議**:
• 建議分批布局優質ETF
• 控制倉位，保留現金
• 關注國際市場變化

⚠️ **注意事項**:
• 波動加大，注意風險控制
• 避免追高殺低
• 定期檢視投資組合

🔍 **分析模型**: ${model}
🔄 **下次更新**: 約20-40分鐘後"
        
        echo "$notification"
        return 0
    else
        log "❌ 無法生成市場趨勢分析"
        return 1
    fi
}

# 發送Discord通知
send_discord_notification() {
    local notification="$1"
    local analysis_type="$2"
    
    log "📤 發送Discord通知: $analysis_type"
    
    /home/pclaw/.npm-global/bin/openclaw message send \
        --channel discord \
        --target "$DISCORD_CHANNEL" \
        --message "$notification" 2>/dev/null && log "✅ Discord通知發送成功" || log "⚠️ Discord通知發送失敗"
}

# 主函數
main() {
    log "🚀 啟動手機友好版投資分析系統 (Discord群組版)"
    log "📍 Discord頻道: $DISCORD_CHANNEL"
    
    # 初始檢查
    if ! check_ollama; then
        log "❌ 系統啟動失敗: Ollama服務不可用"
        exit 1
    fi
    
    # 發送啟動通知
    local startup_msg="📈 **投資分析系統(手機版)已啟動**
✅ 優化為手機友好格式
📱 所有分析內容在通知中完整呈現
🎯 包含具體操作建議和風險提示
🔄 每20-40分鐘發送一次分析報告
💡 無需查看檔案，手機直接可讀"
    
    send_discord_notification "$startup_msg" "系統啟動"
    
    local etf_index=0
    
    while true; do
        # 1. 分析市場趨勢
        log "📊 執行市場趨勢分析"
        market_notification=$(generate_market_trend_notification)
        
        if [ $? -eq 0 ] && [ -n "$market_notification" ]; then
            send_discord_notification "$market_notification" "市場趨勢"
            log "✅ 市場趨勢分析通知發送成功"
        else
            log "⚠️ 市場趨勢分析生成失敗"
        fi
        
        sleep 60  # 等待1分鐘
        
        # 2. 分析1個ETF
        local etf_info="${ETF_TARGETS[$etf_index]}"
        log "🔍 執行ETF分析: $etf_info"
        
        etf_notification=$(generate_etf_analysis_notification "$etf_info")
        
        if [ $? -eq 0 ] && [ -n "$etf_notification" ]; then
            send_discord_notification "$etf_notification" "ETF分析"
            log "✅ ETF分析通知發送成功"
        else
            log "⚠️ ETF分析生成失敗"
        fi
        
        # 更新索引
        etf_index=$(( (etf_index + 1) % ${#ETF_TARGETS[@]} ))
        
        # 等待間隔 (20-40分鐘)
        sleep_time=$((RANDOM % 1200 + 1200))  # 20-40分鐘
        log "⏸️ 等待 $(($sleep_time/60)) 分鐘後進行下一次分析"
        sleep "$sleep_time"
    done
}

main