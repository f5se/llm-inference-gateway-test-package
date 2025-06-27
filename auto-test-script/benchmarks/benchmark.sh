#pip install vllm==0.3.3

export OPENAI_API_KEY=123

python ./benchmark_serving.py --base-url http://10.0.10.100:8000 \
--endpoint /v1/completions \
--tokenizer ./tokenizer/ \
--model-id /models/Qwen3-4B \
--load-inputs ./samples.txt \
--request-count 5000 \
--max-concurrent 800
