#!/bin/bash

# Ollama配置優化腳本
# 基於官方最佳實踐優化配置

set -e

CONFIG_FILE="$HOME/.ollama/config.json"
BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"

echo "🔧 **Ollama配置優化**"
echo ""

# 備份當前配置
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "✅ 備份當前配置: $BACKUP_FILE"
fi

# 創建優化配置
cat > "$CONFIG_FILE" << EOF
{
  "OLLAMA_HOST": "127.0.0.1:11434",
  "OLLAMA_ORIGINS": "*",
  
  # 性能優化
  "OLLAMA_NUM_PARALLEL": 2,           # 並行請求數，避免過載
  "OLLAMA_KEEP_ALIVE": "30s",         # 保持活動時間，避免長時間佔用VRAM
  "OLLAMA_MAX_LOADED_MODELS": 1,      # 最大加載模型數，避免VRAM不足
  
  # GPU優化 (GTX 1080 Ti 11GB)
  "OLLAMA_GPU_LAYERS": 33,            # qwen3.5需要33層，避免過多
  "OLLAMA_FLASH_ATTENTION": true,     # 啟用閃存注意力，提升性能
  
  # 記憶體優化
  "OLLAMA_MMAP": true,                # 啟用記憶體映射，減少RAM使用
  "OLLAMA_F16": true                  # 使用半精度浮點數，減少VRAM使用
}
EOF

echo "✅ 創建優化配置: $CONFIG_FILE"
echo ""

# 顯示配置說明
echo "📋 **配置說明**:"
echo "1. KEEP_ALIVE: 30s - 模型閒置30秒後自動卸載，釋放VRAM"
echo "2. MAX_LOADED_MODELS: 1 - 同時只加載1個模型，避免VRAM不足"
echo "3. GPU_LAYERS: 33 - 匹配qwen3.5模型需求，避免浪費"
echo "4. NUM_PARALLEL: 2 - 允許2個並行請求，平衡性能"
echo ""

# 檢查當前VRAM使用
echo "📊 **當前VRAM狀態**:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | while read used total; do
        percent=$((used * 100 / total))
        echo "   VRAM使用: ${used}MB / ${total}MB (${percent}%)"
        
        if [ $percent -gt 80 ]; then
            echo "   ⚠️  VRAM使用過高，建議清理"
        fi
    done
fi

echo ""
echo "💡 **建議行動**:"
echo "1. 停止所有運行中模型: ollama stop <model>"
echo "2. 等待30秒讓配置生效"
echo "3. 重新啟動需要的模型"
echo "4. 監控VRAM使用變化"

echo ""
echo "📝 配置檔案: $CONFIG_FILE"
echo "💾 備份檔案: $BACKUP_FILE"