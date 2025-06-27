#!/bin/bash

# 固定目标服务器
TARGETS=("10.0.20.128:8000" "10.0.20.133:8000")

# 参数配置
MAX_CONCURRENT=${1:-100}
REQUEST_COUNT=${2:-10000}
RUN_DURATION=30     # 每次运行时间（秒）
INTERVAL=60         # 每次启动间隔（秒）

source .venv/bin/activate
export OPENAI_API_KEY=123
echo "🕒延迟60s开启"
sleep 60
while true; do
    echo "Starting new round at $(date)"

    # 启动所有目标服务器请求
    PIDS=()
    for TARGET in "${TARGETS[@]}"; do
        echo "→ Sending benchmark to $TARGET"
        python ./benchmark_serving.py --base-url http://$TARGET \
            --endpoint /v1/completions \
            --backend openai \
            --tokenizer ./tokenizer/ \
            --model-id /models/Qwen3-4B \
            --load-inputs ./samples.txt \
            --request-count "$REQUEST_COUNT" \
            --max-concurrent "$MAX_CONCURRENT" &
        PIDS+=($!)
    done

    # 等待运行时间
    sleep "$RUN_DURATION"

    # 结束所有进程
    echo "⏱ Killing benchmark processes after $RUN_DURATION seconds"
    for PID in "${PIDS[@]}"; do
        kill "$PID" 2>/dev/null
    done

    # 休眠到下一轮开始
    SLEEP_LEFT=$((INTERVAL - RUN_DURATION))
    if [ "$SLEEP_LEFT" -gt 0 ]; then
        echo "🕒 Waiting $SLEEP_LEFT seconds for next round..."
        sleep "$SLEEP_LEFT"
    fi

    echo "🔁 Round complete at $(date)"
done
"
