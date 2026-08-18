# Empirical1 — 第一阶段实证：数据构建 pipeline

## 目录结构

```
pipeline/     ★ 要跑的代码（当前口径）
  00_data_pipeline.ipynb    原始交易 → full_data.dta (30 列) + 描述统计 + 验证
  database.do               Step 1 的 Stata 脚本（超大文件 collapse）

replicate/    忠实复现版（旧口径，存档备查）
  replicate_all.ipynb       §0a–§6，代码直接抄自原 notebook
  database.do
  PIPELINE_DOC.md           逐节文档
  README.md

reference/    参考用（VM 原件，不跑）
  to_nine.ipynb / product_character.ipynb / product_level.ipynb
  outsourcing_analysis.ipynb / descriptive_analysis.ipynb
  coverage.ipynb / sample.ipynb / Outsource.ipynb
  build_product_characteristics.ipynb / database_old.do
```

## 跑哪个

**跑 `pipeline/00_data_pipeline.ipynb`**——它产出当前口径的 30 列 `full_data.dta`，并自带与现有文件的对比验证。

`replicate/` 是旧口径的忠实复现（主产品 = total_output 最大、外包强度两套口径并存），保留用于追溯历史结果。

## 口径（pipeline 版统一采用）

| 概念 | 定义 |
|---|---|
| 外包产品 | 同一企业同一年对同一产品既买(投入)又卖(产出) |
| 外包额 | `min(投入额, 产出额)`，逐 firm×product×year |
| 自产额 | `production_value = 产出额 − 外包额` |
| 外包强度 | `Σ外包额 / Σ产出额`（firm×year） |
| 中介 | 强度 > 0.90 |
| 外包企业 | 强度 ≥ 0.01 |
| **主产品** | firm×year 内 **`production_value` 最大**（并列取 `product_id` 最小） |

> 旧版 `full_data.dta` 主产品用 `total_output` 最大。pipeline 版已改为 `production_value`，受影响列：`is_main` / `main_product` / `main_product_output` / `sales_relative_main` / `input_similarity` / `output_similarity`。

## 路径约定：代码与数据分离

| | 变量 | 位置 | 进 git？ |
|---|---|---|---|
| **代码**（ipynb / do） | `CODE` | `<BASE>/Empirical1/` | ✅ 是 |
| **数据**（全部 .dta） | `DATA` | `<BASE>/Empirical1_data/` | ❌ 否（文件太大）|
| 原始交易数据 | `RAW` | `G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta` | ❌ 否 |

`<BASE>` 在 notebook 顶部切换：

```python
BASE = Path(r'G:\Kuangyu_Temp\Outsource')                          # VM
# BASE = Path(r'C:\Users\HKUBS\Documents\aproject\Outsourcing')    # 本地
```

**约定**：所有 `.dta` 一律放 `Empirical1_data/`，所有代码一律放 `Empirical1/`。仓库里没有 `.gitignore`——靠这条约定自觉遵守，不要把 dta 加进 git。

`Empirical1_data/` 里应有的输入文件：`full_product_similarity.dta`、`full_data.dta`（现有底表，供验证对比）、`bianma.dta`。

## 数据链条与预期数字

```
1718_total_cleaned_by_year1.dta
  → [Step1  Stata]  lenth15.dta
  → [Step2]         lenth9      465,487,031 行 / 2,778 产品 / 7,191,877 企业
  → [Step3]         firm_product_year_level.dta   90,296,650 行 / 12,339,537 firm-year
  → [Step3b]        product_characteristics.dta   2,778 × 11
  → [Step4–6]       full_data.dta                 90,296,650 × 30
```

其他预期数字：中介占比 ≈ 6.24%；去中介后 87,432,386 行；主产品 11,569,923 / 次要 75,862,463。

## 输出的 30 列

**20 列基础**：year, firm_id, product_id, total_output, outsourcing_value, production_value, outsourcing_percen, sales_percen, sales_relative_main, is_main, main_product, main_product_output, input_similarity, output_similarity, firm_total_output, firm_total_outsource, n_products, outsourcing_intensity, is_intermediary, is_outsourcing

**10 列产品级特征**：total_output_p, total_outsourcing_p, total_production_p, num_years, num_firms, num_firms_outsourcing, outsourcing_intensity_p, avg_output_per_firm, avg_output_per_year, pct_firms_outsourcing
