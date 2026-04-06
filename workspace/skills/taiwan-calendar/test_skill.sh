#!/bin/bash

echo "=== 台灣日曆技能測試 ==="
echo "測試時間: $(date)"
echo ""

echo "1. 測試今日查詢:"
python3 scripts/taiwan_calendar.py today
echo ""

echo "2. 測試特定日期查詢 (2026-04-07):"
python3 scripts/taiwan_calendar.py check 2026-04-07
echo ""

echo "3. 測試5個工作日計算:"
python3 scripts/taiwan_calendar.py add-days 5
echo ""

echo "4. 測試下一個工作日:"
python3 scripts/taiwan_calendar.py next-working
echo ""

echo "5. 測試4月份工作日統計:"
python3 scripts/taiwan_calendar.py range 2026-04-01 2026-04-30
echo ""

echo "=== 測試完成 ==="