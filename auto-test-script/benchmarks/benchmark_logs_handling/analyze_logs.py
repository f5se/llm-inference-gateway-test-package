import os
import re
import pandas as pd

# === 配置区域 ===
log_dir = "."  # 当前目录
output_prefix = "performance_comparison"

# === 目标指标 ===
metrics_keys = [
    "Mean TTFT",
    "Median TTFT",
    "P99 TTFT",
    "Mean TPOT",
    "Median TPOT",
    "P99 TPOT"
]

# === 文件名匹配规则 ===

log_pattern = re.compile(
    r"^(?P<tblb>tblb|notblb)_(?P<algorithm>.+?)_concurrent(?P<concurrent>\d+)_\d{8}_\d{6}\.log$"
)


# === 收集日志数据 ===
data = []

for filename in os.listdir(log_dir):
    match = log_pattern.match(filename)
    if not match:
        continue  # 跳过不匹配文件

    tblb_status = match.group("tblb")
    algorithm = match.group("algorithm")
    concurrent = int(match.group("concurrent"))
    filepath = os.path.join(log_dir, filename)

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    entry = {
        "Algorithm": algorithm,
        "Concurrent": concurrent,
        "TBLB_Status": tblb_status,
    }

    for key in metrics_keys:
        regex = re.search(rf"{re.escape(key)}:\s+([0-9.]+)\s*ms", content)
        entry[key] = float(regex.group(1)) if regex else None

    data.append(entry)

# === 转换为 DataFrame ===
df = pd.DataFrame(data)

if df.empty:
    print("❌ 未匹配到任何符合规范的 .log 文件，请检查文件名格式和路径")
    exit(1)

# === 拆分为 tblb / notblb DataFrame ===
tblb_df = df[df["TBLB_Status"] == "tblb"].set_index(["Algorithm", "Concurrent"])
notblb_df = df[df["TBLB_Status"] == "notblb"].set_index(["Algorithm", "Concurrent"])

# === 合并成对比表格 ===
combined = notblb_df.join(tblb_df, lsuffix="_notblb", rsuffix="_tblb")

# === 添加差值列 ===
for key in metrics_keys:
    combined[f"{key} Δ"] = combined[f"{key}_tblb"] - combined[f"{key}_notblb"]

combined.reset_index(inplace=True)

# === 输出文件 ===
combined.to_csv(f"{output_prefix}.csv", index=False)
combined.to_markdown(f"{output_prefix}.md", index=False)
combined.to_excel(f"{output_prefix}.xlsx", index=False)

print("✅ 分析完成，生成结果文件：")
print(f"- {output_prefix}.csv")
print(f"- {output_prefix}.md")
print(f"- {output_prefix}.xlsx")

import matplotlib.pyplot as plt

output_base = "performance_comparison"


# 第1图：有无 TBLB 下的 Mean TTFT / Mean TPOT
# 每个算法生成一个 TBLB vs notblb 的 TTFT/TPOT 对比图
for algorithm in df["Algorithm"].unique():
    plt.figure(figsize=(10, 6))
    subset = df[df["Algorithm"] == algorithm]

    for tblb_status in ["notblb", "tblb"]:
        part = subset[subset["TBLB_Status"] == tblb_status]
        grouped = part.groupby("Concurrent").mean(numeric_only=True).sort_index()

        if not grouped.empty:
            plt.plot(grouped.index, grouped["Mean TTFT"], label=f"{tblb_status} - Mean TTFT")
            plt.plot(grouped.index, grouped["Mean TPOT"], label=f"{tblb_status} - Mean TPOT", linestyle="--")
    
    
    all_concurrents = sorted(df["Concurrent"].unique())
    plt.xticks(all_concurrents)
    plt.gca().xaxis.set_major_locator(plt.FixedLocator(all_concurrents))
    plt.xticks(all_concurrents, rotation=45)
    plt.title(f"{algorithm} - TBLB vs No-TBLB: Mean TTFT & TPOT")
    plt.xlabel("Concurrent Requests")
    plt.ylabel("Latency (ms)")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    safe_alg_name = algorithm.replace("/", "_").replace(" ", "_")
    plt.savefig(f"{output_base}_{safe_alg_name}_tblb_vs_notblb.png")
    plt.close()


# 第2图：不同算法下的 Mean TTFT（仅 TBLB 场景）
plt.figure(figsize=(10, 6))
for algorithm in df["Algorithm"].unique():
    subset = df[(df["Algorithm"] == algorithm) & (df["TBLB_Status"] == "tblb")]
    grouped = subset.groupby("Concurrent").mean(numeric_only=True).sort_index()
    plt.plot(grouped.index, grouped["Mean TTFT"], label=algorithm)


all_concurrents = sorted(df["Concurrent"].unique())
plt.xticks(all_concurrents)
plt.gca().xaxis.set_major_locator(plt.FixedLocator(all_concurrents))
plt.xticks(all_concurrents, rotation=45)
plt.title("Mean TTFT vs Concurrent (per Algorithm with TBLB)")
plt.xlabel("Concurrent Requests")
plt.ylabel("Mean TTFT (ms)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig(f"{output_base}_alg_ttft.png")
plt.close()

# 第3图：不同算法下的 Mean TPOT（仅 TBLB 场景）
plt.figure(figsize=(10, 6))
for algorithm in df["Algorithm"].unique():
    subset = df[(df["Algorithm"] == algorithm) & (df["TBLB_Status"] == "tblb")]
    grouped = subset.groupby("Concurrent").mean(numeric_only=True).sort_index()
    plt.plot(grouped.index, grouped["Mean TPOT"], label=algorithm)

all_concurrents = sorted(df["Concurrent"].unique())
plt.xticks(all_concurrents)
plt.gca().xaxis.set_major_locator(plt.FixedLocator(all_concurrents))
plt.xticks(all_concurrents, rotation=45)
plt.title("Mean TPOT vs Concurrent (per Algorithm with TBLB)")
plt.xlabel("Concurrent Requests")
plt.ylabel("Mean TPOT (ms)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig(f"{output_base}_alg_tpot.png")
plt.close()

