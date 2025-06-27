#!/bin/bash

# --- 参数设置 ---
REQUEST_COUNT=${1:-10000}
LOG_DIR="./benchmark_logs"
mkdir -p "$LOG_DIR"

SCRIPT_NOTBLB="./benchmark-notblb-p.sh"
SCRIPT_TBLB="./benchmark_tblb-p.sh"


# ---当需要在执行过程中，自动修改调度器的算法时---
# 第一次运行时系统会提示是否确认保存known_host信息，需人工确认
REMOTE_HOST="root@47.110.148.0"
SSH_KEY="~/.ssh/key-for-llm-perf.pem"         # 替换为你的私钥路径
REMOTE_CONFIG="/root/scheduler/config/scheduler-config.yaml"


#---要对哪些模型进行测试,模型列表中的第一个模型要和START_MODE一致 ---
#MODES=("s1_enhanced" "s1_adaptive" "s1_ratio" "s1_precise" "s1_nonlinear")
MODES=("s2_enhanced" "s2_advanced" "s2_adaptive")
START_MODE="s1_enhanced"

#---从多少并发开始，按多少STEP步进增加到多少并发结束----
MAX_START=100
MAX_END=500
STEP=100
WAIT_BETWEEN_CONCURRENCY=30
WAIT_AFTER_REMOTE_CHANGE=20

#---控制并发到达某个阀值后，调整request_count值
THRESHOLD=999999  # 达到此并发数时切换 REQUEST_COUNT到NEW_REQUEST_COUNT。如大于MAX_END则不会发生测试中的REQUEST_COUNT调整
NEW_REQUEST_COUNT=15000
SWITCHED=false #程序控制性开关，无需改动


#---控制并发到达某个阀值后，调整STEP值
THRESHOLD_STEP=50000  # 达到此并发数时切换 NEW_STEP。如大于MAX_END则不会发生测试中的STEP调整
NEW_STEP=50
SWITCHED_STEP=false   #程序控制性开关，无需改动

# --- 单轮并发执行逻辑 ---
run_one_mode() {
    local MODE_NAME="$1"
    local MAX_CONCURRENT=$MAX_START

    echo "============================"
    echo ">>> 开始压力测试: mode=$MODE_NAME"
    echo "============================"

    while [ "$MAX_CONCURRENT" -le "$MAX_END" ]; do
	echo "Running test: MAX_CONCURRENT=$MAX_CONCURRENT, REQUEST_COUNT=$REQUEST_COUNT"

        TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

        echo ">>> [RUNNING] mode=$MODE_NAME, max_concurrent=$MAX_CONCURRENT"

        LOG_FILE_NOTBLB="$LOG_DIR/notblb_${MODE_NAME}_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"
        bash "$SCRIPT_NOTBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_NOTBLB" 2>&1
        if [ $? -ne 0 ]; then
            echo "[ERROR] NOTBLB failed for mode=$MODE_NAME concurrent=$MAX_CONCURRENT" | tee -a "$LOG_FILE_NOTBLB"
        fi

        LOG_FILE_TBLB="$LOG_DIR/tblb_${MODE_NAME}_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"
        bash "$SCRIPT_TBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_TBLB" 2>&1
        if [ $? -ne 0 ]; then
            echo "[ERROR] TBLB failed for mode=$MODE_NAME concurrent=$MAX_CONCURRENT" | tee -a "$LOG_FILE_TBLB"
        fi

        echo "[INFO] 等待 $WAIT_BETWEEN_CONCURRENCY 秒进入下一并发数测试"
        sleep $WAIT_BETWEEN_CONCURRENCY

	if [ "$SWITCHED" = false ] && [ $MAX_CONCURRENT -ge $THRESHOLD ]; then
            echo "Threshold reached: updating REQUEST_COUNT from $REQUEST_COUNT to $NEW_REQUEST_COUNT"
            REQUEST_COUNT=$NEW_REQUEST_COUNT
            SWITCHED=true
        fi

	if [ "$SWITCHED_STEP" = false ] && [ $MAX_CONCURRENT -ge $THRESHOLD_STEP ]; then
            echo "Threshold_step reached: updating STEP from $STEP to $NEW_STEP"
            STEP=50
            SWITCHED_STEP=true
        fi


        MAX_CONCURRENT=$((MAX_CONCURRENT + STEP))
    done
}

# --- SSH 修改远程 YAML 模式名 ---
update_remote_mode() {
    local NEW_MODE="$1"

    echo "[INFO] SSH 到远程服务器更新模式: $NEW_MODE"

    ssh -i "$SSH_KEY" "$REMOTE_HOST" bash << EOF
sed -i '/^modes:/,/^[^[:space:]]/ {
  /^[[:space:]]\\{2\\}-[[:space:]]*name:/ {
    s/^\\([[:space:]]\\{2\\}-[[:space:]]*name:[[:space:]]*\\).*/\\1$NEW_MODE/
    b
  }
}' "$REMOTE_CONFIG"
EOF

    if [ $? -ne 0 ]; then
        echo "[ERROR] SSH 替换失败，请检查连接、权限或目标文件路径"
        exit 1
    fi
}

# --- 主逻辑执行 ---
for MODE in "${MODES[@]}"; do
    if [ "$MODE" != "$START_MODE" ]; then
        echo "[INFO] 等待 $WAIT_BETWEEN_CONCURRENCY 秒后开始模式切换到 $MODE"
        sleep "$WAIT_BETWEEN_CONCURRENCY"
        update_remote_mode "$MODE"
        echo "[INFO] 等待 $WAIT_AFTER_REMOTE_CHANGE 秒后开始测试"
        sleep "$WAIT_AFTER_REMOTE_CHANGE"
    fi

    run_one_mode "$MODE"
done

echo "✅ 所有模式测试已完成，结果日志位于 $LOG_DIR"

