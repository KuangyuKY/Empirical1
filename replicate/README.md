# replicate — 一键复现第一阶段当前结果

`replicate_all.ipynb` 的代码**直接抽取自你原始的 notebook 单元**(未重写),按依赖顺序拼成一个可从上到下运行的复现流程。只做了三处最小改动:
1. 修 `outsourcing_analysis` 里 `to_stata(..., index=False)` 的参数 bug → `write_index=False`;
2. glue:把 `firm_aggregate_table` 另存为 `summary.dta`(`descriptive_analysis`/`sample` 读的就是它);从 lenth9 切出 `lenth9_18.dta`;
3. **改路径**——代码与数据分离(见下)。

## 路径约定(代码 git 共享,数据只在 VM)

| | 变量 | 位置 |
|---|---|---|
| **代码** | `CODE` | `G:\Kuangyu_Temp\Outsource\Empirical1\` — git 同步,本地/VM 两边共享 |
| **生成数据** | `DATA` | `G:\Kuangyu_Temp\Outsource\replicate\` — 全部产出,只在 VM,**不进 git** |
| **已有输入** | `SRC` | `G:\Kuangyu_Temp\Outsource\` — `full_product_similarity.dta`、`io_table_lite.dta` |
| **原始数据** | `RAW` | `G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta` |

每段开头 `os.chdir(DATA)`,所有相对读写都落在 `DATA`;只有 `SRC`/`RAW` 用绝对路径。
> 注意:代码里的 `Empirical1\replicate\`(本文件夹)放**代码**;VM 上的 `Outsource\replicate\` 放**数据**。同名但不同用途。

## 起点与顺序
从**最原始文件**开始。超大原始文件的 collapse 交给 **Stata**(`database.do`,由 notebook 调 VM 的 StataMP-64),9 位码及之后在 Python 里跑。

| 段 | 源 | 读入 | 产出 |
|---|---|---|---|
| §0a | database.do (Stata) | RAW | lenth15.dta |
| §0b | to_nine | lenth15.dta | lenth9.dta, lenth9_18.dta |
| §1–§2 | product_character | lenth9, similarity(SRC) | firm_product_year_level, product_characteristics, **full_data**, firm_year_summary |
| §3 | outsourcing_analysis | lenth9 | firm_aggregate_table → **summary.dta** |
| §4 | descriptive_analysis | summary.dta | 描述统计 + 图 |
| §5 | coverage | full_data, similarity(SRC) | diagnostics/coverage_summary.csv + 图 |
| §6 | sample | summary.dta, lenth9_18, io_table_lite(SRC) | similarity.dta(企业级余弦) |

## 注意
- **口径(照现有代码保留)**:§2 full_data 主产品用 **total_output** 最大;§5 coverage 里重算为 **production_value** 最大;§3 外包强度用**投入侧**口径(旧,中介≈12.46%),与 §2 的 min 口径不同。这是你当前代码本来就并存的,忠实保留,未统一。
- **内存**:§1 与 §3 各读一次 ~4.65 亿行的 lenth9,建议 VM 大内存运行。
- **big data 走 Stata**:仅最原始文件的 collapse 在 Stata;`to_nine` 之后沿用你原来的 pandas 代码。若某步 Python 内存扛不住,告诉我再改 `.do`。
- **前置输入**:`SRC` 下需有 `full_product_similarity.dta` 与 `io_table_lite.dta`。

## 相关文件
- `replicate_all.ipynb` — 一键复现,每段带命名 md 标题。
- `PIPELINE_DOC.md` — 逐步文档,小节标题与 notebook 的 md 标题**逐字一致**。
- `database.do` — §0a 的 Stata 脚本(RAW → lenth15,输出到 `DATA`)。
- `..\00_data_pipeline.ipynb` — **改进版**(min 口径 + production_value 主产品),同样已改为调 Stata + 新路径。此处 `replicate_all.ipynb` 是**忠实复现版**。
