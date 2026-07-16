# replicate — 一键复现第一阶段当前结果

`replicate_all.ipynb` 的代码**直接抽取自你原始的 notebook 单元**（未重写），按依赖顺序拼成一个可从上到下运行的复现流程。只做了两处最小改动:
1. 修 `outsourcing_analysis` 里 `to_stata(..., index=False)` 的参数 bug → `write_index=False`;
2. 加一格 glue,把 `firm_aggregate_table` 另存为 `summary.dta`(`descriptive_analysis`/`sample` 读取的就是它)。

## 起点与顺序
从**最原始文件** `1718_total_cleaned_by_year1.dta` 开始。超大原始文件的 collapse 交给 **Stata**(`database.do`,由 notebook 调用 VM 的 StataMP-64),9 位码及之后在 Python 里跑。

| 段 | 源 | 读入 | 产出 |
|---|---|---|---|
| §0a | database.do (Stata) | 1718_total_cleaned_by_year1.dta | lenth15.dta |
| §0b | to_nine | lenth15.dta | lenth9.dta |
| §1–§2 | product_character | lenth9.dta, full_product_similarity.dta | firm_product_year_level.dta, product_characteristics.dta, **full_data.dta**, firm_year_summary.dta |
| §3 | outsourcing_analysis | lenth9.dta | firm_aggregate_table.dta → **summary.dta** |
| §4 | descriptive_analysis | summary.dta | 描述统计 + 图 |
| §5 | coverage | full_data.dta, similarity | coverage_summary.csv + 相似度分布图 |
| §6 | sample | summary.dta, lenth9_18.dta, io_table_lite.dta | similarity.dta(企业级余弦) |

## 注意
- **口径(照现有代码保留)**:§2 的 full_data 主产品用 **total_output** 最大;§3 外包强度用**投入侧**口径(旧,中介≈12.46%),与 §2 的 min 口径不同——这是你当前代码本来就并存的两套,忠实保留,未统一。
- **内存**:§1 与 §3 各读一次 ~4.65 亿行的 lenth9,建议 VM 大内存运行。
- **依赖文件**:§6 需要 `lenth9_18.dta`(2018 子集)与 `io_table_lite.dta`。
- **工作目录 / Stata**:§0a 用 `StataMP-64.exe /e do database.do`;请把 notebook 里的 `DO_DATABASE` 与 README 中 `database.do` 的路径改成 VM 上的实际路径。各段沿用原代码的 chdir(部分产出落在 `...\Outsource\description\`)。
- **big data 走 Stata**:仅最原始文件的 collapse 在 Stata;`to_nine` 之后(读 lenth15/lenth9,约 4.65 亿行)沿用你原来的 pandas 代码(VM 大内存可跑)。若某步 Python 内存扛不住,告诉我,再把它也改成 `.do`。

## 相关文件
- `database.do` —— §0a 调用的 Stata 脚本(原始 → lenth15)。
- `Empirical1\00_data_pipeline.ipynb` —— **改进版**(min 口径 + production_value 主产品),同样已改为 Step1 调 Stata。此处 `replicate_all.ipynb` 是**忠实复现版**。
