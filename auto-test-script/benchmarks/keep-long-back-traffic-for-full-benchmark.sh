#!/bin/bash

TARGETS=("10.0.20.128:8000" "10.0.20.133:8000")
MAX_CONCURRENT=${1:-10}
REQUEST_COUNT=${2:-10000}
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
PID_FILE="bg_traffic_pids/bg_traffic_pids_$TIMESTAMP.txt"

source .venv/bin/activate
export OPENAI_API_KEY=123

> "$PID_FILE"

for TARGET in "${TARGETS[@]}"; do
    LOG_FILE="./benchmark_bg_log/benchmark_${TARGET//:/_}_$TIMESTAMP.log"
    echo "🚀 Starting sustained benchmark to $TARGET" >&2

    python ./benchmark_serving.py --base-url http://$TARGET \
        --endpoint /v1/completions \
        --backend openai \
        --tokenizer ./tokenizer/ \
        --model-id /models/Qwen3-4B \
        --load-inputs ./samples.txt \
        --request-count "$REQUEST_COUNT" \
        --max-concurrent "$MAX_CONCURRENT" >> "$LOG_FILE" 2>&1 &

    echo $! >> "$PID_FILE"
done

echo "$PID_FILE"

