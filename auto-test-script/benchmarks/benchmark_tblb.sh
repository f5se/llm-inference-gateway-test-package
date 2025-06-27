#pip install vllm==0.3.3
source .venv/bin/activate
sleep 1

export export OPENAI_API_KEY=123

python ./benchmark_serving.py --base-url http://10.0.10.100:8000 \
--endpoint /v1/completions \
--tokenizer ./tokenizer/ \
--model-id /models/Qwen3-4B \
--load-inputs ./samples.txt \
--request-count 1000 \
--max-concurrent 100
