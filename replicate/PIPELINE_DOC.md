# 复现流程操作文档 —— 对应 `replicate_all.ipynb`

本文档与 `replicate_all.ipynb` **按 markdown 小节一一对应**：notebook 里每个 `## §…` 标题，在本文档里都有**同名**的一节，记录"读入什么 / 做了什么 / 产出什么 / 关键定义 / 预期数字"。

> **维护约定**：改代码时，同步改本文档同名小节；小节标题必须与 notebook 里的 `## §…` 标题**逐字一致**（人工审核时靠标题对齐，不用格号）。"预期数字"来自历史运行，换样本/换口径后需更新。

## 路径约定（代码 git 共享，数据只在 VM）

| | 变量 | 位置 | 说明 |
|---|---|---|---|
| **代码** | `CODE` | `G:\Kuangyu_Temp\Outsource\Empirical1\` | git 同步，本地/VM 两边共享 |
| **生成数据** | `DATA` | `G:\Kuangyu_Temp\Outsource\replicate\` | 本流程产出的**全部**数据，只在 VM，**不进 git** |
| **已有输入** | `SRC` | `G:\Kuangyu_Temp\Outsource\` | `full_product_similarity.dta`、`io_table_lite.dta`（保持原位） |
| **原始数据** | `RAW` | `G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta` | 最原始交易数据 |

每段开头都 `os.chdir(DATA)`，所以**所有相对读写都落在 `DATA`**；只有 `SRC` / `RAW` 用绝对路径。`%reset -f` 的格子会在 reset 之后**重新注入** `DATA`/`SRC` 定义。

**总链条**：
```
1718_total_cleaned_by_year1.dta
  §0a database.do (Stata)  → lenth15.dta
  §0b to_nine (Python)     → lenth9.dta
  §1  product_character    → firm_product_year_level.dta, product_characteristics.dta
  §2  product_character    → full_data.dta, firm_year_summary.dta
  §3  outsourcing_analysis → firm_aggregate_table.dta → summary.dta
  §4  descriptive_analysis → 描述统计 + 图
  §5  coverage             → coverage_summary.csv + 相似度分布图
  §6  sample               → similarity.dta（企业级余弦）
```

**两套口径并存（忠实保留你现有代码，未统一）**：
- §2 `full_data` 的**主产品 = total_output 最大**；外包额 = `min(投入,产出)`（min 口径）。
- §5 `coverage` 里**主产品重算为 production_value 最大**（与 §2 不同）。
- §3 `firm_aggregate_table` 的**外包强度 = 投入侧份额**（旧口径，中介≈12.46%），与 §2 的 min 口径不同。

---

## §0a　database.do（Stata）：原始交易 → lenth15

- **输入**：`G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta`（最原始、已按年清洗的交易数据；极大，pandas/VS Code 打不开）。
- **调用**：notebook 用 `subprocess.run([stata_exe, "/e", "do", DO_DATABASE])` 调 `StataMP-64.exe` 跑 `database.do`。
- **操作**（`database.do` 内）：
  1. `collapse (sum) v, by(firm_id product_id input_output year)` —— 聚合到 firm×product×投入产出×年（精确求和，红冲负值自动对冲）。
  2. `drop if v <= 0`。存中间件 `1718_total_cleaned1.dta`。
  3. `product_id = substr(product_id, 1, 15)` —— 截前 15 位。
  4. `is_output = (input_output=="output")`；`egen num_outputs = total(is_output)`，`drop if num_outputs < 1` —— 只保留**至少有一条产出记录**的企业。
  5. `keep firm_id year product_id v is_output` → 存 **`lenth15.dta`**。
- **产出**：`lenth15.dta`（列：firm_id, year, product_id[15位], v, is_output）。
- **备注**：大文件放 Stata——VM 能开、collapse 精确、无 pandas 分块问题。返回码 0 且生成 lenth15 才能继续。

## §0b　to_nine：15 位码 → 9 位码（→ lenth9）

代码来自你原 `to_nine.ipynb`（未改；两格：环境导入 + 主逻辑）。

- **输入**：`lenth15.dta`。
- **操作**：
  1. 按 `is_output` 分产出/投入；各取 `product_id[:9]`。
  2. 剔除**高层聚合码**（1 位或 3 位后全 0，太粗）。
  3. 判断真实细分层级：某 7 位前缀只对应一个 9 位码 → 该产品最多到 7 位；5 位同理。
  4. **合法 9 位码集合** = 真 9 位码（不以 `00` 结尾）+ 7 位层级码（补 `00`）。
  5. 用该集合过滤，并在 9 位层级**重新聚合求和**。
  6. `firms = 产出侧 ∩ 投入侧`，只留既产出又投入的企业。
  7. `concat(投入, 产出)` → 存 **`lenth9.dta`**。
  8. **glue**：从内存里的 lenth9 切出 2018 子集 → 存 **`lenth9_18.dta`**（供 §6 用；原代码读的是预先存在的文件，这里改为自动生成，保证与本次重建的 lenth9 一致）。
- **产出**：`lenth9.dta`（列：firm_id, product_id[9位], is_output, year, v）、`lenth9_18.dta`。
- **预期数字**：产品 4058 → **2778**；企业 **7,191,877**；行数 **465,487,031**。
- **备注**：读 lenth15（约 4.65 亿行）用 pandas——你原来在 VM 上跑通的代码。内存扛不住需改 Stata。

## §1　product_character：firm_product_year_level + product_characteristics

代码来自你原 `product_character.ipynb`（未改）。

- **输入**：`lenth9.dta`。
- **操作**：
  1. 读 lenth9，drop 缺失、drop `v<0`。
  2. 产出侧按 (year, firm, product) 求和 = `total_output`；投入侧 = `total_input`；以产出为主 left-merge，`total_input` 缺失填 0。
  3. **`outsourcing_value = min(total_input, total_output)`**；`production_value = total_output − outsourcing_value`；`outsourcing_percen = outsourcing_value/total_output`。
  4. 存 **`firm_product_year_level.dta`**（+ .csv）。
  5. 按 product_id 汇总产品特征（num_firms 跨年去重、total_output、outsourcing_intensity 等）→ 存 **`product_characteristics.dta`**。
- **产出**：`firm_product_year_level.dta`、`product_characteristics.dta`。
- **预期数字**：firm_product_year_level **90,296,650** 行；firm-year **12,339,537**；产品特征 **2,778** 个；产品级 outsourcing_intensity 均值≈**0.151**。
- **注意**：以**产出侧为基**（只留有产出记录的 firm-year），故 firm-year 是 12.34M，而非 §3 全交易口径的 13.09M。

## §2　product_character：full_data + firm_year_summary

代码来自你原 `product_character.ipynb`（未改）。

- **输入**：`firm_product_year_level.dta`、`full_product_similarity.dta`。
- **操作**：
  1. **企业层汇总**：firm_total_output、firm_total_outsource（=Σ outsourcing_value）、n_products；`outsourcing_intensity`；`is_intermediary`=强度>0.90；`is_outsourcing`=强度≥0.01 → 存 `firm_year_summary.dta`。
  2. **主产品**：firm-year 内按 `total_output` 降序（并列 product_id 升序）取第一 = `main_product`（★ 口径 = **总产出最大**）；`is_main`。
  3. `sales_percen`、`sales_relative_main`。
  4. **合并 similarity**（对称化后按 (product_id, main_product) 合并）；主产品自身相似度设 1。
  5. 整理列 → 存 **`full_data.dta`**（20 列）。
- **产出**：`full_data.dta`、`firm_year_summary.dta`。
- **预期数字**：full_data **90,296,650** 行；中介占比（firm-year，min 口径）≈**6.24%**。
- **口径提醒**：主产品此处用 **total_output**；§5 会自己重算为 **production_value**——两处不一致是你现有代码现状，忠实保留。

## §3　outsourcing_analysis：firm_aggregate_table → summary.dta

代码来自你原 `outsourcing_analysis.ipynb`（**仅修** `to_stata(index=False)`→`write_index=False`）+ 一格 glue。

- **输入**：`lenth9.dta`（全量、两侧、两年）。
- **操作**：
  1. 读 lenth9；按 (firm, product, year) 判断"既买又卖" → 外包产品标记。
  2. 企业层汇总 `firm_agg`：total_output、total_input、外包品的 outsourcing_output/input、n_products、n_outsourcing_products、main_product（销售额最大）等。
  3. **`outsourcing_intensity = outsourcing_output/total_output`**（★ **投入侧口径**）；`is_intermediary`=强度>0.90。存 `firm_aggregate_table.dta`。
  4. **glue**：`firm_agg.to_stata('summary.dta')` —— §4/§6 读的是 `summary.dta`，靠列名判断它与 firm_aggregate_table 一致，故另存一份。
- **产出**：`firm_aggregate_table.dta`、`summary.dta`。
- **预期数字**：firm-year **13,094,906**；有外包 **7,716,925**；中介 **12.46%**（1,631,747）。
- **⚠️ 已知问题（保留原样）**：原代码里 `outsourcing_output` 与 `outsourcing_input` **都取自投入表**（复制粘贴），故强度是投入侧口径、可>1、中介偏多。§2 的 min 口径才是修正版。是否统一由你定。

## §4　descriptive_analysis：外包普遍率 / 强度 / 相关性

代码来自你原 `descriptive_analysis.ipynb`（未改）。

- **输入**：`summary.dta`（= §3 的 firm_aggregate_table）。
- **操作**：
  1. **普遍率**：按年统计 `outsourcing_intensity>0` 占比 → `outsourcing_prevalence.dta`。
  2. **强度分布**（剔除中介）：直方图 → `outsourcing_intensity_distribution.png`；分位数 → `outsourcing_intensity_percentiles.csv`。
  3. **相关性**：3b 外包销售额 vs 主产品销售额；3d 投入侧 vs 产出侧外包份额 → 两张散点图。
  4. **汇总统计表**（剔除中介）→ `summary_statistics.dta`。
- **产出**：上述 .dta / .csv / .png。
- **备注**：Fact#1（真实生产 vs 销售）在原代码里是伪代码、未运行，本节不产出该图。

## §5　coverage：选择集覆盖 + 相似度分布

代码来自你原 `coverage.ipynb`（未改）。

- **输入**：`full_data.dta`、`full_product_similarity.dta`。
- **操作**：
  1. 读 full_data，**drop 中介**。
  2. **主产品 = 每 firm×year 内 `production_value` 最大**（★ 与 §2 的 total_output 不同，这里重算）。分主产品 / 次要产品。
  3. similarity 对称化后合并到次要产品。
  4. **选择集**：每个主产品取 input top-N ∪ output top-N（N=30/50/100）；算产品数覆盖率与销售额覆盖率 → `diagnostics/coverage_summary.csv`。
  5. 画相似度分布图、按相似度分箱的覆盖率图。
- **产出**：`diagnostics/coverage_summary.csv` + 一批 .png。
- **预期数字**：full_data 90,296,650 → 去中介 **87,432,386**；主产品 **11,569,923**、次要 **75,862,463**；**top30 覆盖 24.4% 产品数 / 58.0% 销售额**；top50 30.9%/65.8%；top100 41.7%/74.8%；similarity 匹配 100%。

## §6　sample：企业级余弦相似度 → similarity.dta

代码来自你原 `sample.ipynb`（未改，5 格）。

- **输入**：`summary.dta`（取 2018、非中介、外包强度>0）、`lenth9_18.dta`（2018 子集）、`io_table_lite.dta`（投入系数）。
- **操作**：
  1. 从 summary.dta 筛 `is_intermediary==0 & outsourcing_intensity>0`，**随机抽 5 万家**（`random_state=42`）。
  2. 用 lenth9_18 分出每个产品的买/卖，`outsource = min(buy,sell)`、`own = sell − outsource`。
  3. 每家企业：用 io_table 把**外包产品**与**自产产品**分别加权成投入向量，统一维度算**余弦相似度**。
  4. 存 **`similarity.dta`**（firm_id, cosine_similarity）。
- **产出**：`similarity.dta`。
- **含义**：企业"外包的东西 vs 自产的东西"在投入结构上的相似度——企业层 make-vs-buy 分离度。
- **依赖**：`lenth9_18.dta` 由 §0b 自动生成（在 `DATA`）；`io_table_lite.dta` 需预先存在于 `SRC`。

---

## 附：需要按 VM 调整的路径 / 参数

| 位置 | 变量 | 当前值 |
|---|---|---|
| §0a | `stata_exe` | `C:/Program Files/Stata17/StataMP-64.exe` |
| §0a | `CODE` | `G:\Kuangyu_Temp\Outsource\Empirical1`（`DO_DATABASE = CODE/replicate/database.do` 自动拼）|
| 各节 | `DATA` | `G:\Kuangyu_Temp\Outsource\replicate`（全部生成数据）|
| 各节 | `SRC` | `G:\Kuangyu_Temp\Outsource`（similarity / io_table 等输入）|
| `database.do` 内 | 原始文件 / 输出目录 | `G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta` → `cd G:\Kuangyu_Temp\Outsource\replicate` |

## 附：待办 / 后续更新点

- [ ] 是否**统一外包强度口径**（§3 投入侧 → min）；若统一，§3/§4 的中介占比与描述统计需重跑并更新本文档"预期数字"。
- [ ] 是否**统一主产品口径**（§2 total_output vs §5 production_value）。
- [ ] 若 `to_nine` / §1 / §3 的 pandas 读 lenth 内存扛不住 → 改写为 Stata `.do`，并在此新增同名小节。
- [ ] 扩样/换年份后，所有"预期数字"需更新。
