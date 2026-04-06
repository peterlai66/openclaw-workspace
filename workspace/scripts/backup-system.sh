#!/bin/bash
# PClaw AI 系統備份腳本
# 目標：死掉時可以輕鬆還原到最近的狀態

BACKUP_DIR="/home/pclaw/.openclaw/backups"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_NAME="pclaw-backup-$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "🦞 PClaw AI 系統備份開始 [$DATE]"
echo "=========================================="

# 創建備份目錄
mkdir -p "$BACKUP_PATH"

echo "📁 備份關鍵目錄："

# 1. 配置檔案
echo "  🔄 備份配置檔案..."
cp -r /home/pclaw/.openclaw/openclaw.json "$BACKUP_PATH/"
cp -r /home/pclaw/.openclaw/gateway-identity.json "$BACKUP_PATH/" 2>/dev/null || echo "    ⚠️ gateway-identity.json 不存在"

# 2. 工作空間
echo "  🔄 備份工作空間..."
mkdir -p "$BACKUP_PATH/workspace"
cp -r /home/pclaw/.openclaw/workspace/* "$BACKUP_PATH/workspace/" 2>/dev/null

# 3. 代理配置
echo "  🔄 備份代理配置..."
mkdir -p "$BACKUP_PATH/agents"
cp -r /home/pclaw/.openclaw/agents/* "$BACKUP_PATH/agents/" 2>/dev/null

# 4. 腳本
echo "  🔄 備份腳本..."
mkdir -p "$BACKUP_PATH/scripts"
cp -r /home/pclaw/.openclaw/workspace/scripts/* "$BACKUP_PATH/scripts/" 2>/dev/null

# 5. 記憶檔案
echo "  🔄 備份記憶檔案..."
mkdir -p "$BACKUP_PATH/memory"
cp -r /home/pclaw/.openclaw/workspace/memory/* "$BACKUP_PATH/memory/" 2>/dev/null 2>/dev/null
cp -r /home/pclaw/.openclaw/workspace/MEMORY.md "$BACKUP_PATH/" 2>/dev/null

# 創建還原腳本
echo "  🔄 創建還原腳本..."
cat > "$BACKUP_PATH/restore.sh" << 'EOF'
#!/bin/bash
# PClaw AI 系統還原腳本

echo "🦞 PClaw AI 系統還原開始"
echo "=========================================="

if [ ! -f "./openclaw.json" ]; then
    echo "❌ 錯誤：找不到備份檔案"
    exit 1
fi

echo "⚠️ 警告：此操作將覆蓋當前系統配置"
echo "繼續嗎？(y/N)"
read -r confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ 取消還原"
    exit 0
fi

echo "🔧 開始還原..."

# 停止Gateway服務
echo "  ⏸️  停止Gateway服務..."
systemctl --user stop openclaw-gateway 2>/dev/null

# 還原配置檔案
echo "  🔄 還原配置檔案..."
cp -f ./openclaw.json /home/pclaw/.openclaw/
cp -f ./gateway-identity.json /home/pclaw/.openclaw/ 2>/dev/null

# 還原工作空間
if [ -d "./workspace" ]; then
    echo "  🔄 還原工作空間..."
    rm -rf /home/pclaw/.openclaw/workspace.bak 2>/dev/null
    mv /home/pclaw/.openclaw/workspace /home/pclaw/.openclaw/workspace.bak 2>/dev/null
    cp -r ./workspace /home/pclaw/.openclaw/
fi

# 還原代理配置
if [ -d "./agents" ]; then
    echo "  🔄 還原代理配置..."
    cp -r ./agents/* /home/pclaw/.openclaw/agents/ 2>/dev/null
fi

# 還原腳本
if [ -d "./scripts" ]; then
    echo "  🔄 還原腳本..."
    mkdir -p /home/pclaw/.openclaw/workspace/scripts
    cp -r ./scripts/* /home/pclaw/.openclaw/workspace/scripts/ 2>/dev/null
fi

# 還原記憶
if [ -d "./memory" ]; then
    echo "  🔄 還原記憶檔案..."
    mkdir -p /home/pclaw/.openclaw/workspace/memory
    cp -r ./memory/* /home/pclaw/.openclaw/workspace/memory/ 2>/dev/null
fi

if [ -f "./MEMORY.md" ]; then
    cp -f ./MEMORY.md /home/pclaw/.openclaw/workspace/ 2>/dev/null
fi

# 啟動Gateway服務
echo "  ▶️  啟動Gateway服務..."
systemctl --user start openclaw-gateway

echo ""
echo "✅ 還原完成！"
echo ""
echo "📋 還原內容："
echo "  - 系統配置 (openclaw.json)"
echo "  - Gateway身份 (gateway-identity.json)"
echo "  - 工作空間檔案"
echo "  - 代理配置"
echo "  - 腳本檔案"
echo "  - 記憶檔案"
echo ""
echo "⚠️ 注意：可能需要手動重啟相關服務"
EOF

chmod +x "$BACKUP_PATH/restore.sh"

# 創建備份清單
echo "  📝 創建備份清單..."
cat > "$BACKUP_PATH/backup-info.txt" << EOF
PClaw AI 系統備份
==================
備份時間: $DATE
備份名稱: $BACKUP_NAME

包含內容:
1. 系統配置
   - openclaw.json
   - gateway-identity.json

2. 工作空間
   - 所有工作空間檔案

3. 代理配置
   - 所有代理配置

4. 腳本檔案
   - 所有自定義腳本

5. 記憶檔案
   - MEMORY.md
   - memory/ 目錄

還原方法:
1. 進入備份目錄: cd $BACKUP_PATH
2. 執行還原: ./restore.sh
3. 確認還原

重要提醒:
- 還原前建議備份當前狀態
- 還原後可能需要重啟服務
- 檢查配置是否正確
EOF

# 計算備份大小
BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)

echo ""
echo "✅ 備份完成！"
echo "📊 備份資訊："
echo "  名稱: $BACKUP_NAME"
echo "  路徑: $BACKUP_PATH"
echo "  大小: $BACKUP_SIZE"
echo "  時間: $DATE"
echo ""
echo "🔧 還原方法："
echo "  cd $BACKUP_PATH"
echo "  ./restore.sh"
echo ""
echo "📈 備份統計："
echo "  總備份數: $(ls -1 "$BACKUP_DIR" | wc -l)"
echo "  最新備份: $BACKUP_NAME"

# 清理舊備份（保留最近5個）
echo ""
echo "🧹 清理舊備份（保留最近5個）..."
cd "$BACKUP_DIR" && ls -t | tail -n +6 | xargs -I {} rm -rf {} 2>/dev/null || true

echo "🦞 備份流程完成"