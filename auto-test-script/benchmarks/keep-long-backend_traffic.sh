#!/bin/bash

# 持续压测两个目标服务器
TARGETS=("10.0.20.128:8000" "10.0.20.133:8000")

# 并发和请求数配置（注意：这里设置大一点，比如持续压力每秒发起足够请求）
MAX_CONCURRENT=${1:-10}
REQUEST_COUNT=${2:-10000}  # 大数字以保持长时间运行，实际可以限制速率或时间

source .venv/bin/activate
export OPENAI_API_KEY=123

for TARGET in "${TARGETS[@]}"; do
    echo "🚀 Starting sustained benchmark to $TARGET"

    # 单独起一个后台任务，不结束
    python ./benchmark_serving.py --base-url http://$TARGET \
        --endpoint /v1/completions \
        --backend openai \
        --tokenizer ./tokenizer/ \
        --model-id /models/Qwen3-4B \
        --load-inputs ./samples.txt \
        --request-count "$REQUEST_COUNT" \
        --max-concurrent "$MAX_CONCURRENT" >> benchmark_$TARGET.log 2>&1 &
done

echo "✅ All benchmarks started in background. Use 'ps' or logs to monitor."

