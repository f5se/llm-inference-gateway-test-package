#!/bin/bash
echo "[INFO] 脚本启动后。按 Ctrl+C 可中断当前轮次并清理后台流量。"
# === 全局清理函数（用于 Ctrl+C 或异常退出） ===
cleanup() {
    echo -e "\n[TRAP] 捕获到 Ctrl+C 或异常退出，开始清理后台流量进程..."
    stop_background_traffic
    echo "[TRAP] 清理完成，脚本退出。"
    exit 1
}

# === 捕获 Ctrl+C (SIGINT), 终止信号 (SIGTERM), 脚本异常退出 (ERR) ===
trap cleanup SIGINT SIGTERM ERR


# --- 参数设置 ---
# ---默认REQUEST总数10000，可通过传参进来---
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

#要对哪些模型进行测试,模型列表中的第一个模型要和START_MODE一致
#MODES=("s1_enhanced" "s1_adaptive" "s1_ratio" "s1_precise" "s1_nonlinear")
MODES=("s1_enhanced")
START_MODE="s1_enhanced"

#---从多少并发开始，按多少STEP步进增加到多少并发结束----
MAX_START=10
MAX_END=100
STEP=10
WAIT_BETWEEN_CONCURRENCY=30
WAIT_AFTER_REMOTE_CHANGE=20

#---控制并发到达某个阀值后，调整request_count值
THRESHOLD=999999  # 达到此并发数时切换 REQUEST_COUNT到NEW_REQUEST_COUNT。如大于MAX_END则不会发生测试中的REQUEST_COUNT调整
NEW_REQUEST_COUNT=15000
SWITCHED=false #程序控制性开关，无需改动

#---控制并发到达某个阀值后，调整STEP值
THRESHOLD_STEP=999999  # 达到此并发数时切换 STEP数值到new_step。如大于MAX_END则不会发生测试中的STEP调整
NEW_STEP=50
SWITCHED_STEP=false  #程序控制性开关，无需改动

# === 控制加载背景流量模式 ===
BG_TRAFFIC_MODE="random"   # static表示持续加压背景流量，可改为 "random"表示随机加载背景流量，背景流量不过调度器vs
RANDOM_BG_SCRIPT="./keep-random-back-traffic-for-full-benchmark.sh"

# === 配置背景压测并发和请求数 ===
BG_CONCURRENT=20
BG_REQUEST_COUNT=40000

# === 全局变量 ===
BG_PGID=""  # 背景流量进程组ID

start_background_traffic() {
    local MODE_NAME="$1"
    local STAGE="$2"
    local TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
    echo "[INFO] 启动背景流量 ($BG_TRAFFIC_MODE): $MODE_NAME - $STAGE"

    if [ "$BG_TRAFFIC_MODE" == "static" ]; then
        # 使用setsid创建进程组，统一管理方式
        BG_PGID=$(setsid bash ./keep-long-back-traffic-for-full-benchmark.sh "$BG_CONCURRENT" "$BG_REQUEST_COUNT" > /dev/null 2>&1 & echo $!)
        echo "[INFO] 静态背景流量进程组 ID: $BG_PGID"
    elif [ "$BG_TRAFFIC_MODE" == "random" ]; then
        # 使用setsid创建进程组，统一管理方式
        BG_PGID=$(setsid bash "$RANDOM_BG_SCRIPT" "$BG_CONCURRENT" "$BG_REQUEST_COUNT" > /dev/null 2>&1 & echo $!)
        echo "[INFO] 随机背景流量进程组 ID: $BG_PGID"
    else
        echo "[ERROR] 无效的 BG_TRAFFIC_MODE: $BG_TRAFFIC_MODE"
        exit 1
    fi

    sleep 5
}

stop_background_traffic() {
    echo "[INFO] 停止背景流量进程"
    if [ -n "$BG_PGID" ]; then
        echo "[DEBUG] 杀死整个进程组，PGID: $BG_PGID"
        # 杀死整个进程组，确保所有子进程都被清理
        kill -- -"$BG_PGID" 2>/dev/null
        # 等待进程清理完成
        sleep 2
        # 强制杀死如果还有残留进程
        kill -9 -- -"$BG_PGID" 2>/dev/null
        echo "[INFO] 已清理背景流量进程组: $BG_PGID"
        BG_PGID=""
    else
        echo "[WARN] 没有找到背景流量进程组 ID"
    fi
}


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

    # === 启动背景流量并执行 NOTBLB ===
    start_background_traffic "$MODE_NAME" "notblb"
    echo "[DEBUG] 主脚本获取到的进程组 ID 是: '$BG_PGID'"
    LOG_FILE_NOTBLB="$LOG_DIR/notblb_${MODE_NAME}_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"

    # 启动NOTBLB测试（在后台运行）
    bash "$SCRIPT_NOTBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_NOTBLB" 2>&1 &
    NOTBLB_PID=$!
    echo "[INFO] NOTBLB 测试启动，PID: $NOTBLB_PID，背景流量持续运行中..."

    # 等待NOTBLB测试完成
    wait "$NOTBLB_PID"
    NOTBLB_EXIT_CODE=$?

    # NOTBLB完成后停止背景流量
    stop_background_traffic

    if [ $NOTBLB_EXIT_CODE -ne 0 ]; then
        echo "[ERROR] NOTBLB failed for mode=$MODE_NAME concurrent=$MAX_CONCURRENT" | tee -a "$LOG_FILE_NOTBLB"
    fi

    # === 启动背景流量并执行 TBLB ===
    start_background_traffic "$MODE_NAME" "tblb"
    echo "[DEBUG] 主脚本获取到的进程组 ID 是: '$BG_PGID'"
    LOG_FILE_TBLB="$LOG_DIR/tblb_${MODE_NAME}_concurrent${MAX_CONCURRENT}_$TIMESTAMP.log"

    # 启动TBLB测试（在后台运行）
    bash "$SCRIPT_TBLB" "$MAX_CONCURRENT" "$REQUEST_COUNT" > "$LOG_FILE_TBLB" 2>&1 &
    TBLB_PID=$!
    echo "[INFO] TBLB 测试启动，PID: $TBLB_PID，背景流量持续运行中..."

    # 等待TBLB测试完成
    wait "$TBLB_PID"
    TBLB_EXIT_CODE=$?

    # TBLB完成后停止背景流量
    stop_background_traffic

    if [ $TBLB_EXIT_CODE -ne 0 ]; then
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
        STEP=$NEW_STEP
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
