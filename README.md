# Empirical1 — 第一阶段实证：数据构建 pipeline

## 目录结构

```
pipeline/     ★ 主流程（编号 = 跑的顺序）
  01_cleaning.do             4 张 collapsed 年度表 → lenth15_year.dta（Stata）
  02_build_full_data.ipynb   lenth15_year → full_data.dta (30 列) + 描述统计
  03_extensive.do            §3.3–3.4  extensive margin：选不选这个产品（Stata）
  patch_relative_main.ipynb  一次性补丁（02 重跑后即不需要），不编号
  patch_relative_main.do     同上，Stata 版 Step 2

results/      ★ 回归表（进 git，都是几 KB 的 txt）
  extensive/                 03 的 11 张表

diagnostics/  ★ 诊断脚本与输出（进 git，两边同步分析）
  compare_full_data.ipynb    新旧 full_data 逐列对比
  full_data_comparison.md    上面那个跑出来的报告
  03_extensive.log           03 的全过程 log

replicate/    旧口径忠实复现，存档备查
reference/    VM 原件与已被取代的版本，参考不跑
```

编号只给主流程留着；诊断和一次性补丁不占编号。

## 跑的顺序

| # | 文件 | 干什么 |
|---|---|---|
| 01 | `pipeline/01_cleaning.do` | 超大文件 append / 产品码清洗 / collapse（保留 year）|
| 02 | `pipeline/02_build_full_data.ipynb` | 建 `full_data.dta`；Step 0 那格可直接调 01，跑过就跳过 |
| 03 | `pipeline/03_extensive.do` | choice set 构造 + extensive margin 回归 |

跑完 02 想核对新旧差异，跑 `diagnostics/compare_full_data.ipynb`。

**路径切换**：01/03 顶部一行（`$DATA`/`$OUT` 或 `cd`），notebook 第一格的 `DATA`/`OUT`/`CODE`。03 用 `cd` + 相对路径，因为 `clear all` 会清掉 global 宏但不改工作目录。

## 输出去向的三条规则

| 类型 | 去向 | 进 git？ |
|---|---|---|
| **数据**（`.dta`） | `Empirical1_data/` | ❌ |
| **回归表**（`.txt`） | `Empirical1/results/<环节>/` | ✅ |
| **检测 / 诊断结果**（对比报告、核对表、log） | `Empirical1/diagnostics/` | ✅ |

结果和诊断进 git 是为了 VM 上跑完能同步到本地一起看。

## 03_extensive 的设计

**问题**：给定主产品，企业更可能把哪些产品加进产品组合？

**Choice set**：每个主产品取 `input top30 ∪ output top30`，剩下 ~2,720 个产品压成一行 `OTHER`（相似度取均值），代表"低相似度那一堆"。不这么做的话每个 firm-year 要摊平成 2,778 行，全是 0，太稀疏。

**相对原版 `code/description/diversification/diversification_complete.do` 的两处改动**，其余逐行照搬：

| 原版 | 改成 | 为什么 |
|---|---|---|
| `gsort firm_id year -production_value` | 末尾加 `product_id` | 只在 `production_value` 精确并列时起作用，不改排序语义。和 02 的主产品口径对齐，重跑结果稳定 |
| `joinby ..., unmatched(master)` 后 `drop _merge` | 删掉那一行 | `joinby` 不生成 `_merge`，`main_info` 和 `choice_set_union` 也都不带这列，原样跑必报 "variable not found" |

**内存**：`joinby` 那步是峰值——去中介后 ~1,157 万 firm-year × 平均 ~48 个候选 ≈ 5.5 亿行，粗估 25–30 GB。跑不动就分年跑再 append（峰值减半），或 top30 降到 top20。存盘后的 `div_data.dta` 只有 14 个窄列，后面所有回归都不吃紧。

## 数据来源与去向

| | 位置 | 说明 |
|---|---|---|
| **原始数据（只读，不修改）** | `Data/` | `buyer-yearly-17-collapsed.dta`、`buyer-yearly-18-collapsed.dta`、`seller-yearly-17-collapsed.dta`、`seller-yearly-18-collapsed.dta`、`bianma_all.dta`（19 位编码表，列 `product_id` str19 + 名称）、`bianma.dta`（9 位，核对用）、`full_product_similarity.dta` |
| **所有产物** | `Empirical1_data/` | 中间文件 + `full_data.dta` |
| **代码** | `Empirical1/` | 本仓库，git 同步 |

路径在两处切换 VM / 本地：`01_cleaning.do` 顶部的 `$DATA` / `$OUT`，notebook 第一格的 `DATA` / `OUT` / `CODE`。

**约定**：`.dta` 一律不进 git（仓库里没有 `.gitignore`，靠自觉）。

## 清洗逻辑的出处

照搬 `IO_Table/io_repro`（`02_cleaning_pipeline.do` + `pre_process.ipynb`），**唯一区别是全程保留 `year`**。

IO 表那条线在 `02_cleaning_pipeline.do` 第 120 行 `collapse (sum) v, by(firm_id product_id input_output)` 把 2017+2018 合并成一张截面，所以 `lenth9` / `lenth9_clean` / `lenth9_domin` 都没有年份。本项目需要年度面板，因此在该 collapse 及后续所有 groupby 里都带上 `year`。

### 两处**刻意不做**的 io_repro 步骤

| io_repro 步骤 | 本 pipeline | 原因 |
|---|---|---|
| `lenth9_clean`：对角线对冲（同企业同产品买卖轧差） | **不做** | 外包的定义就是"同企业同产品既买又卖"，对冲会把要研究的信息抹掉 |
| `lenth9_domin`：主导产品处理（占比 >0.99 砍零头） | **不做** | IO 表估系数专用的调整，与本项目无关 |

## 数据流

```
Data/  buyer_17_collapsed / buyer_18_collapsed / seller_17_collapsed / seller_18_collapsed
       bianma_all.dta (19 位编码表)
 │ [01_cleaning.do]  改列名 + 加 year + input_output → append → v = 正+负
 │                   → 产品码补 19 位 + 数值过滤 → 并编码表
 │                   → collapse by(firm product io **year**) → drop v<=0
 │                   → 截 15 位 + is_output + 只留有产出企业
 ▼ lenth15_year.dta
 │ [Step1] 15→9 位码标准化（层级码处理）+ firm 交集
 ▼ lenth9_year.dta
 │ [Step2] firm×product×year 聚合；外包额 = min(投入, 产出)
 ▼ firm_product_year_level.dta            (7 列)
 │ [Step3] 产品级特征聚合
 ▼ product_characteristics.dta            (11 列)
 │ [Step4] firm×year 汇总：外包强度、中介/外包标记
 │ [Step5] 主产品 = production_value 最大
 │ [Step6] 合并 similarity + 产品特征（_p 后缀）
 ▼ full_data.dta                          (30 列)
 │ [Step7] 与现有 full_data 对比验证
 │ [Step8] 描述统计
```

## 关键口径

| 概念 | 定义 |
|---|---|
| 外包产品 | 同一企业同一年对同一产品既买(投入)又卖(产出) |
| 外包额 | `min(投入额, 产出额)`，逐 firm×product×year |
| 自产额 | `production_value = 产出额 − 外包额` |
| 外包强度 | `Σ外包额 / Σ产出额`（firm×year） |
| 中介 | 强度 > 0.90 |
| 外包企业 | 强度 ≥ 0.01 |
| **主产品** | firm×year 内 **`production_value` 最大**（并列取 `product_id` 最小） |

> 旧 `full_data.dta` 主产品用 `total_output` 最大。本 pipeline 已按现行定义改为 `production_value`，受影响列：`is_main` / `main_product` / `main_product_production` / `production_relative_main` / `input_similarity` / `output_similarity`。Step 7 的验证会把这几列单独标注。

### 相对规模指标：为什么改成 production / production

旧版 `sales_relative_main = 副产品 total_output / 主产品 total_output`。主产品既然按 `total_output` 取最大，分母就是该 firm-year 的最大销量，比值**数学上恒 ≤ 1**。

主产品改按 `production_value` 选之后，分母变成"自产最多那个产品的销量"，跟最大值脱钩了。转售型企业尤其危险——主要靠外包转售赚钱时，自产最多的可能是个只卖几百块的小产品，分母趋近 0，比值爆炸（实测均值从 0.20 涨到 180 万）。

要恢复有界性，分子分母必须和"主产品按什么选"同口径。因为主产品 = `argmax production_value`，只有：

```
production_relative_main = 副产品 production_value / 主产品 production_value    # 恒 ≤ 1
```

两列因此改名：`main_product_output` → `main_product_production`，`sales_relative_main` → `production_relative_main`，名实相符。

> 旧名在 `main_os/intensive_margin_analysis.do` 里有 20+ 处引用（那半边"相对销量"回归产出 12 个 `S*_D/E/F_Sales.txt`），但**论文一处都没引用**，所以改名不影响任何已发表数字。若要启用那条线，把变量名同步过去即可。

## 参考口径的历史数字（旧版 full_data）

lenth9 465,487,031 行 / 2,778 产品 / 7,191,877 企业；`firm_product_year_level` 90,296,650 行 / 12,339,537 firm-year；中介占比 6.24%；去中介后 87,432,386 行。

新 pipeline 因为保留了 year，行数会与上述**不同**（旧口径把两年合并去重了），以实际跑出的为准。

## 输出的 30 列

**20 列基础**：year, firm_id, product_id, total_output, outsourcing_value, production_value, outsourcing_percen, sales_percen, production_relative_main, is_main, main_product, main_product_production, input_similarity, output_similarity, firm_total_output, firm_total_outsource, n_products, outsourcing_intensity, is_intermediary, is_outsourcing

**10 列产品级特征**：total_output_p, total_outsourcing_p, total_production_p, num_years, num_firms, num_firms_outsourcing, outsourcing_intensity_p, avg_output_per_firm, avg_output_per_year, pct_firms_outsourcing
