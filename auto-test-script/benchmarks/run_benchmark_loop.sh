#!/bin/bash

# 默认 request-count，如传参则使用参数值
REQUEST_COUNT=${1:-10000}
LOG_DIR="./benchmark_logs"
mkdir -p "$LOG_DIR"

# 初始 max_concurrent
MAX_CONCURRENT=200
MAX_LIMIT=500
STEP=20
WAIT_SECONDS=60

# 脚本路径
SCRIPT_NOTBLB="benchmark-notblb-p.sh"
SCRIPT_TBLB="benchmark_tblb-p.sh"

# 循环执行
while [ "$MAX_CONCURRENT" -le "$MAX_LIMIT" ]; do
    TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

    echo "=== [START] max_concurrent=$MAX_CONCURRENT at $TIMESTAMP ==="

    # 修改 notblb 脚本中 max-concurrent 参数并执行
    LOG_FILE_NOTBLB="$LOG_DIR/notblb_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"
    echo "[INFO] Running NOTBLB with max-concurrent=$MAX_CONCURRENT, request-count=$REQUEST_COUNT"
    bash "$SCRIPT_NOTBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_NOTBLB" 2>&1

    # 修改 tblb 脚本中 max-concurrent 参数并执行
    LOG_FILE_TBLB="$LOG_DIR/tblb_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"
    echo "[INFO] Running TBLB with max-concurrent=$MAX_CONCURRENT, request-count=$REQUEST_COUNT"
    bash "$SCRIPT_TBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_TBLB" 2>&1

    echo "[INFO] Waiting $WAIT_SECONDS seconds before next round..."
    sleep "$WAIT_SECONDS"

    # 递增
    MAX_CONCURRENT=$((MAX_CONCURRENT + STEP))
done

echo "=== [COMPLETE] All benchmark rounds finished ==="

