# LLM推理网关完整测试资源包

## 项目简介

这是一个用于测试LLM推理网关性能和负载均衡功能的完整测试资源包。该项目包含了模拟API服务、F5负载均衡器配置、自动化测试脚本和监控仪表板等组件，用于验证智能调度算法在LLM推理场景下的性能表现。

## 功能特性

- **模拟API服务**: 提供vLLM和SGLang风格的模拟API，支持动态指标更新
- **F5负载均衡器模拟**: 模拟F5 BIG-IP的池成员管理和认证功能  
- **智能调度iRule**: 实现基于实时指标的负载均衡调度算法
- **自动化压测工具**: 支持多并发级别的性能测试和背景流量生成
- **监控仪表板**: 基于Grafana和Prometheus的实时监控系统

## 项目结构

```
完整测试资源包/
├── auto-test-script/          # 自动化测试脚本
├── F5-irule/                  # F5 iRule规则文件
├── grafana/                   # Grafana监控配置
├── Mock-API/                  # 模拟API服务  
└── vllm-simulator/           # vLLM模拟器
```

## 快速开始

### 1. 启动模拟API服务

> 建议对所有python项目目录启用python虚拟环境
>
> 在各自python程序目录下执行以下两步后，再执行相关python程序
>
> `python3 -m venv .venv`
>
> `source .venv/bin/activate`

#### vLLM模拟API
```bash
cd Mock-API/llm-mock-api
python main.py #自动启动以下三个服务
python app_vllm.py  # 默认端口8001
python app_vllm2.py # 端口8002
python app_vllm3.py # 端口8003

```

#### SGlang模拟API

```
cd Mock-API/llm-mock-api
python main_sglang.py #自动启动以下三个服务
python app_sglang.py  # 默认端口8010
python app_sglang2.py # 端口8012
python app_sglang3.py # 端口8015
```

#### F5模拟API  

```bash
cd Mock-API/f5-mock-api
python f5-mock-api-updated.py  # 默认端口8443
#以下命令启动表示将pool member的IP都设置为host.docker.internal这个FQDN
#用于当在本地容器中运行scheduler调度器时，调度器可以通过该FQDN访问到在宿主机中启动的LLM mock API
python f5-mock-api-updated.py --localdocker 1 
```

### 2. 启动监控系统

> 完全本地模拟测试，可以不考虑启用grafana系统，在正式GPU环境下测试时候，应启用，是重要的观察工具

```bash
cd grafana
docker-compose up -d
```
访问地址：
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

### 3. 自动化测试

> 自动化测试是为真实的GPU环境提供的模拟测试脚本。本地功能性测试可仅使用curl等命令，当然使用自动化脚本也可以。

```bash
cd auto-test-script
-----------------------------------
├── Client_requests_test_and_caculator_full_report #用于确定调度器程序本身选择成员的概率与理论概率的符合度。需下面的llm和F5的mock API配合。

cd auto-test-script/benchmark
------------------------------------
├── backend_request_func.py ###核心程序，勿改动
├── benchmark-1gpu.sh #手动执行脚本
├── benchmark-4gpu.sh #手动执行脚本
├── benchmark-notblb-p.sh #手动执行脚本，可传参
├── benchmark-notblb.sh #手动执行脚本
├── benchmark.sh #手动执行脚本
├── benchmark_bg_log
├── benchmark_logs
├── benchmark_logs_handling
│   └── analyze_logs.py #自动化生成分析结果，仅限full_benchmark_scheduler.sh或full_benchmark_scheduler_forsamenode.sh生成的日志
├── benchmark_serving.py ###核心程序，勿改动
├── benchmark_tblb-p.sh #可传参脚本，被引用脚本，也可以手动运行
├── benchmark_tblb.sh #可传参脚本，被引用脚本，也可以手动运行
├── bg_traffic_pids
├── fixed_backend_taffic_loop.sh #对指定目标施加固定间隔流量脚本
├── full_benchmark_scheduler.sh #对于异构节点，或无需背景流量的主测试脚本 #可传参  ###完全自动化的脚本
├── full_benchmark_scheduler_forsamenode.sh #希望在测试流量中夹杂背景流量的主测试脚本 #可传参    ###完全自动化的脚本
├── keep-long-back-traffic-for-full-benchmark.sh #被引用脚本
├── keep-long-backend_traffic.sh #手动背景流量脚本
├── keep-random-back-traffic-for-full-benchmark.sh #被引用脚本
├── random_backend_traffic_loop.sh #对随机目标随机发起持续随机时间请求的脚本
├── run_benchmark.sh #手动测试脚本
├── run_benchmark_loop.sh #手动简单循环脚本
├── samples.txt ###prompt样本，勿改动
└── tokenizer ###核心程序，勿改动
    ├── tokenizer.json
    ├── tokenizer.model
    └── tokenizer_config.json

```

## API接口文档

### 1. vLLM模拟API

#### 程序说明

请查看`app-vllm*.py`，程序内提供了一些控制性配置。例如是否启用metrics值动态更新以及启用后多久自动更新一次，metrics动态更新的取值范围。注意如果修改，需多个子程序都修改。


#### 获取指标
- **接口**: `GET /metrics`
- **描述**: 获取vLLM格式的Prometheus指标
- **响应示例**:
```
# HELP vllm:num_requests_waiting Number of requests waiting to be processed.
# TYPE vllm:num_requests_waiting gauge
vllm:num_requests_waiting{model_name="qwen3"} 12.0
# HELP vllm:gpu_cache_usage_perc GPU KV-cache usage.
# TYPE vllm:gpu_cache_usage_perc gauge
vllm:gpu_cache_usage_perc{model_name="qwen3"} 0.1
```

#### 手动触发更新

> 该接口用于自动化测试时，外部系统主动触发一次metrics更新

- **接口**: `POST /trigger_update`
- **描述**: 立即更新指标数值
- **响应示例**:
```json
{"status": "Metrics updated immediately"}
```

#### 控制动态更新

> 一般用不上该接口，除非你想在脚本运行时通过API控制是否开启或关闭metrics动态更新

- **接口**: `POST /toggle_update/{state}`
- **参数**: state (0=关闭, 1=开启)
- **响应示例**:
```json
{"dynamic_update": true}
```



### 2. SGlang模拟API

> 功能同vLLM，仅指标是按照SGlang格式



### 3. F5模拟API

> 该API主要是在没有F5的情况下联调整个调度器程序。程序提供F5 tokens认证、更新模拟，模拟LTM pool资源对象接口。以便调度器可以模拟连接F5。
>
> 程序还提供了相应开关来模拟自动模拟Pool中的members变化。具体请查看程序内容。
>
> 为了保证程序的正常运行，你需要修改其中的`nterfaces = netifaces.ifaddresses("en0")`网卡名称为你的本地网卡名称。这样脚本可以模拟127.0.0.1以及一个本地正式IP，共计2个IP，通过组合不同Port来模拟多个成员。

#### 用户认证
- **接口**: `POST /mgmt/shared/authn/login`
- **请求体**:
```json
{
  "username": "admin",
  "password": "admin"
}
```
- **响应示例**:
```json
{
  "username": "admin",
  "loginProviderName": "tmos",
  "token": {
    "name": "ABCD1234...",
    "token": "ABCD1234...",
    "userName": "admin",
    "timeout": 1200
  }
}
```

#### 获取池成员
- **接口**: `GET /mgmt/tm/ltm/pool/~{partition}~{pool_name}/members`
- **请求头**: `X-F5-Auth-Token: {token}`
- **响应示例**:
```json
{
  "kind": "tm:ltm:pool:members:memberscollectionstate",
  "items": [
    {
      "name": "127.0.0.1:8001",
      "address": "127.0.0.1",
      "partition": "Common",
      "fullPath": "/Common/127.0.0.1:8001"
    }
  ]
}
```



## 测试场景举例说明

### 1. 压测脚本参数配置

> 以下仅为举例，具体请参看各自具体脚本内的配置

在`full_benchmark_scheduler_forsamenode.sh`中可以配置：

```bash
# 请求总数（默认10000）
REQUEST_COUNT=10000

# 并发配置
MAX_START=10        # 起始并发数
MAX_END=100         # 最大并发数  
STEP=10            # 并发递增步长

# 调度算法模式
MODES=("s1_enhanced" "s1_adaptive" "s1_ratio" "s1_precise" "s1_nonlinear")

# 背景流量配置
BG_TRAFFIC_MODE="random"  # static/random
BG_CONCURRENT=20         # 背景流量并发数
BG_REQUEST_COUNT=40000   # 背景流量请求数
```

### 2. iRule调度参数

在`F5-irule/irule_llm_timing.txt`中可以配置：

```tcl
set debug                0              # 调试开关
set pool_tblb_sched     "pool_tblb_sched"    # 调度器池名
set pool_backend_llm    "Pool_vllm"          # LLM后端池名
set side_timeout_ms     "500"               # sideband连接超时时间(毫秒)
set call_interval_ms    "10"                # 调度间隔(毫秒)，也就是irule缓存调度结果的时间
```



### 3. 模拟测试：本地功能性模拟测试

1. 按照快速开始部分的提示以及API接口部分提示的注意事项，启动以下支撑服务
   - F5 mock API
   - vLLM以及SGlang  mock API
2. 启动调度器主程序。调度器主程序及运行说明详见调度器相关资源文档
3. 使用`auto-test-script/Client_requests_test_and_caculator_full_report.py`自动化执行，程序会自动化生成实际选择百分比与理论百分比的对比报告，以证明调度器程序的有效性
4. 此时你已经可以直接向调度器的API发起请求，来查看调度器返回的决策结果。调度器API细节见调度器相关资源文档
5. 当然，自己还可以构建模拟客户端请求和LLM响应，形成端到端测试，如需这样测试，你还需要构建：
   - F5 BIG-IP，配置相关vs，部署相关iRule。部署真实的BIG-IP就意味着无需部署F5 mock API
   - 部署实际可以对prompt请求进行返回的LLM服务（真实的vLLM，或用`vllm-simulator`模拟的)
     - 需要注意的是，如果你部署真实的vLLM类服务，那么就不需要再部署vLLM或SGlang的mock API
     - 如果是部署的vllm-simulator，在这个模拟器中我们需要的部分指标不会出现自动化的metric值，因此还是需要部署vllm mock API (此API仅只有模拟metrics的功能)。这就会造成两个服务有两个不同端口，因此你需要在调度器配置中配置具体的vllm metrics接口（在生产环境下，一般vLLM的业务API接口与metrics API接口是使用相同端口）。



### 4. 实测：无背景压力流量的自动化测试

使用的脚本:`full_benchmark_scheduler.sh`

> 注意：测试中设置的request count一次总量不要超过50000，因为提供的prompt样本仅有50000个。

该测试可以自动模拟以下功能：

- 自动化测试多个不同算法模型
- 对每个算法在设定并发区间内按照步进数自动测试，例如从10并发开始，测试到1000并发止。按20并发累加步进
- 支持测试轮次中自动化修改并发累加步进数，以方便在一个完整的自动化测试周期的前期用小步进，在后期用大步进
- 支持测试轮次中自动化修改总请求数，支持在测试初期并发用户少时-使用较小总请求数，在后期大并发用户数时切换为较大总请求数
- 自动产生可被`analyze_logs.py`分析的日志



### 5. 实测：有背景压力流量的自动化测试

使用的脚本：`full_benchmark_scheduler_forsamenode.sh`

> 注意：测试中设置的request count一次总量不要超过50000，因为提供的prompt样本仅有50000个。

该测试可以自动模拟以下功能：

- 设置始终伴随的背景压力流量，例如在5个节点中，对其中2个固定节点持续施加压力流量，并同时对5个节点做正常测试
- 设置随机背景压力流量，例如在5个节点中，对2个随机节点进行随机启动的、持续随机时间的压力流量，并同时对5个节点做正常测试
- 可设置背景压力流量大小
- 自动化测试多个不同算法模型
- 对每个算法在设定并发区间内按照步进数自动测试，例如从10并发开始，测试到1000并发止。按20并发累加步进
- 支持测试轮次中自动化修改并发累加步进数，以方便在一个完整的自动化测试周期的前期用小步进，在后期用大步进
- 支持测试轮次中自动化修改总请求数，支持在测试初期并发用户少时-使用较小总请求数，在后期大并发用户数时切换为较大总请求数
- 自动产生可被`analyze_logs.py`分析的日志



### 6. 日志分析工具

脚本位于 `benchmark/benchmark_logs_handling`目录下，可自动化生成以下数据：

- 包含不同并发下，有和无tblb状态的以下指标的文件
  - Mean TTFT、 Median TTFT、P99 TTFT，Mean TPOT、Median TPOT、P99 TPOT
  - Mean TTFT 变化值、Median TTFT变化值、P99 TTFT变化值
- 同时提供 csv、Markdown、excel三种文件格式，以便更好的分析
- 脚本还会自动产生以下图形文件
  - 在有TBLB时，不同算法的TTFT，TPOT的比较曲线图
  - 每个算法在有/无 TBLB时的对比曲线图（包含Mean TTFT和Mean TPOT）

> 提示：未包含的统计分析类型，可借助大模型来分析，可简化工作。



## 注意事项

### 环境要求
- Python 3.7+
- Docker和Docker Compose
- bash shell环境
- 足够的系统资源支持高并发测试

### 安全注意事项
- F5模拟API使用自签名证书，仅用于测试环境
- 默认认证凭据为admin/admin，生产环境请修改
- API端口需要防火墙放行

### 性能调优建议
- 根据实际硬件配置调整并发数和请求数
- 监控系统资源使用情况，避免过载
- 测试前确保所有模拟服务正常运行
- 长时间测试建议分批进行，避免资源耗尽

### 常见问题
1. **权限问题**: 测试脚本需要执行权限，使用`chmod +x *.sh`赋权
2. **依赖缺失**: 确保Python依赖包已安装，如FastAPI、Flask、uvicorn、pandas、matplotlib等。测试阶段建议使用在各个目录使用python虚拟环境
3. **网络问题**: 确保Docker容器能够访问宿主机网络、端口火墙问题
4. **认证问题：**实际连接F5测试时，启动调度器脚本前记得export F5_PASSWORD环境变量的值为真实账号的密码，否则容易造成多次认证失败而账号锁定。调度器连接F5的账号用guest权限即可。



## 许可证

本项目用于F5测试和研究以及项目推动目的。 您可以任意修改、纠正程序中的错误、改进程序，但需要反馈给SE同事。您不应该将本方案架构、程序、思想、算法细节与任何友商共享。