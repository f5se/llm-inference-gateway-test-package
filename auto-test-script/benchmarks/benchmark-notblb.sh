#pip install vllm==0.3.3
source .venv/bin/activate
sleep 1
export export OPENAI_API_KEY=123

python ./benchmark_serving.py --base-url http://10.0.10.200:8000 \
--endpoint /v1/completions \
--backend openai \
--tokenizer ./tokenizer/ \
--model-id /models/Qwen3-4B \
--load-inputs ./samples.txt \
--request-count 10000 \
--max-concurrent 100
