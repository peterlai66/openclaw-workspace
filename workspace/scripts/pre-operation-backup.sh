#!/bin/bash
# 重大操作前自動備份

OPERATION="$1"
echo "🦞 操作前自動備份 [$OPERATION]"
echo "=========================================="

# 執行快速備份
/home/pclaw/.openclaw/workspace/scripts/backup-system.sh > /tmp/pre-op-backup.log 2>&1

echo "✅ 操作前備份完成"
echo "📝 操作: $OPERATION"
echo "⏰ 時間: $(date '+%Y-%m-%d %H:%M:%S')"
