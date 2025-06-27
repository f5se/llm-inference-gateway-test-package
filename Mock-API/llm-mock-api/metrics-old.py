from fastapi import FastAPI, Response
import uvicorn
import threading
import multiprocessing

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent))

# vLLM mock metrics
app_vllm = FastAPI()

@app_vllm.get("/metrics")
def get_vllm_metrics():
    content = """
# HELP vllm:num_requests_waiting Number of requests waiting to be processed.
# TYPE vllm:num_requests_waiting gauge
vllm:num_requests_waiting{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 13.0
# HELP vllm:gpu_cache_usage_perc GPU KV-cache usage. 1 means 100 percent usage.
# TYPE vllm:gpu_cache_usage_perc gauge
vllm:gpu_cache_usage_perc{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 0.1
""".strip()
    return Response(content=content, media_type="text/plain")


app_vllm2 = FastAPI()

@app_vllm2.get("/metrics")
def get_vllm_metrics():
    content = """
# HELP vllm:num_requests_waiting Number of requests waiting to be processed.
# TYPE vllm:num_requests_waiting gauge
vllm:num_requests_waiting{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 222.0
# HELP vllm:gpu_cache_usage_perc GPU KV-cache usage. 1 means 100 percent usage.
# TYPE vllm:gpu_cache_usage_perc gauge
vllm:gpu_cache_usage_perc{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 0.3
""".strip()
    return Response(content=content, media_type="text/plain")


app_vllm3 = FastAPI()

@app_vllm3.get("/metrics")
def get_vllm_metrics():
    content = """
# HELP vllm:num_requests_waiting Number of requests waiting to be processed.
# TYPE vllm:num_requests_waiting gauge
vllm:num_requests_waiting{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 2222.0
# HELP vllm:gpu_cache_usage_perc GPU KV-cache usage. 1 means 100 percent usage.
# TYPE vllm:gpu_cache_usage_perc gauge
vllm:gpu_cache_usage_perc{model_name="./models/Qwen3-1.7B/models--Qwen--Qwen3-1.7B/snapshots/d3e258980a49b060055ea9038dad99d75923f7c4"} 0.99
""".strip()
    return Response(content=content, media_type="text/plain")




# 启动服务器的线程函数
def run_vllm():
    uvicorn.run(
        "metrics:app_vllm",
        host="0.0.0.0",
        port=8001,
        log_level="info",
        reload=True,
        reload_delay=0.25,
        workers=1
    )

def run_vllm2():
    uvicorn.run(
        "metrics:app_vllm2",
        host="0.0.0.0",
        port=8002,
        log_level="info",
        reload=True,
        reload_delay=0.25,
        workers=1
    )

def run_vllm3():
    uvicorn.run(
        "metrics:app_vllm3",
        host="0.0.0.0",
        port=8003,
        log_level="info",
        reload=True,
        reload_delay=0.25,
        workers=1
    )


if __name__ == "__main__":
    t1 = threading.Thread(target=run_vllm)
    t2 = threading.Thread(target=run_vllm2)
    t3 = threading.Thread(target=run_vllm3)

    t1.start()
    t2.start()
    t3.start()

    t1.join()
    t2.join()
    t3.join()
