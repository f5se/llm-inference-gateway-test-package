#!/bin/bash

# 配置目标服务器列表
SERVER_LIST=("10.0.20.128:8000" "10.0.20.133:8000" "10.0.20.133:8001" "10.0.20.133:8002" "10.0.20.133:8003")

# 并发和请求总数参数
MAX_CONCURRENT=${1:-80}
REQUEST_COUNT=${2:-1000}

source .venv/bin/activate
export OPENAI_API_KEY=123

while true; do
    # 1-60s 随机启动延迟
    START_DELAY=$((RANDOM % 60 + 1))
    echo "Sleeping ${START_DELAY}s before next round..."
    sleep "$START_DELAY"

    # 从列表中随机选出两个不重复的服务器
    SELECTED=($(shuf -e "${SERVER_LIST[@]}" -n 2))
    SERVER1=${SELECTED[0]}
    SERVER2=${SELECTED[1]}
    echo "Selected servers: $SERVER1 and $SERVER2"

    # 10-30s 随机运行时间
    RUN_DURATION=$((RANDOM % 31 + 10))
    echo "Each benchmark will run for ${RUN_DURATION}s..."

    # 启动两个 benchmark 进程（并发运行）
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

    # 等待随机运行时间后终止两个进程
    sleep "$RUN_DURATION"
    echo "Killing both benchmark processes after ${RUN_DURATION}s..."
    kill $PID1 2>/dev/null
    kill $PID2 2>/dev/null

    echo "Round complete."
done

