#!/bin/bash
# 對話追蹤和引用系統
# 讓用戶清楚知道回覆哪句話，避免重複詢問

set -e

TRACKER_DIR="/home/pclaw/.openclaw/workspace/system/conversation-tracker"
mkdir -p "$TRACKER_DIR"

LOG_FILE="$TRACKER_DIR/tracker-$(date +%Y%m%d).log"
INDEX_FILE="$TRACKER_DIR/index-$(date +%Y%m%d).json"
SUMMARY_FILE="$TRACKER_DIR/summary-$(date +%Y%m%d).md"

log_tracker() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 1. 建立對話索引
build_conversation_index() {
    log_tracker "建立對話索引..."
    
    # 建立JSON索引結構
    cat > "$INDEX_FILE" << EOF
{
  "conversation_date": "$(date +%Y-%m-%d)",
  "last_updated": "$(date +%Y-%m-%d %H:%M:%S)",
  "message_count": 0,
  "user_messages": [],
  "assistant_responses": [],
  "question_answer_pairs": []
}
EOF
    
    log_tracker "✅ 對話索引建立完成: $INDEX_FILE"
}

# 2. 追蹤用戶問題
track_user_question() {
    local question_id="$1"
    local question_text="$2"
    local timestamp="$3"
    
    log_tracker "追蹤用戶問題: $question_id"
    
    # 更新索引
    python3 -c "
import json
import sys

try:
    with open('$INDEX_FILE', 'r') as f:
        index = json.load(f)
    
    # 添加用戶問題
    question_entry = {
        'id': '$question_id',
        'text': '$question_text',
        'timestamp': '$timestamp',
        'status': 'pending',
        'response_id': None
    }
    
    index['user_messages'].append(question_entry)
    index['message_count'] = len(index['user_messages']) + len(index['assistant_responses'])
    
    with open('$INDEX_FILE', 'w') as f:
        json.dump(index, f, indent=2)
    
    print('✅ 用戶問題已追蹤')
    
except Exception as e:
    print(f'❌ 追蹤失敗: {e}')
"
}

# 3. 追蹤助理回應
track_assistant_response() {
    local response_id="$1"
    local response_text="$2"
    local question_id="$3"
    local timestamp="$4"
    
    log_tracker "追蹤助理回應: $response_id (回應問題: $question_id)"
    
    # 更新索引
    python3 -c "
import json
import sys

try:
    with open('$INDEX_FILE', 'r') as f:
        index = json.load(f)
    
    # 添加助理回應
    response_entry = {
        'id': '$response_id',
        'text': '$response_text',
        'timestamp': '$timestamp',
        'question_id': '$question_id'
    }
    
    index['assistant_responses'].append(response_entry)
    
    # 更新對應問題狀態
    for i, question in enumerate(index['user_messages']):
        if question['id'] == '$question_id':
            index['user_messages'][i]['status'] = 'answered'
            index['user_messages'][i]['response_id'] = '$response_id'
            
            # 添加到問答對
            qa_pair = {
                'question_id': '$question_id',
                'question_text': question['text'],
                'response_id': '$response_id',
                'response_text': '$response_text',
                'timestamp': '$timestamp'
            }
            index['question_answer_pairs'].append(qa_pair)
            break
    
    index['message_count'] = len(index['user_messages']) + len(index['assistant_responses'])
    index['last_updated'] = '$timestamp'
    
    with open('$INDEX_FILE', 'w') as f:
        json.dump(index, f, indent=2)
    
    print('✅ 助理回應已追蹤')
    
except Exception as e:
    print(f'❌ 追蹤失敗: {e}')
"
}

# 4. 生成對話摘要
generate_conversation_summary() {
    log_tracker "生成對話摘要..."
    
    cat > "$SUMMARY_FILE" << EOF
# 對話追蹤摘要
## 日期: $(date +"%Y-%m-%d")
## 最後更新: $(date +"%H:%M:%S")

## 📊 對話統計
- **總消息數**: $(jq '.message_count' "$INDEX_FILE" 2>/dev/null || echo "0")
- **用戶問題數**: $(jq '.user_messages | length' "$INDEX_FILE" 2>/dev/null || echo "0")
- **助理回應數**: $(jq '.assistant_responses | length' "$INDEX_FILE" 2>/dev/null || echo "0")
- **已回答問題**: $(jq '[.user_messages[] | select(.status == "answered")] | length' "$INDEX_FILE" 2>/dev/null || echo "0")
- **待回答問題**: $(jq '[.user_messages[] | select(.status == "pending")] | length' "$INDEX_FILE" 2>/dev/null || echo "0")

## 🔍 問答追蹤

### 已回答問題:
EOF
    
    # 添加已回答問題
    jq -r '.question_answer_pairs[] | "#### Q: \(.question_text)\n**A**: \(.response_text)\n- 時間: \(.timestamp)\n- 問題ID: \(.question_id)\n- 回應ID: \(.response_id)\n"' "$INDEX_FILE" 2>/dev/null >> "$SUMMARY_FILE" || echo "無已回答問題" >> "$SUMMARY_FILE"
    
    cat >> "$SUMMARY_FILE" << EOF

### 待回答問題:
EOF
    
    # 添加待回答問題
    jq -r '.user_messages[] | select(.status == "pending") | "- **\(.text)** (ID: \(.id), 時間: \(.timestamp))"' "$INDEX_FILE" 2>/dev/null >> "$SUMMARY_FILE" || echo "無待回答問題" >> "$SUMMARY_FILE"
    
    cat >> "$SUMMARY_FILE" << EOF

## 🎯 使用指南

### 1. 如何知道回覆哪句話？
助理回應會包含:
- **問題ID引用**: [Q:問題ID]
- **問題摘要**: 簡要說明回覆的問題
- **時間標記**: 問題和回應的時間

### 2. 如何避免重複詢問？
檢查對話摘要:
\`\`\`bash
# 查看今日對話摘要
cat $SUMMARY_FILE

# 檢查特定問題狀態
grep "問題ID" $SUMMARY_FILE

# 查看所有已回答問題
grep "已回答問題" $SUMMARY_FILE -A 20
\`\`\`

### 3. 如何追蹤對話進度？
\`\`\`bash
# 查看對話索引
cat $INDEX_FILE | jq .

# 檢查未回答問題
cat $INDEX_FILE | jq '.user_messages[] | select(.status == "pending")'

# 查看對話統計
cat $SUMMARY_FILE | head -15
\`\`\`

## 🔧 技術實現

### 追蹤機制:
1. **每個用戶問題分配唯一ID**
2. **每個助理回應關聯問題ID**
3. **所有對話記錄到JSON索引**
4. **定期生成可讀摘要**

### 引用格式:
- **問題引用**: [Q:20260404-1623-001] (日期-時間-序號)
- **回應標記**: ↪️ 回覆 [Q:問題ID]
- **狀態標示**: ✅ 已回答 / ⏳ 處理中

### 驗證方法:
\`\`\`bash
# 驗證追蹤系統運行
ls -la $TRACKER_DIR/*.json

# 檢查今日對話
find $TRACKER_DIR -name "summary-*.md" -type f | tail -1 | xargs cat

# 測試追蹤功能
./system/conversation-tracker.sh --test
\`\`\`

---
*此系統解決「不知道回覆哪句話」問題*
*所有問答都有追蹤，避免重複詢問*
EOF
    
    log_tracker "✅ 對話摘要生成完成: $SUMMARY_FILE"
}

# 5. 建立回應引用模板
create_response_template() {
    log_tracker "建立回應引用模板..."
    
    TEMPLATE_FILE="$TRACKER_DIR/response-template.md"
    
    cat > "$TEMPLATE_FILE" << 'EOF'
## 回應引用格式模板

### 模板1: 直接回覆特定問題
```
↪️ 回覆 [Q:問題ID] 關於「問題摘要」

[你的回應內容...]

📌 問題追蹤:
- 問題ID: [Q:問題ID]
- 問題時間: [時間]
- 回應時間: [時間]
- 狀態: ✅ 已回答
```

### 模板2: 回覆多個相關問題
```
🔗 綜合回覆以下問題:
1. [Q:問題ID1] - 問題摘要1
2. [Q:問題ID2] - 問題摘要2

[綜合回應內容...]

📋 問題追蹤:
- 已回答問題: [Q:問題ID1], [Q:問題ID2]
- 回應時間: [時間]
```

### 模板3: 自主發言（非回覆）
```
💬 自主發言 - [主題]

[發言內容...]

📝 發言類型: 自主發言（非回覆特定問題）
```

### 模板4: 進度更新
```
🔄 進度更新 - [任務名稱]

[進度內容...]

🔗 相關問題: [Q:問題ID] (如有)
```

## 使用指南

### 何時使用引用格式？
- **回覆用戶問題時** → 使用模板1或2
- **自主提供資訊時** → 使用模板3
- **報告任務進度時** → 使用模板4

### 如何生成問題ID？
問題ID格式: `Q:YYYYMMDD-HHMM-SSS`
- YYYYMMDD: 日期
- HHMM: 時間
- SSS: 序號 (001, 002, ...)

### 如何引用舊問題？
```
↪️ 回覆 [Q:20260404-1623-001] 關於「免tag設定檢查」

[回應內容...]

📌 原始問題: 「之前讓你設定免tag的部分你檢查一下 應該又被刪了」
📅 問題時間: 2026-04-04 16:23
⏰ 回應時間: $(date +"%Y-%m-%d %H:%M")
```

## 自動化工具

### 自動生成引用:
```bash
# 生成問題引用
echo "↪️ 回覆 [Q:$(date +%Y%m%d-%H%M-001)] 關於「[問題摘要]」"

# 生成追蹤信息
echo "📌 問題追蹤:"
echo "- 問題ID: [Q:$(date +%Y%m%d-%H%M-001)]"
echo "- 回應時間: $(date +"%Y-%m-%d %H:%M")"
```

### 檢查問題狀態:
```bash
# 檢查問題是否已回答
grep "Q:20260404-1623-001" $SUMMARY_FILE

# 查看所有待回答問題
grep "待回答問題" $SUMMARY_FILE -A 10
```

---
*使用此模板確保對話清晰可追蹤*
*避免「不知道回覆哪句話」的困惑*
EOF
    
    log_tracker "✅ 回應引用模板建立完成: $TEMPLATE_FILE"
}

# 主執行
log_tracker "🚀 啟動對話追蹤系統..."

build_conversation_index
generate_conversation_summary
create_response_template

log_tracker "🎯 對話追蹤系統建立完成！"
log_tracker "📝 追蹤日誌: $LOG_FILE"
log_tracker "📋 對話索引: $INDEX_FILE"
log_tracker "📄 對話摘要: $SUMMARY_FILE"
log_tracker "📝 引用模板: $TRACKER_DIR/response-template.md"

echo "========================================"
echo "對話追蹤系統摘要:"
echo "1. 對話索引: 已建立 (JSON格式)"
echo "2. 對話摘要: 已生成 (Markdown格式)"
echo "3. 引用模板: 已建立 (4種回應格式)"
echo "4. 追蹤日誌: 已開始記錄"
echo "========================================"
echo "使用指南:"
echo "- 查看今日對話: cat $SUMMARY_FILE"
echo "- 檢查問題狀態: grep '問題ID' $SUMMARY_FILE"
echo "- 使用引用模板: cat $TRACKER_DIR/response-template.md"
echo "========================================"