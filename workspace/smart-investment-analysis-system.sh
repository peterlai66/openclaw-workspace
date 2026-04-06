#!/bin/bash

# 智能投資分析系統
# 專注台股ETF分析與投資建議

set -e

# 配置
LOG_DIR="/home/pclaw/.openclaw/workspace/logs/investment-analysis"
OUTPUT_DIR="/home/pclaw/.openclaw/workspace/investment-analysis-output"
DATA_DIR="/home/pclaw/.openclaw/workspace/investment-data"

# 重要ETF列表 (台股)
ETF_LIST=(
    "0050 元大台灣50"
    "0056 元大高股息"
    "00878 國泰永續高股息"
    "006208 富邦台50"
    "00713 元大台灣高息低波"
    "00919 群益台灣精選高息"
    "00929 復華台灣科技優息"
    "00939 統一台灣高息動能"
    "00940 元大台灣價值高息"
)

# 創建目錄
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$DATA_DIR"

# 日誌函數
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/system.log"
    echo "$1"
}

# 獲取市場數據 (模擬 - 實際需要API)
get_market_data() {
    local symbol="$1"
    local timestamp=$(date '+%Y%m%d')
    local data_file="$DATA_DIR/${symbol}_${timestamp}.json"
    
    log "📈 獲取市場數據: $symbol"
    
    # 模擬數據 - 實際應該使用FinMind或Fugle API
    cat > "$data_file" << EOF
{
  "symbol": "$symbol",
  "date": "$(date '+%Y-%m-%d')",
  "price": "$(echo $((100 + RANDOM % 50)))",
  "change": "$(echo $((RANDOM % 5 - 2)).$((RANDOM % 99)))",
  "volume": "$(echo $((10000 + RANDOM % 50000)))",
  "pe_ratio": "$(echo $((10 + RANDOM % 20)).$((RANDOM % 99)))",
  "dividend_yield": "$(echo $((2 + RANDOM % 8)).$((RANDOM % 99))%)",
  "technical_score": "$((30 + RANDOM % 70))",
  "fundamental_score": "$((30 + RANDOM % 70))"
}
EOF
    
    echo "$data_file"
}

# 分析單一ETF
analyze_etf() {
    local etf_symbol="$1"
    local etf_name="$2"
    local timestamp=$(date '+%Y%m%d_%H%M')
    local output_file="$OUTPUT_DIR/${etf_symbol}_analysis_${timestamp}.md"
    
    log "🔍 分析ETF: $etf_name ($etf_symbol)"
    
    # 獲取數據
    data_file=$(get_market_data "$etf_symbol")
    
    # 使用本地AI模型進行深度分析
    prompt="請分析台灣ETF '$etf_name ($etf_symbol)' 的投資價值，考慮：
    
1. **基本面分析**：
   - 成分股質量和分散度
   - 股息收益率和穩定性
   - 費用比率和管理品質

2. **技術面分析**：
   - 近期價格走勢
   - 成交量變化
   - 技術指標信號

3. **市場環境分析**：
   - 當前台股大盤狀況
   - 利率和經濟環境
   - 產業輪動趨勢

4. **風險評估**：
   - 市場風險
   - 流動性風險
   - 特定風險

請提供具體的投資建議，包括：
- 適合的投資者類型
- 建議的投資時機
- 風險控制策略
- 預期報酬範圍"

    # 使用適合台灣市場分析的模型
    model="jcai/llama3-taide-lx-8b-chat-alpha1:q4_K_M"
    
    response=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.6,
                \"top_p\": 0.85,
                \"num_predict\": 1000
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "分析失敗" ]; then
        # 生成分析報告
        echo "# ETF深度分析報告" > "$output_file"
        echo "**標的**: $etf_name ($etf_symbol)" >> "$output_file"
        echo "**分析時間**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
        echo "**使用模型**: $model" >> "$output_file"
        echo "" >> "$output_file"
        
        # 添加數據摘要
        if [ -f "$data_file" ]; then
            echo "## 市場數據摘要" >> "$output_file"
            price=$(jq -r '.price' "$data_file")
            change=$(jq -r '.change' "$data_file")
            dividend=$(jq -r '.dividend_yield' "$data_file")
            echo "- 當前價格: $price" >> "$output_file"
            echo "- 漲跌幅: $change" >> "$output_file"
            echo "- 股息率: $dividend" >> "$output_file"
            echo "" >> "$output_file"
        fi
        
        echo "## 深度分析" >> "$output_file"
        echo "$response" >> "$output_file"
        
        echo "" >> "$output_file"
        echo "## 投資建議摘要" >> "$output_file"
        echo "### 🎯 建議行動" >> "$output_file"
        echo "1. **立即行動**: " >> "$output_file"
        echo "2. **觀察等待**: " >> "$output_file"
        echo "3. **避免操作**: " >> "$output_file"
        echo "" >> "$output_file"
        echo "### ⚠️ 風險提示" >> "$output_file"
        echo "- 主要風險: " >> "$output_file"
        echo "- 控制策略: " >> "$output_file"
        
        log "✅ ETF分析完成: $output_file"
        
        # 發送分析摘要
        send_investment_analysis_summary "$etf_symbol" "$etf_name" "$output_file"
        
        return 0
    else
        log "❌ ETF分析失敗: $etf_symbol"
        return 1
    fi
}

# 市場趨勢分析
analyze_market_trend() {
    local timestamp=$(date '+%Y%m%d_%H%M')
    local output_file="$OUTPUT_DIR/market_trend_${timestamp}.md"
    
    log "📊 分析整體市場趨勢"
    
    prompt="請分析當前台灣股市的整體趨勢，特別關注：

1. **大盤指數分析**：
   - 加權指數走勢
   - 櫃買指數表現
   - 成交量變化

2. **產業輪動觀察**：
   - 強勢產業（半導體、AI、傳產等）
   - 弱勢產業
   - 資金流向

3. **國際市場影響**：
   - 美股對台股影響
   - 匯率變化
   - 國際資金動向

4. **技術指標信號**：
   - 均線排列
   - 技術指標（RSI、MACD等）
   - 關鍵支撐壓力位

5. **投資策略建議**：
   - 當前適合的投資風格（積極/保守）
   - 推薦的ETF或個股類型
   - 風險控制建議

請提供具體、可操作的投資建議。"

    model="qwen3.5:latest"
    
    response=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.7,
                \"top_p\": 0.9,
                \"num_predict\": 1200
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "趨勢分析失敗")
    
    if [ -n "$response" ] && [ "$response" != "趨勢分析失敗" ]; then
        echo "# 台股市場趨勢分析報告" > "$output_file"
        echo "**分析時間**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
        echo "**使用模型**: $model" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 市場趨勢分析" >> "$output_file"
        echo "$response" >> "$output_file"
        
        echo "" >> "$output_file"
        echo "## 🎯 本日投資建議" >> "$output_file"
        echo "### 推薦關注標的" >> "$output_file"
        echo "1. **優先考慮**: " >> "$output_file"
        echo "2. **可以觀察**: " >> "$output_file"
        echo "3. **暫時避開**: " >> "$output_file"
        echo "" >> "$output_file"
        echo "### 📅 操作策略" >> "$output_file"
        echo "- 短線操作: " >> "$output_file"
        echo "- 中長線布局: " >> "$output_file"
        echo "- 風險控制: " >> "$output_file"
        
        log "✅ 市場趨勢分析完成: $output_file"
        
        # 發送趨勢分析通知
        send_market_trend_summary "$output_file"
        
        return 0
    else
        log "❌ 市場趨勢分析失敗"
        return 1
    fi
}

# 投資組合建議
generate_portfolio_suggestion() {
    local timestamp=$(date '+%Y%m%d_%H%M')
    local output_file="$OUTPUT_DIR/portfolio_suggestion_${timestamp}.md"
    
    log "💼 生成投資組合建議"
    
    prompt="請為台灣投資者設計一個ETF投資組合，考慮不同風險偏好：

1. **保守型投資者**（風險承受度低）：
   - 適合的ETF組合
   - 配置比例建議
   - 預期報酬和風險

2. **穩健型投資者**（風險承受度中）：
   - 平衡的ETF組合
   - 成長與收益平衡
   - 定期調整策略

3. **積極型投資者**（風險承受度高）：
   - 成長導向ETF組合
   - 產業配置建議
   - 主動管理策略

請為每種類型提供具體的ETF標的、配置比例、和操作建議。"

    model="qwen3:14b"
    
    response=$(curl -s http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": \"$prompt\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.65,
                \"top_p\": 0.88,
                \"num_predict\": 1500
            }
        }" 2>/dev/null | jq -r '.response' 2>/dev/null || echo "組合建議失敗")
    
    if [ -n "$response" ] && [ "$response" != "組合建議失敗" ]; then
        echo "# 智能投資組合建議" > "$output_file"
        echo "**生成時間**: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
        echo "**適用對象**: 台灣ETF投資者" >> "$output_file"
        echo "**使用模型**: $model" >> "$output_file"
        echo "" >> "$output_file"
        echo "## 投資組合建議" >> "$output_file"
        echo "$response" >> "$output_file"
        
        echo "" >> "$output_file"
        echo "## 📊 配置摘要" >> "$output_file"
        echo "### 保守型組合" >> "$output_file"
        echo "- 預期年化報酬: " >> "$output_file"
        echo "- 最大回撤控制: " >> "$output_file"
        echo "- 適合人群: " >> "$output_file"
        echo "" >> "$output_file"
        echo "### 穩健型組合" >> "$output_file"
        echo "- 預期年化報酬: " >> "$output_file"
        echo "- 風險收益比: " >> "$output_file"
        echo "- 適合人群: " >> "$output_file"
        echo "" >> "$output_file"
        echo "### 積極型組合" >> "$output_file"
        echo "- 預期年化報酬: " >> "$output_file"
        echo "- 波動度預期: " >> "$output_file"
        echo "- 適合人群: " >> "$output_file"
        
        log "✅ 投資組合建議完成: $output_file"
        
        return 0
    else
        log "❌ 投資組合建議失敗"
        return 1
    fi
}

# 發送分析摘要
send_investment_analysis_summary() {
    local symbol="$1"
    local name="$2"
    local output_file="$3"
    
    summary="📈 **ETF深度分析完成**
**標的**: $name ($symbol)
**時間**: $(date '+%H:%M:%S')
**重點**: 包含基本面、技術面、風險評估
**建議**: 提供具體投資行動建議

📄 詳細報告已保存，請查閱具體分析內容。"
    
    /home/pclaw/.npm-global/bin/openclaw message send \
        --channel discord \
        --target 1488038362815266836 \
        --message "$summary" 2>/dev/null || log "⚠️ Discord通知發送失敗"
}

# 發送市場趨勢摘要
send_market_trend_summary() {
    local output_file="$1"
    
    summary="🌊 **台股市場趨勢分析完成**
**分析時間**: $(date '+%H:%M:%S')
**範圍**: 大盤指數、產業輪動、國際影響
**產出**: 本日投資建議和操作策略

📊 已生成具體投資建議，請查閱詳細報告。"
    
    /home/pclaw/.npm-global/bin/openclaw message send \
        --channel discord \
        --target 1488038362815266836 \
        --message "$summary" 2>/dev/null || log "⚠️ Discord通知發送失敗"
}

# 主循環
main_loop() {
    log "🚀 啟動智能投資分析系統"
    log "追蹤ETF數量: ${#ETF_LIST[@]}個"
    
    local cycle=0
    
    while true; do
        cycle=$((cycle + 1))
        log "🔄 開始第 $cycle 輪投資分析"
        
        # 1. 分析市場趨勢
        log "📊 執行市場趨勢分析"
        analyze_market_trend
        
        # 2. 分析2-3個重點ETF
        log "🔍 執行ETF深度分析"
        for i in {1..3}; do
            etf_index=$((RANDOM % ${#ETF_LIST[@]}))
            etf_info="${ETF_LIST[$etf_index]}"
            etf_symbol=$(echo "$etf_info" | awk '{print $1}')
            etf_name=$(echo "$etf_info" | cut -d' ' -f2-)
            
            analyze_etf "$etf_symbol" "$etf_name"
            
            # ETF分析間隔
            sleep $((RANDOM % 60 + 60))
        done
        
        # 3. 每3輪生成一次投資組合建議
        if [ $((cycle % 3)) -eq 0 ]; then
            log "💼 生成投資組合建議"
            generate_portfolio_suggestion
        fi
        
        log "⏸️ 第 $cycle 輪投資分析完成，等待下一輪"
        sleep 1800  # 30分鐘後開始下一輪
    done
}

# 啟動系統
main() {
    log "🔧 初始化智能投資分析系統"
    
    # 檢查Ollama服務
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "❌ Ollama服務未運行"
        exit 1
    fi
    
    log "✅ 系統準備就緒，開始投資分析"
    main_loop
}

# 執行
main "$@"