#!/bin/bash
# 使用参数 max_concurrent 和 request_count
MAX_CONCURRENT=${1:-100}
REQUEST_COUNT=${2:-10000}

source .venv/bin/activate
sleep 1
export OPENAI_API_KEY=123

python ./benchmark_serving.py --base-url http://10.0.10.200:8000 \
--endpoint /v1/completions \
--backend openai \
--tokenizer ./tokenizer/ \
--model-id /models/Qwen3-4B \
--load-inputs ./samples.txt \
--request-count "$REQUEST_COUNT" \
--max-concurrent "$MAX_CONCURRENT"

