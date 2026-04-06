#!/bin/bash
# 工具使用追蹤系統
# 追蹤工具何時使用、如何使用、使用效果

set -e

USAGE_DIR="/home/pclaw/.openclaw/workspace/system/tool-usage"
USAGE_LOG="$USAGE_DIR/usage-$(date +%Y%m%d).log"
USAGE_REPORT="$USAGE_DIR/report-$(date +%Y%m%d-%H%M).md"
mkdir -p "$USAGE_DIR"

log_usage() {
    local tool="$1"
    local action="$2"
    local result="$3"
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 使用工具: $tool | 動作: $action | 結果: $result" | tee -a "$USAGE_LOG"
}

# 1. 檢查智能健康檢查工具使用
check_health_tools() {
    echo "🔍 檢查智能健康檢查工具使用..."
    
    # 趨勢分析工具
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/trend-analysis.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system/trend-analysis -name "*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "trend-analysis.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
    
    # 問題預測工具
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/problem-predictor.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system/problem-predictions -name "*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "problem-predictor.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
    
    # 智能優化工具
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/smart-optimizer.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system/optimizations -name "*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "smart-optimizer.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
    
    # 報告生成工具
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/report-generator.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system/work-reports -name "*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "report-generator.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
}

# 2. 檢查系統管理工具使用
check_system_tools() {
    echo "🔍 檢查系統管理工具使用..."
    
    # 健康檢查工具
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/system-health-check.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system -name "health-report-*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "system-health-check.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
    
    # 持續工作監控
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/continuous-work-monitor.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system/continuous-work -name "*.json" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        log_usage "continuous-work-monitor.sh" "檢查使用時間" "最後運行: $LAST_RUN"
    fi
}

# 3. 檢查任務設計工具使用
check_task_tools() {
    echo "🔍 檢查任務設計工具使用..."
    
    # 任務設計驗證
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/validate-task-design.sh" ]; then
        # 檢查是否在任務創建時使用
        USAGE_COUNT=$(grep -c "validate-task-design" /home/pclaw/.openclaw/workspace/system/*.md 2>/dev/null || echo "0")
        log_usage "validate-task-design.sh" "檢查使用次數" "在文件中被引用: $USAGE_COUNT 次"
    fi
}

# 4. 生成使用報告
generate_usage_report() {
    cat > "$USAGE_REPORT" << EOF
# 工具使用追蹤報告
## $(date +"%Y-%m-%d %H:%M:%S %Z")

## 📊 工具使用統計
### 智能健康檢查系統：
$(for tool in trend-analysis problem-predictor smart-optimizer report-generator; do
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/$tool.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system -path "*$(echo $tool | tr '-' '*')*" -name "*.md" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        echo "- **$tool.sh**: 最後運行: $LAST_RUN"
    fi
done)

### 系統管理工具：
$(for tool in system-health-check continuous-work-monitor; do
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/$tool.sh" ]; then
        LAST_RUN=$(find /home/pclaw/.openclaw/workspace/system -path "*$(echo $tool | tr '-' '*')*" -name "*" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $6, $7, $8}' || echo "從未運行")
        echo "- **$tool.sh**: 最後運行: $LAST_RUN"
    fi
done)

### 任務設計工具：
$(for tool in validate-task-design; do
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/$tool.sh" ]; then
        USAGE_COUNT=$(grep -c "$tool" /home/pclaw/.openclaw/workspace/system/*.md 2>/dev/null || echo "0")
        echo "- **$tool.sh**: 在文件中被引用: $USAGE_COUNT 次"
    fi
done)

## 📈 使用頻率分析
### 高頻使用工具（今天已使用）：
$(grep "$(date +%Y-%m-%d)" "$USAGE_LOG" 2>/dev/null | cut -d'|' -f2 | sort | uniq -c | sort -rn | head -5 | while read count tool; do
    echo "- $tool: $count 次"
done || echo "- 今天尚未使用工具")

### 最近使用工具（最後24小時）：
$(find /home/pclaw/.openclaw/workspace/system -type f -mtime -1 2>/dev/null | xargs ls -lt 2>/dev/null | head -5 | awk '{print $9}' | while read file; do
    tool=$(basename "$file" | sed 's/\..*//')
    echo "- $tool: $(date -r "$file" +"%H:%M")"
done || echo "- 24小時內無工具使用記錄")

## 🎯 使用效果驗證
### 工具產出檢查：
$(for dir in trend-analysis problem-predictions optimizations work-reports; do
    if [ -d "/home/pclaw/.openclaw/workspace/system/$dir" ]; then
        FILE_COUNT=$(find "/home/pclaw/.openclaw/workspace/system/$dir" -type f 2>/dev/null | wc -l)
        LAST_FILE=$(find "/home/pclaw/.openclaw/workspace/system/$dir" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $9}' | xargs basename 2>/dev/null || echo "無檔案")
        echo "- **$dir**: $FILE_COUNT 個檔案，最新: $LAST_FILE"
    fi
done)

### 系統改善指標：
- **任務錯誤變化**: $(openclaw tasks audit 2>&1 | grep "errors" | awk '{print $4}') 個錯誤
- **運行中任務**: $(openclaw tasks list --status running 2>&1 | grep -c "running") 個
- **工具總數**: $(ls /home/pclaw/.openclaw/workspace/scripts/*.sh 2>/dev/null | wc -l) 個
- **使用中工具**: $(grep -c "使用工具" "$USAGE_LOG" 2>/dev/null || echo "0") 個有使用記錄

## 🔄 使用計劃
### 自動化使用排程：
1. **每小時**: 執行趨勢分析和健康檢查
2. **每3小時**: 執行問題預測和優化
3. **每6小時**: 生成工作成果報告
4. **每天**: 全面系統檢查和優化

### 手動使用指南：
\`\`\`bash
# 檢查系統健康
./scripts/system-health-check.sh

# 分析趨勢
./scripts/trend-analysis.sh

# 預測問題
./scripts/problem-predictor.sh

# 執行優化
./scripts/smart-optimizer.sh

# 生成報告
./scripts/report-generator.sh
\`\`\`

## 📋 使用確認
### 我已使用的工具：
$(grep "使用工具" "$USAGE_LOG" 2>/dev/null | tail -5 | while read line; do
    echo "- $(echo "$line" | cut -d'|' -f1 | cut -d: -f2-)"
done || echo "- 尚未記錄工具使用")

### 待使用的工具：
$(for tool in /home/pclaw/.openclaw/workspace/scripts/*.sh; do
    tool_name=$(basename "$tool")
    if ! grep -q "$tool_name" "$USAGE_LOG" 2>/dev/null; then
        echo "- $tool_name"
    fi
done | head -5)

---
*此報告追蹤工具實際使用情況，確保工具不是空話*
*所有使用都有時間戳和結果記錄*
EOF
}

# 執行檢查
echo "🛠️ 開始工具使用追蹤..."
check_health_tools
check_system_tools
check_task_tools

# 生成報告
generate_usage_report

echo "✅ 工具使用追蹤完成！"
echo "📄 使用報告: $USAGE_REPORT"
echo "📝 使用日誌: $USAGE_LOG"
echo "========================================"
echo "工具使用摘要:"
grep "使用工具" "$USAGE_LOG" 2>/dev/null | tail -3 || echo "尚未記錄工具使用"
echo "========================================"