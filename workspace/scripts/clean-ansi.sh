#!/bin/bash
# 簡單的ANSI控制字符清理腳本
# 用法: clean-ansi.sh <輸入文件或管道>

# 主要清理函數
clean_ansi() {
  # 使用sed刪除常見的ANSI控制序列
  sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
      -e 's/\x1b\[[0-9;]*m//g' \
      -e 's/\x1b\[?[0-9;]*[hl]//g' \
      -e 's/\x1b\[?25[hl]//g' \
      -e 's/\x1b\[?2026[hl]//g' \
      -e 's/\x1b\[?1[hl]//g' \
      -e 's/\x0d//g' \
      -e 's/\x0c//g' \
      -e 's/\x07//g' \
      -e 's/\x1b//g'
}

# 如果有參數則處理文件，否則處理標準輸入
if [ $# -eq 0 ]; then
  clean_ansi
else
  for file in "$@"; do
    if [ -f "$file" ]; then
      echo "清理文件: $file"
      clean_ansi < "$file"
    else
      echo "文件不存在: $file" >&2
    fi
  done
fi