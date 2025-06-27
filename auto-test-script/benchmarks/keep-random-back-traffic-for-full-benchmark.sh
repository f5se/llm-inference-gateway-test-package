#!/bin/bash

# === 配置目标服务器列表 ===
SERVER_LIST=("10.0.20.128:8000" "10.0.20.133:8000" "10.0.20.133:8001" "10.0.20.133:8002" "10.0.20.133:8003")

# 并发和请求总数参数
MAX_CONCURRENT=${1:-80}
REQUEST_COUNT=${2:-1000}

# 创建目录
mkdir -p bg_traffic_pids

# 激活环境变量
source .venv/bin/activate
export OPENAI_API_KEY=123

# === 设置清理函数 ===
cleanup_children() {
    echo "[RANDOM-BG] 清理所有子进程..."
    # 杀死当前进程组中的所有进程
    jobs -p | xargs -r kill 2>/dev/null
    exit 0
}

# 捕获终止信号
trap cleanup_children SIGTERM SIGINT

echo "[RANDOM-BG] 启动随机背景流量脚本，主 PID: $$"

# === 循环执行 ===
while true; do
    # 随机延迟启动（1-30秒）
    START_DELAY=$((RANDOM % 30 + 1))
    echo "[RANDOM-BG] Sleeping ${START_DELAY}s..."
    sleep "$START_DELAY"

    # 随机选择两个不同的目标
    SELECTED=($(shuf -e "${SERVER_LIST[@]}" -n 2))
    SERVER1=${SELECTED[0]}
    SERVER2=${SELECTED[1]}
    echo "[RANDOM-BG] Selected servers: $SERVER1, $SERVER2"

    # 设置运行时间（10-20秒）
    RUN_DURATION=$((RANDOM % 11 + 10))
    echo "[RANDOM-BG] Running for ${RUN_DURATION}s..."

    # 启动两个 benchmark 流量进程
    python ./benchmark_serving.py --base-url http://$SERVER1 \
        --endpoint /v1/completions \
        --backend openai \
        --tokenizer ./tokenizer/ \
        --model-id /models/Qwen3-4B \
        --load-inputs ./samples.txt \
        --request-count "$REQUEST_COUNT" \
        --max-concurrent "$MAX_CONCURRENT" &

    PID1=$!

    python ./benchmark_serving.py --base-url http://$SERVER2 \
        --endpoint /v1/completions \
        --backend openai \
        --tokenizer ./tokenizer/ \
        --model-id /models/Qwen3-4B \
        --load-inputs ./samples.txt \
        --request-count "$REQUEST_COUNT" \
        --max-concurrent "$MAX_CONCURRENT" &

    PID2=$!

    echo "[RANDOM-BG] Started benchmark PIDs: $PID1, $PID2"

    sleep "$RUN_DURATION"

    echo "[RANDOM-BG] Killing benchmark PIDs: $PID1 and $PID2"
    kill "$PID1" 2>/dev/null
    kill "$PID2" 2>/dev/null
    
    # 等待进程完全结束
    wait "$PID1" 2>/dev/null
    wait "$PID2" 2>/dev/null
done
