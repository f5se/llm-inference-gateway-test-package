#!/bin/bash

# 定义日志文件路径
LOG_FILE="benchmark_output.log"

# 清空旧日志（如不想清空可注释掉此行）
> "$LOG_FILE"

# 记录起始时间
echo "=== Benchmark NotLB 开始: $(date) ===" | tee -a "$LOG_FILE"
bash benchmark-notblb.sh 2>&1 | tee -a "$LOG_FILE"

# 等待 60 秒
echo "=== 等待 60 秒后开始 Benchmark TBLB ===" | tee -a "$LOG_FILE"
sleep 60

# 记录 TBLB 开始时间
echo "=== Benchmark TBLB 开始: $(date) ===" | tee -a "$LOG_FILE"
bash benchmark_tblb.sh 2>&1 | tee -a "$LOG_FILE"

# 记录完成时间
echo "=== 所有测试完成: $(date) ===" | tee -a "$LOG_FILE"

