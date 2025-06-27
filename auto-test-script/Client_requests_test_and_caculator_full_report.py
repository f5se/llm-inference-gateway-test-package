import requests
import time
from collections import Counter, defaultdict

SELECT_URL = "http://localhost:8080/scheduler/select"
STATUS_URL = "http://127.0.0.1:8080/pools/status"
TRIGGER_URLS = [
    "http://localhost:8001/trigger_update",
    "http://localhost:8002/trigger_update",
    "http://localhost:8003/trigger_update"
]

HEADERS = {"Content-Type": "application/json"}
POOL_REQUEST_PAYLOAD = {
    "pool_name": "example_pool1",
    "partition": "Common",
    "members": ["127.0.0.1:8001", "127.0.0.1:8002", "127.0.0.1:8003"]
}
MEMBERS = POOL_REQUEST_PAYLOAD["members"]

# 数据结构用于总表统计
history_selection = defaultdict(list)  # 每轮每个成员的选择概率
history_percent = defaultdict(list)    # 每轮每个成员的 /status percent

def run_scheduler_test(num_requests=1000):
    counter = Counter()
    success = 0
    fail = 0

    for _ in range(num_requests):
        try:
            response = requests.post(SELECT_URL, headers=HEADERS, json=POOL_REQUEST_PAYLOAD, timeout=3)
            if response.status_code == 200:
                # 新的纯文本响应格式
                selected = response.text.strip()
                if selected in MEMBERS:
                    counter[selected] += 1
                    success += 1
                else:
                    fail += 1
            else:
                fail += 1
        except Exception:
            fail += 1

    return counter, success, fail

def get_status_percent():
    try:
        response = requests.get(STATUS_URL, timeout=3)
        if response.status_code == 200:
            data = response.json()
            for pool in data.get("pools", []):
                if pool.get("name") == "example_pool1":
                    member_percents = {}
                    for m in pool.get("members", []):
                        addr = f"{m['ip']}:{m['port']}"
                        percent = m.get("percent", 0.0)
                        member_percents[addr] = percent
                    return member_percents
    except Exception:
        pass
    return {}

def print_round_report(counter, success, fail, percent_from_status, total):
    print("测试结果统计:")
    print("---------------------")
    print(f"总请求数: {total}")
    print(f"成功请求数: {success}")
    print(f"失败请求数: {fail}")
    print("#第一列是member成员，第二列式选择概率值，第三列是从/pools/status接口获取的percent字段值")
    print("----各成员被选择概率及score分值分布概率----------")
    for member in MEMBERS:
        picked_percent = (counter[member] / total) * 100 if total else 0
        status_percent = percent_from_status.get(member, 0.0)
        print(f"{member},{picked_percent:.2f}%,{status_percent:.2f}%")
    print("--------------------------------------------")

def trigger_metrics_update():
    all_success = True
    for url in TRIGGER_URLS:
        try:
            response = requests.post(url, timeout=3)
            if response.status_code != 200:
                all_success = False
                print(f"[错误] 请求 {url} 返回状态码: {response.status_code}")
                try:
                    print("响应内容:", response.json())
                except Exception:
                    print("响应内容非 JSON 格式:", response.text)
            else:
                json_data = response.json()
                if json_data.get("status") != "Metrics updated immediately":
                    all_success = False
                    print(f"[错误] 请求 {url} 响应内容异常: {json_data}")
        except Exception as e:
            all_success = False
            print(f"[错误] 请求 {url} 失败，异常信息: {e}")
    return all_success


def print_final_summary():
    print("\n======== 总体测试统计报告（所有轮次）========")
    for member in MEMBERS:
        print(f"\n{member}")
        print("-------------------------")
        print("选择概率\tLLM workload分布")
        for sel, perc in zip(history_selection[member], history_percent[member]):
            print(f"{sel:.2f}%\t{perc:.2f}%")
    print("--------------------------------------------\n")


import matplotlib.pyplot as plt
import seaborn as sns

def draw_visual_charts():
    print("\n正在生成可视化图表，请稍候...")

    sns.set(style="whitegrid")
    for member in MEMBERS:
        rounds = list(range(1, len(history_selection[member]) + 1))
        sel_values = history_selection[member]
        percent_values = history_percent[member]

        plt.figure(figsize=(10, 5))
        plt.plot(rounds, sel_values, marker='o', label="selective probability", linewidth=2)
        plt.plot(rounds, percent_values, marker='s', label="LLM workload distribution", linewidth=2)

        plt.title(f"{member}: selective probability vs. LLM workload distribution")
        plt.xlabel("Rounds")
        plt.ylabel("Percentage (%)")
        plt.xticks(rounds)
        plt.ylim(0, 100)
        plt.legend()
        plt.grid(True)
        plt.tight_layout()

        # 可选：保存为文件，也可以直接显示
        plt.savefig(f"{member.replace(':', '_')}_trend.png")
        plt.show()  # 如果你在本地运行，也可以取消注释来实时查看

    print("图表已生成，文件保存在当前目录下。")


def main():
    try:
        loop_times = int(input("请输入要循环的次数: "))
    except ValueError:
        print("请输入一个有效的数字")
        return

    for i in range(loop_times):
        print(f"\n=== 第 {i+1} 轮测试开始 ===")
        counter, success, fail = run_scheduler_test()
        status_percent = get_status_percent()

        # 当前轮次数据记录
        total = 1000
        for member in MEMBERS:
            picked_percent = (counter[member] / total) * 100 if total else 0
            status_val = status_percent.get(member, 0.0)
            history_selection[member].append(picked_percent)
            history_percent[member].append(status_val)

        # 显示本轮测试报告
        print_round_report(counter, success, fail, status_percent, total)

        print("暂停 1 秒，准备触发 metrics 更新...")
        time.sleep(1)

        if trigger_metrics_update():
            print("所有 metrics 更新请求执行成功。")
        else:
            print("部分 metrics 更新请求失败，请检查服务状态。")

    # 所有轮次完成后输出汇总表
    print_final_summary()

     # 绘制折线图
    draw_visual_charts()

if __name__ == "__main__":
    main()
