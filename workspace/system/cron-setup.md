# 定期檢查Cron任務設置

## 目標：
建立自動化的定期檢查系統，確保24/7持續工作。

## Cron任務配置：

### 1. 每小時健康檢查
```bash
# 每小時執行系統健康檢查
0 * * * * cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh >> /home/pclaw/.openclaw/workspace/system/health-check-cron.log 2>&1
```

### 2. 每30分鐘持續工作監控
```bash
# 每30分鐘檢查持續工作狀態
*/30 * * * * cd /home/pclaw/.openclaw/workspace && ./scripts/continuous-work-monitor.sh
```

### 3. 每日深度檢查
```bash
# 每天02:00執行深度檢查
0 2 * * * cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh --deep >> /home/pclaw/.openclaw/workspace/system/deep-check-$(date +\%Y\%m\%d).log 2>&1
```

### 4. 每週維護任務
```bash
# 每週一03:00執行維護
0 3 * * 1 cd /home/pclaw/.openclaw/workspace && ./scripts/maintenance-weekly.sh
```

### 5. 每月架構審查
```bash
# 每月1號04:00執行架構審查
0 4 1 * * cd /home/pclaw/.openclaw/workspace && ./scripts/architecture-review-monthly.sh
```

## 設置方法：

### 方法A：使用crontab
```bash
# 編輯當前用戶的crontab
crontab -e

# 添加上述cron任務
```

### 方法B：使用系統cron目錄
```bash
# 創建cron腳本
sudo nano /etc/cron.d/openclaw-health

# 內容：
0 * * * * pclaw cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh >> /home/pclaw/.openclaw/workspace/system/health-check-cron.log 2>&1
*/30 * * * * pclaw cd /home/pclaw/.openclaw/workspace && ./scripts/continuous-work-monitor.sh
```

### 方法C：使用OpenClaw內建Cron系統
```bash
# 使用OpenClaw的cron功能
openclaw cron add --name "hourly-health-check" --schedule "0 * * * *" --command "cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh"
```

## 驗證Cron任務：

### 檢查當前cron任務：
```bash
crontab -l
```

### 測試cron執行：
```bash
# 手動執行測試
cd /home/pclaw/.openclaw/workspace && ./scripts/system-health-check.sh
```

### 檢查日誌：
```bash
tail -f /home/pclaw/.openclaw/workspace/system/health-check-cron.log
```

## 監控和警報：

### 成功指標：
- ✅ 每小時健康檢查正常執行
- ✅ 持續工作監控正常運行
- ✅ 系統狀態持續良好
- ✅ 價值創造活動持續

### 警報機制：
- ❌ 健康檢查失敗
- ❌ 關鍵服務停止
- ❌ 任務錯誤過多
- ❌ 無價值創造活動

## 我的承諾：
**建立完整的自動化監控系統，確保24/7持續工作，不間斷創造價值。**