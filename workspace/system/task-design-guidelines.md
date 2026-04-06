# 任務設計規範

## 核心原則：
**設計良好的任務不會卡住**

## 任務設計要求：

### 1. 明確標識
**必須有**：
- ✅ **label**：清晰描述任務目的
- ✅ **超時設置**：合理超時時間
- ✅ **進度檢查點**：定期報告進度

**禁止**：
- ❌ 無label的任務
- ❌ 無限運行的任務
- ❌ 無進度報告的任務

### 2. 生命周期管理
**必須實現**：
- ✅ **開始檢查**：資源和條件檢查
- ✅ **進度報告**：定期報告狀態
- ✅ **完成清理**：正確結束和清理
- ✅ **錯誤處理**：優雅失敗和恢復

### 3. 監控和恢復
**必須支持**：
- ✅ **健康檢查**：定期自我檢查
- ✅ **超時處理**：超時自動處理
- ✅ **恢復機制**：失敗後可恢復
- ✅ **狀態報告**：實時狀態可查詢

## 具體實現指南：

### 創建任務時必須：
```bash
# 錯誤示範（會卡住）：
openclaw tasks add --task "做一些事情"

# 正確示範（良好設計）：
openclaw tasks add \
  --label "系統優化：清理舊日誌" \
  --task "清理超過7天的日誌檔案" \
  --timeout "1h" \
  --progress-check "每10分鐘報告進度"
```

### 任務實現必須：
```python
# 僞代碼示例
class WellDesignedTask:
    def __init__(self):
        self.label = "清晰描述"
        self.timeout = 3600  # 1小時
        self.checkpoints = []
    
    def run(self):
        self.report_start()
        
        for checkpoint in self.checkpoints:
            if self.is_timed_out():
                self.handle_timeout()
                return
            
            self.execute_checkpoint(checkpoint)
            self.report_progress(checkpoint)
        
        self.report_success()
        self.cleanup()
    
    def handle_failure(self, error):
        self.report_failure(error)
        self.attempt_recovery()
        if not self.can_recover():
            self.cleanup_and_exit()
```

## 檢查清單：

### 創建任務前檢查：
- [ ] 是否有清晰的label？
- [ ] 是否有合理的超時時間？
- [ ] 是否有進度檢查點設計？
- [ ] 是否有錯誤處理機制？
- [ ] 是否有恢復方案？

### 運行中監控：
- [ ] 是否定期報告進度？
- [ ] 是否在超時範圍內？
- [ ] 是否有資源異常？
- [ ] 是否需要介入優化？

### 完成後審查：
- [ ] 是否正確清理資源？
- [ ] 是否有學習記錄？
- [ ] 是否有優化建議？
- [ ] 是否更新設計規範？

## 我的承諾：
**從現在開始，只創建設計良好的任務，從源頭避免卡住問題。**