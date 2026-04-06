#!/bin/bash
# Task狀態檢查腳本

echo "🦞 Task系統狀態檢查 [$(date '+%Y-%m-%d %H:%M:%S')]"
echo "=========================================="

# 檢查運行中的Task
echo "📊 運行中的Task:"
openclaw tasks list --status running 2>/dev/null || echo "  無運行中的Task"

echo ""
echo "📋 所有Task狀態:"
openclaw tasks list 2>/dev/null || echo "  無法獲取Task列表"

echo ""
echo "🔍 Task審計:"
openclaw tasks audit 2>/dev/null || echo "  無審計發現"

# 檢查本地模型可用性
echo ""
echo "🤖 本地模型狀態:"
if pgrep -f "ollama serve" > /dev/null; then
    echo "  ✅ Ollama服務運行中"
    # 測試本地模型回應
    echo "  🔄 測試本地模型回應..."
    timeout 5 curl -s http://localhost:11434/api/generate -d '{"model":"qwen:7b","prompt":"你好","stream":false}' 2>/dev/null | grep -q "response" && echo "  ✅ 本地模型可回應" || echo "  ⚠️ 本地模型回應測試失敗"
else
    echo "  ❌ Ollama服務未運行"
fi

echo ""
echo "📈 系統資源:"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "  記憶體: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "  磁碟: $(df -h /home | awk 'NR==2{print $5}')"