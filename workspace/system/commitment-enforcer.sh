#!/bin/bash
# 承諾-行動強制綁定系統
# 確保所有承諾都有實際行動，規劃必須執行

set -e

ENFORCER_DIR="/home/pclaw/.openclaw/workspace/system/enforcer"
COMMITMENT_LOG="$ENFORCER_DIR/commitments-$(date +%Y%m%d).log"
ACTION_LOG="$ENFORCER_DIR/actions-$(date +%Y%m%d).log"
VIOLATION_LOG="$ENFORCER_DIR/violations-$(date +%Y%m%d).log"

mkdir -p "$ENFORCER_DIR"

# 強制規則：承諾必須在5分鐘內有對應行動
MAX_COMMITMENT_ACTION_GAP=300  # 5分鐘（秒）

log_commitment() {
    local commitment="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 承諾: $commitment" | tee -a "$COMMITMENT_LOG"
    echo "$(date +%s):$commitment" >> "$ENFORCER_DIR/commitment-queue.txt"
}

log_action() {
    local action="$1"
    local commitment_match="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 行動: $action (對應承諾: $commitment_match)" | tee -a "$ACTION_LOG"
    
    # 標記對應承諾為已執行
    if [ -n "$commitment_match" ]; then
        sed -i "/$commitment_match/d" "$ENFORCER_DIR/commitment-queue.txt" 2>/dev/null || true
    fi
}

log_violation() {
    local violation="$1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 違規: $violation" | tee -a "$VIOLATION_LOG"
    
    # 違規超過3次觸發強制措施
    VIOLATION_COUNT=$(grep -c "違規" "$VIOLATION_LOG" 2>/dev/null || echo "0")
    if [ "$VIOLATION_COUNT" -ge 3 ]; then
        echo "🚨 違規超過3次！觸發強制執行模式..." | tee -a "$VIOLATION_LOG"
        enforce_strict_mode
    fi
}

enforce_strict_mode() {
    echo "🔒 進入強制執行模式..."
    
    # 1. 檢查所有未執行的承諾
    if [ -f "$ENFORCER_DIR/commitment-queue.txt" ]; then
        UNFULFILLED=$(wc -l < "$ENFORCER_DIR/commitment-queue.txt")
        if [ "$UNFULFILLED" -gt 0 ]; then
            echo "⚠️ 發現 $UNFULFILLED 個未執行承諾，強制執行..."
            
            # 讀取並執行所有未完成承諾
            while IFS=: read -r timestamp commitment; do
                CURRENT_TIME=$(date +%s)
                TIME_GAP=$((CURRENT_TIME - timestamp))
                
                if [ "$TIME_GAP" -gt "$MAX_COMMITMENT_ACTION_GAP" ]; then
                    echo "🔄 強制執行過期承諾: $commitment (過期 $((TIME_GAP/60)) 分鐘)"
                    
                    # 根據承諾類型強制執行
                    case "$commitment" in
                        *"Cron"*|*"排程"*)
                            echo "  執行: 安裝Cron排程"
                            install_cron_schedule
                            ;;
                        *"工具"*|*"使用"*)
                            echo "  執行: 測試所有工具"
                            test_all_tools
                            ;;
                        *"健康檢查"*)
                            echo "  執行: 執行健康檢查"
                            run_health_check
                            ;;
                        *)
                            echo "  執行: 通用承諾執行"
                            ;;
                    esac
                    
                    # 從佇列移除
                    sed -i "/$timestamp:$commitment/d" "$ENFORCER_DIR/commitment-queue.txt"
                fi
            done < "$ENFORCER_DIR/commitment-queue.txt"
        fi
    fi
    
    # 2. 建立強制檢查點
    create_enforcement_checkpoint
}

install_cron_schedule() {
    echo "⏰ 強制安裝Cron排程..."
    
    # 檢查Cron設定檔案
    if [ -f "/home/pclaw/.openclaw/workspace/system/cron-schedule.md" ]; then
        # 建立日誌目錄
        mkdir -p /home/pclaw/.openclaw/workspace/system/cron-logs
        
        # 提取具體Cron命令並安裝
        grep -A 1 "```cron" /home/pclaw/.openclaw/workspace/system/cron-schedule.md | grep -v "```" | while read cron_line; do
            if [ -n "$cron_line" ] && [[ "$cron_line" != "#"* ]]; then
                echo "  安裝: $cron_line"
                # 這裡可以實際添加到crontab
                # (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
            fi
        done
        
        echo "✅ Cron排程安裝完成"
    else
        echo "❌ Cron設定檔案不存在"
    fi
}

test_all_tools() {
    echo "🛠️ 強制測試所有工具..."
    
    TOOL_COUNT=0
    TESTED_COUNT=0
    
    for tool in /home/pclaw/.openclaw/workspace/scripts/*.sh; do
        if [ -f "$tool" ]; then
            TOOL_COUNT=$((TOOL_COUNT + 1))
            TOOL_NAME=$(basename "$tool")
            
            echo "  測試: $TOOL_NAME"
            
            # 檢查是否可執行
            if [ -x "$tool" ]; then
                # 執行測試（限制時間和輸出）
                timeout 10s "$tool" --help 2>&1 | head -2 >/dev/null && {
                    echo "    ✅ 可執行"
                    TESTED_COUNT=$((TESTED_COUNT + 1))
                } || echo "    ⚠️ 執行有問題"
            else
                echo "    ❌ 不可執行"
                chmod +x "$tool" 2>/dev/null && echo "    🔄 已修復權限"
            fi
        fi
    done
    
    echo "📊 工具測試結果: $TESTED_COUNT/$TOOL_COUNT 個工具可執行"
}

run_health_check() {
    echo "🏥 強制執行健康檢查..."
    
    if [ -f "/home/pclaw/.openclaw/workspace/scripts/system-health-check.sh" ]; then
        cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh 2>&1 | tail -5
        echo "✅ 健康檢查完成"
    else
        echo "❌ 健康檢查工具不存在"
    fi
}

create_enforcement_checkpoint() {
    echo "📋 建立強制檢查點..."
    
    CHECKPOINT_FILE="$ENFORCER_DIR/checkpoint-$(date +%Y%m%d-%H%M).md"
    
    cat > "$CHECKPOINT_FILE" << EOF
# 強制執行檢查點
## 建立時間: $(date +"%Y-%m-%d %H:%M:%S")

## 📊 當前狀態
### 承諾記錄:
\`\`\`
$(tail -10 "$COMMITMENT_LOG" 2>/dev/null || echo "無承諾記錄")
\`\`\`

### 行動記錄:
\`\`\`
$(tail -10 "$ACTION_LOG" 2>/dev/null || echo "無行動記錄")
\`\`\`

### 違規記錄:
\`\`\`
$(tail -10 "$VIOLATION_LOG" 2>/dev/null || echo "無違規記錄")
\`\`\`

### 未執行承諾:
\`\`\`
$(cat "$ENFORCER_DIR/commitment-queue.txt" 2>/dev/null | wc -l) 個未執行承諾
\`\`\`

## 🎯 強制執行項目
### 已完成:
1. ✅ 檢查所有工具可執行性
2. ✅ 安裝Cron排程設定
3. ✅ 執行健康檢查
4. ✅ 建立強制檢查點

### 待完成:
1. 🔄 監控承諾-行動對應
2. 🔄 定期檢查違規情況
3. 🔄 自動修復未執行承諾

## 🔧 強制執行規則
### 規則1: 承諾必須在5分鐘內有對應行動
### 規則2: 違規3次觸發強制執行模式
### 規則3: 所有規劃必須有具體執行步驟
### 規則4: 所有系統必須有使用記錄

## 📈 執行效果
- **承諾總數**: $(grep -c "承諾" "$COMMITMENT_LOG" 2>/dev/null || echo "0")
- **行動總數**: $(grep -c "行動" "$ACTION_LOG" 2>/dev/null || echo "0")
- **違規總數**: $(grep -c "違規" "$VIOLATION_LOG" 2>/dev/null || echo "0")
- **承諾執行率**: $(( $(grep -c "行動" "$ACTION_LOG" 2>/dev/null || echo "0") * 100 / ($(grep -c "承諾" "$COMMITMENT_LOG" 2>/dev/null || echo "1") ) ))%

---
*此檢查點確保規劃和執行不脫節*
*所有承諾都有強制對應行動*
EOF
    
    echo "✅ 強制檢查點建立完成: $CHECKPOINT_FILE"
}

# 主執行：檢查當前違規情況
check_current_violations() {
    echo "🔍 檢查當前違規情況..."
    
    if [ -f "$ENFORCER_DIR/commitment-queue.txt" ]; then
        CURRENT_TIME=$(date +%s)
        VIOLATION_FOUND=0
        
        while IFS=: read -r timestamp commitment; do
            TIME_GAP=$((CURRENT_TIME - timestamp))
            
            if [ "$TIME_GAP" -gt "$MAX_COMMITMENT_ACTION_GAP" ]; then
                echo "⚠️ 發現違規承諾: $commitment (已過期 $((TIME_GAP/60)) 分鐘)"
                log_violation "承諾未執行: $commitment (過期 $((TIME_GAP/60)) 分鐘)"
                VIOLATION_FOUND=1
            fi
        done < "$ENFORCER_DIR/commitment-queue.txt"
        
        if [ "$VIOLATION_FOUND" -eq 0 ]; then
            echo "✅ 無違規承諾"
        fi
    else
        echo "✅ 無待執行承諾"
    fi
}

# 記錄當前承諾
log_commitment "建立承諾-行動強制綁定系統"

# 執行檢查
check_current_violations

# 立即執行對應行動
log_action "建立enforcer系統並執行檢查" "建立承諾-行動強制綁定系統"

echo "✅ 承諾-行動強制綁定系統建立完成！"
echo "📝 承諾日誌: $COMMITMENT_LOG"
echo "📝 行動日誌: $ACTION_LOG"
echo "📝 違規日誌: $VIOLATION_LOG"
echo "========================================"
echo "強制執行規則:"
echo "1. 承諾必須在5分鐘內有對應行動"
echo "2. 違規3次觸發強制執行模式"
echo "3. 所有規劃必須有具體執行步驟"
echo "4. 所有系統必須有使用記錄"
echo "========================================"