# Empirical1 — 第一阶段实证：数据构建 pipeline

## 目录结构

```
pipeline/     ★ 要跑的代码
  01_cleaning.do              4 张 collapsed 年度表 → lenth15_year.dta（Stata）
  02_build_full_data.ipynb    lenth15_year → full_data.dta (30 列) + 描述统计
  03_compare_full_data.ipynb  新旧 full_data 对比 → diagnostics/

diagnostics/  ★ 检测性输出（进 git，两边同步分析）
replicate/    旧口径忠实复现，存档备查
reference/    VM 原件与已被取代的版本，参考不跑
```

## 跑的顺序

1. **`pipeline/01_cleaning.do`**（Stata）——超大文件的 append / 产品码清洗 / collapse
2. **`pipeline/02_build_full_data.ipynb`**（Python）——Step 0 那格也可以直接调用 do 文件，跑过就跳过
3. **`pipeline/03_compare_full_data.ipynb`**（Python）——02 跑完后再跑，输出新旧对比报告

## 输出去向的两条规则

| 类型 | 去向 | 进 git？ |
|---|---|---|
| **数据**（`.dta`） | `Empirical1_data/` | ❌ |
| **检测 / 诊断结果**（对比报告、核对表、log 摘要） | `Empirical1/diagnostics/` | ✅ |

诊断结果进 git 是为了 VM 上跑完能同步到本地一起看。

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

> 旧 `full_data.dta` 主产品用 `total_output` 最大。本 pipeline 已按现行定义改为 `production_value`，受影响列：`is_main` / `main_product` / `main_product_output` / `sales_relative_main` / `input_similarity` / `output_similarity`。Step 7 的验证会把这几列单独标注。

## 参考口径的历史数字（旧版 full_data）

lenth9 465,487,031 行 / 2,778 产品 / 7,191,877 企业；`firm_product_year_level` 90,296,650 行 / 12,339,537 firm-year；中介占比 6.24%；去中介后 87,432,386 行。

新 pipeline 因为保留了 year，行数会与上述**不同**（旧口径把两年合并去重了），以实际跑出的为准。

## 输出的 30 列

**20 列基础**：year, firm_id, product_id, total_output, outsourcing_value, production_value, outsourcing_percen, sales_percen, sales_relative_main, is_main, main_product, main_product_output, input_similarity, output_similarity, firm_total_output, firm_total_outsource, n_products, outsourcing_intensity, is_intermediary, is_outsourcing

**10 列产品级特征**：total_output_p, total_outsourcing_p, total_production_p, num_years, num_firms, num_firms_outsourcing, outsourcing_intensity_p, avg_output_per_firm, avg_output_per_year, pct_firms_outsourcing
