# pipeline/ 进度说明

**更新 2026-09-13。** 逐个文件说明：做什么、跑到哪、卡在哪。
目录整体说明见 `../README.md`；项目背景见 `../../HANDOFF 1.md`。

---

## 一张表看完

| 文件 | 规模 | 干什么 | 跑过没 | 产出在 |
|---|---|---|---|---|
| `01_cleaning.do` | 99 行 | 4 张年度表 → `lenth15_year.dta` | ✅ **VM 跑通** | `Empirical1_data/` |
| `02_build_full_data.ipynb` | 22 cell | → `full_data.dta`（30 列） | ✅ **VM 跑通** | `Empirical1_data/` |
| `03_choice_set.do` | 285 行 | choice set + 覆盖率诊断 | ✅ **VM 跑通，数字与报告吻合** | `results/choice_set/` |
| `04_entry.do` | 638 行 | Sample A/B/C 的 5 张回归表 | ⬜ **修了注释 bug + merge bug，待重跑** | `results/entry/` |
| `figure.ipynb` | 26 cell | 第一部分全部作图 | 🟡 **本地验证通过，VM 未跑** | `results/figures/` |
| `patch_relative_main.ipynb` | 8 cell | 一次性补丁 | 🟡 **Step 1 成功 / Step 2 OOM** | `Empirical1_data/` |
| `patch_relative_main.do` | 47 行 | 同上，Stata 版 Step 2 | ⬜ 未跑（可选） | — |

编号只给主流程；补丁和作图不占编号。

> **★ 2026-09-10 范围调整**：全样本横截面回归**砍掉**（论文 §3.3–3.4）。
> 原 `03_extensive.do` 已移到 `reference/03_extensive_fullsample.do` 存档。
> 理由与影响见下面「03_choice_set.do」一节。

---

## 01_cleaning.do　✅ 已跑通

**做什么**：4 张 collapsed 年度表 append → 产品码补 19 位 → 并编码表 → collapse 到
`firm × product × input_output × year` → 截 15 位 → 只留有产出的企业。

**输入**（`$DATA = G:\Kuangyu_Temp\Data`，只读）
`buyer-yearly-{17,18}-collapsed.dta`、`seller-yearly-{17,18}-collapsed.dta`、`bianma_all.dta`

**输出**（`$OUT = G:\Kuangyu_Temp\Outsource\Empirical1_data`）
`lenth15_year.dta` —— 列：`firm_id year product_id`(15位) `v is_output`

**逻辑出处**：照搬 `IO_Table/io_repro/02_cleaning_pipeline.do`，**唯一区别是全程保留 `year`**。
IO 表那条线在原文件第 120 行 `collapse (sum) v, by(firm_id product_id input_output)` 把两年合并成一张截面，
所以 `lenth9` / `lenth9_clean` / `lenth9_domin` 都没有年份。本项目要年度面板，因此该 collapse 及后续所有 groupby 都带 `year`。

**刻意不做的两步**

| io_repro 步骤 | 本 pipeline | 原因 |
|---|---|---|
| `lenth9_clean` 对角线对冲（同企业同产品买卖轧差）| **不做** | 外包的定义就是"同企业同产品既买又卖"，对冲会把要研究的信息抹掉 |
| `lenth9_domin` 主导产品处理（占比 >0.99 砍零头）| **不做** | IO 表估系数专用，与本项目无关 |

---

## 02_build_full_data.ipynb　✅ 已跑通

**做什么**：`lenth15_year` → 9 位码标准化 → firm×product×year 聚合 → 产品级特征 → `full_data.dta`

**Step 0** 那格可以直接调 `01_cleaning.do`；跑过就跳过。

```
lenth15_year.dta
 │ [Step1] 15→9 位码标准化（层级码处理）+ firm 交集
 ▼ lenth9_year.dta
 │ [Step2] firm×product×year 聚合；外包额 = min(投入, 产出)
 ▼ firm_product_year_level.dta        (7 列)
 │ [Step3] 产品级特征聚合
 ▼ product_characteristics.dta        (11 列)
 │ [Step4] firm×year 汇总：外包强度、中介/外包标记
 │ [Step5] 核心产品 = production_value 最大（并列取 product_id 最小）
 │ [Step6] 合并 similarity + 产品特征（_p 后缀）
 ▼ full_data.dta                      (30 列)
 │ [Step7] 与旧 full_data 对比验证
 │ [Step8] 描述统计
```

**实际产出**

| | 值 |
|---|---|
| 行数 | 90,297,401 |
| firm-year | 12,339,578 |
| 企业数 | 7,191,900 |
| 列数 | 30 |
| 体积 | 18.60 GB |

**与旧 full_data 的差异**（`../diagnostics/full_data_comparison.md`）
行数 +751、企业 +23、`outsourcing_value` 总和**完全相同**、S 均值 +0.23%、C 均值 −1.47%。
+751 行判定为数据源头带来的，可接受。

**⚠️ 一个已知缺口**：`full_data.dta` 里那两列还是旧名旧口径 —— `main_product_output`、`sales_relative_main`。
原因见下面的补丁说明。**不影响任何已计划的回归和作图**（03 和 figure 都不读这两列）。

---

## 03_choice_set.do　✅ VM 跑通

**做什么**：每个核心产品取 input top30 ∪ demand-complementarity top30 作候选集，
其余 ~2,720 个产品压成一行 OTHER（相似度取均值）。
**全部在产品对层面算完，不按企业展开**——展开是 04 的事。

```
PART 1  双向 similarity            → sim_bi.dta（04 的 Sample C 要用）
PART 2  choice set top30 并集      → choice_set.dta + choice_set_other.dta
PART 3  覆盖率诊断 top30/50/100    → results/choice_set/coverage.txt
```

### 实跑结果（2026-09-12）

**与 `Empirical_Report.md` §3.1 逐个吻合**——重建流程的一次强验证：

| Top-N | 平均候选数 | 数量覆盖率 | 销售额覆盖率 | 报告 |
|---|---|---|---|---|
| 30 | 53.94 | 24.40% | 57.98% | 24.4% / 58.0% ✓ |
| 50 | 88.85 | 30.95% | 65.75% | 30.9% / 65.8% ✓ |
| 100 | 174.27 | 41.73% | 74.84% | 41.7% / 74.8% ✓ |

| | 值 |
|---|---|
| 双向 similarity | 7,714,506 = 3,857,253 × 2 ✓ |
| 候选对 | 148,584（仅 input 74,180 / 仅 output 74,404 / 重叠 18,096）|
| OTHER 行 | 2,778，每个核心产品一行 ✓ |
| 实际副产品 | 75,863,157 行，销售额 102.36 万亿（报告 75.9M / 102.4T ✓）|

**顺带解决报告里一个悬案**：正文写平均候选数 53.9、覆盖率表写 53.5——**两个都对，是两种平均**。
53.49 = 148,584 ÷ 2,778，按核心产品取均值；53.94 按行取均值（候选集大的产品权重更高），代码里 `summarize nc` 算的是后者。

### ★ 为什么换掉 03_extensive.do

原 `03_extensive.do` 把每个 firm-year 配上 ~54 个候选后跑全样本 LPM/PPML：

| | 观测数 | joinby 峰值 |
|---|---|---|
| 全样本横截面（**已砍**）| 625,619,601 | 约 5.5 亿行，25–30 GB ← VM 跑不出来 |
| Sample A（保留，见 04）| 74,943,790 | 少 88% |

砍掉的理由是**数量太大、边际意义不足**；回归改到 04 的 Sample A/B/C 上做。
副作用是**内存那个坎自动消失**——原文件在 VM 上跑不出结果，最可能就是死在那个 joinby。

**choice set 本身仍然要做**，因为两样东西需要它：
1. **04 的 Sample A/B 回归**——每个企业要配上候选才能跑 `d_entry`
2. **覆盖率表**（论文 §3.1）

**那两张进论文的图不需要 choice set。** `fig2_lift_*`（选择概率上升）和 `sim_vs_rank_*`（相似度随排名下降）
在 `figure.ipynb` 里都是直接从产品对层面算的，不受这次调整影响。

原文件已移到 `reference/03_extensive_fullsample.do` 存档。

### 相对 `diversification_complete.do` 的两处改动

| 原版 | 改成 | 为什么 |
|---|---|---|
| `gsort firm_id year -production_value` | 末尾加 `product_id` | 只在 `production_value` 精确并列时起作用，不改排序语义。和 02 的核心产品口径对齐，重跑稳定 |
| `joinby ...` 后 `drop _merge` | 删掉那行 | `joinby` 不生成 `_merge`，两个输入也都不带这列，原样跑必报 "variable not found" |

### 内存

PART 3 读 `full_data` 时**只取 6 列**（19 GB → 约 3 GB），这是原文件那个 `use full_data.dta, clear`
一把要 19 GB 的修正。PART 1–2 全在产品对层面（~770 万行），很轻。

---

## 04_entry.do　⬜ 修了注释 bug + merge bug，待重跑

**做什么**：2017→2018 的增量分析。核心产品由 2017 定，对 2018 的结果是**预定的**，
用来回应横截面的 reverse causality。

**三个样本**

| | 定义 | 规模（旧口径参考） |
|---|---|---|
| **A** | 2017 单产品 & 2018 仍在营 | 1,371,269 家 → 74,943,790 行，进入率 1.66% |
| **B** | 两年都在的全部企业，10% 随机抽样 | 468,333 家 → 24,588,519 行，进入率 8.57% |
| **C** | 2017 年的全部副产品，看谁退出 | 34,517,903 行，退出率 54.5% |

**五张表**——每个样本只保留第一张和最后一张（Sample C 本来就只有一张）：

| 表 | 内容 | 列数 |
|---|---|---|
| `A_Entry.txt` | Sample A 新增产品 `d_entry` | 5 |
| `A_Entry_Continuous.txt` | Sample A 新增品的外包份额 | 1 |
| `B_Entry.txt` | Sample B 新增产品 | 5 |
| `B_Entry_Continuous.txt` | Sample B 新增品的外包份额 | 1 |
| `C_Exit.txt` | 产品退出 `d_exit` | 4 |

**砍掉的 4 张**：A 和 B 各两张分解表（Def1 `OS>0` vs `SP=0`、Def2 `OS>=50%` vs `SP<50%`）。

对应两步框架：`d_entry` 是第一步（加不加这个产品），`OS share` 是第二步（加了之后自产还是外购）。

### ★ 2026-09-13 第一次在 VM 上跑：整个文件一行都没执行

**原因是我写的文件头注释。** 第 27 行写了 `*   Empirical1/results/entry/*.txt`，其中的 `/*` 被 Stata 当成块注释开头；
全文件没有 `*/`，于是**从第 27 行到文件末尾全被注释掉**。

用本地 Stata 17 实测确认：

| 测试文件 | 第 3 行注释 | 结果 |
|---|---|---|
| 对照 | `*   results/entry/A_Entry.txt` | 3 个 `display` 全部执行 |
| 测试 | `*   results/entry/*.txt` | 只执行第 1 个；之后全部带 `>` 前缀原样显示，**不执行、不报错** |

这解释了当时的全部现象：`pwd` 停在 `pipeline`（`cd` 没执行）、没有 `results/entry`（`mkdir` 没执行）、没有 log、
git 显示 `nothing to commit`，而结果窗口里能看到「04_entry 全部完成」——那是**源代码被原样滚出来**，不是 `display` 的输出。
03 里没有 `/*`，所以 03 跑通了。

修复后本地实跑：执行到第 54 行 `cd`、因本地无 G: 盘报 r(170)，代码已恢复执行。
全仓库 do 文件已复扫，无 `/*`。归档的 `03_extensive_fullsample.do` 头部同样有 2 处，一并改掉——**它当年也从没真正跑起来过**。

### ★ 2026-09-13 修掉的 merge bug（原文件就有）

Stata 的 `merge` **默认是全外连接**：不带 `keep()` 时，using 表里对不上的行会以 `_merge==2` 整个带进来。
原 `entry_exit_analysis.do` 有 6 处 `merge` 没带 `keep()`，现在都补上了 `keep(master match)`：

| 位置 | 合并 | 被带进来的 | 后果 |
|---|---|---|---|
| **Sample B OTHER** | ← `prods_2017` | 全体企业的 2017 产品 | 🔴 **每家 B 企业都在 `collapse` 里有了分组，OTHER 行 `d_entry` 全变 1——改变 `B_Entry` 结果** |
| **Sample B 展开** | ← `prods_2017` | 约 4,300 万行 2017 产品 | 🟠 **峰值内存涨约 3 倍**（回归不变，这些行相似度缺失被剔）|
| Sample A/B OTHER | ← `choice_set` | 没匹配上的 ~14 万候选对 | 🟡 混进一个空 `firm_id` 垃圾行，log 计数虚高 |
| PART 1 新增/退出 | ← 另一年的产品表 | 另一年独有的产品 | 🟡 `tab is_new` / `tab is_exit` 分母虚高 |

**用小数据按 Stata 语义模拟验证过**：3 家 B 企业里只有 1 家在 top30 外加了产品，原代码给出 `d_entry = 1, 1, 1`（还混进了 2 家非样本企业），
修正后 `1, 0, 0`，与真值一致。

**影响旧结果**：`Empirical_Report` §4.2 的 Sample B 数字（S 0.045 / C 0.116）是带着这个 bug 算的。论文已撤 Sample B，不影响正文。

**顺带解释了内存**：修之前 Sample B 展开其实约 7,000 万行，和 Sample A 差不多大。

### 相对 `entry_exit/entry_exit_analysis.do` 的改动

| # | 改动 | 说明 |
|---|---|---|
| 1 | choice set 不再重建 | 原文件 PART 2 与 03 完全重复，现在直接读 03 的产出 |
| 2 | 砍掉 4 张分解表 | 见上 |
| 3 | `gsort` 加 `product_id` 第二排序键 | 同 03 |
| 4 | 删掉 `joinby` 后的 `drop _merge` | 同 03，原文件同一个 bug |
| 5 | 读 `full_data` 只取 9 列 | 原文件 `use "full_data.dta", clear` 一把要 19 GB |

其余逐行照搬。顺带清掉了砍表后遗留的 `product_has_os` 死代码（2 处）。

### 内存

**峰值在 Sample A 的 `joinby`**：137 万家 × ~54.6 候选 ≈ **7,500 万行**。
Sample B 是 10% 抽样，~47 万 × ~52 ≈ 2,500 万行，只有 A 的三分之一（此前文档写反了）。
Sample C 不需要 choice set，直接用实际产品。

---

## figure.ipynb　🟡 本地验证通过，VM 未跑

**做什么**：第一部分（§2 + §3）所有进论文/报告的图，一个 notebook 出全。
取代原先散在四处的 `make_figures.py`、`fig1_sales_share.py`、`fig2_lift_plot.py`、`similarity_figures.py`。

**26 cell / 16 代码格**，六节：

| 节 | 产出 | 张数 | 用在 |
|---|---|---|---|
| §0 / §0b | 路径检查 + 三个共用 loader | — | — |
| §2.1 | `firm_classification.png` + `summary_table.csv/.md` | 1 | 报告 §2.1 |
| §2.2 | `fig2_composition_*` / `fig3_gap_*` × {2017,2018,pooled} | 6 | **论文** + 报告 §2.2 |
| §3.1a | `fig1_combined_shares_vs_*` + A/B/C 分图 | 8 | **论文** + 报告 §3.1 |
| §3.1b | `fig2_lift_*` + combined | 3 | **论文 + deck** |
| §3.2 | `sim_vs_rank_*` × 4 组（+combined） | 8 | **论文 + deck** |
| §IO | `fig1_input_vectors.png`、`fig3_vector_angles.png` | 2 | **论文 + deck**（★ 重写） |

图 → `results/figures/`（进 git），缓存 → `Empirical1_data/_figure_cache/`（不进 git）。

### 合并时统一的三处

1. **`is_main` 不再各算各的** —— 四个旧脚本各自用 `rank(method='first')` 重算核心产品，并列时结果不确定。
   现在直接用 `full_data` 里存好的（02 已按 `production_value` + `product_id` 双键算出）。
2. **全表扫描 6 遍 → 3 遍** —— 旧脚本每个都把 90M 行整读一次。现在三个 loader 共用 + parquet 缓存。
3. **标签统一** —— `Output Similarity` → `Demand Complementarity`，`Main Product` → `Core Product`。

### ★ §IO 那两张是重写的

原脚本 `Data/seminar_viz.py` **已从机器上删除** —— 全盘搜 `fig1_input_vectors` / `fig3_vector_angles` / `seminar_viz`
只命中 `.tex` 和 `.md` 文档，没有任何代码文件；`Data/` 和 `code/description/` 都不在 git 里，没有历史可翻。

重写时修了四处：

**① 系数列**　去向向量必须用 `coefficient_cal`，不能用 `coefficient`。
校准 = `coefficient_cal = coefficient × 只依赖于行的标量`（行内比值相对标准差 5.15e-16）。
S 用行向量，逐行同乘不改余弦，**对校准免疫**；C 用列向量，**完全依赖校准**。
raw 表行和中位数 1.109 但最大 3035.8（极差 3.27 万倍），且 `corr(log 产出规模, log 行和) = −0.59` ——
raw 是**反着加权**的，最小的部门主导每一列。用 raw 会画出"电动汽车 88% 卖给除霜器"。

**② 例子**　原图用乘用车 / 电动汽车 / 碾磨脱壳谷物。老师明确不喜欢，数据也不支持：
乘用车—电动汽车 S=0.8197（第 7/2777）、**C=0.2381（也是第 7/2777，p99.59）** —— 是高 S **高** C。

**③ 图的设计**　原来「A 锚定 / B 投入像 / C 投入不像」，两个面板用同一组产品，
但 C 在需求维度上并不低（毛巾—碾磨 C=0.047 反而比毛巾—针织袜的 0.037 高），右面板两条线挤在一起。
改成 **2×2 对照**，两个面板排序正好相反：

| 与锚定 A = 毛巾 | S | C |
|---|---|---|
| **B = 针织袜** | **0.991** | 0.037 |
| **D = 天然皮革服装** | 0.015 | **0.208** |

**④ 标签**　产品名走 `TRANS` 字典出英文（论文是英文的），漏译的会打印出来让你补，补不全回落中文 + 中文字体。

### 验证情况

**本地冒烟测试**（截断到前 2 块数据，用旧 `full_data`）：10 格全通，38 个文件全出。
之后做了一次「单遍扫描」重构，复测关键数字逐一相同：

| | 重构前 | 重构后 |
|---|---|---|
| 副产品行数 | 3,429,969 | 3,429,969 ✓ |
| 核心产品数 / 被选对 | 2,659 / 824,513 | 2,659 / 824,513 ✓ |
| 全局 P(chosen) | 0.002415 | 0.002415 ✓ |
| `sim_vs_rank_all` | N=2,795,583 | N=2,795,583 ✓ |

§IO 两张单独本地实跑过，修了两个 bug：A 向量画成水平（「A 与自己的相似度」传成 0.0，`arccos(0)=90°`，应是 1.0）、
8° 夹角时标签叠字。

**VM 上还没跑过。**

### ⚠️ 跑之前确认一件事

**`io_table_calibrated.dta` 在不在 VM 上？** 本地在 `aproject\Data\`（1.8 GB）。
这是 §IO 那两张唯一能用的数据源。**不能用 `io_table_lite.dta` 顶替** —— 它只有 `coefficient`，没有 `coefficient_cal`。

notebook 第一格会检查全部输入并报告；缺了就跳过 §IO，其余照跑。

---

## patch_relative_main.{ipynb,do}　🟡 半成品，可选

**做什么**：把 `full_data.dta` 的两列换成 production 口径。

| 旧列 | 新列 |
|---|---|
| `main_product_output`（核心产品的 `total_output`） | `main_product_production` |
| `sales_relative_main` = 副 sales / 主 sales | `production_relative_main` = 副 production / 主 production |

**为什么要改**：旧口径下核心产品按 `total_output` 取最大，分母就是该 firm-year 的最大销量，比值**数学上恒 ≤ 1**。
核心产品改按 `production_value` 选之后，分母跟最大值脱钩了 —— 转售型企业尤其危险，
自产最多的可能是个只卖几百块的小产品，分母趋近 0，比值爆炸（实测均值从 0.20 涨到 180 万）。
分子分母同用 `production_value` 才重新有界。

**跑到哪**

- **Step 1 ✅ 成功** —— `main_product_production.dta` 已生成，12,339,578 firm-year，0 重复，均值 1.757607e+07
- **Step 2 ❌ MemoryError** —— DataFrame 建好了（`90,297,401 行 x 30 列` 打印出来了），
  但 `df.to_stata()` 在 pandas 的 `_merge_blocks` / `np.vstack` 里要
  `Unable to allocate 12.8 GiB for an array with shape (19, 90297401)`

**原因**：pandas 的 `to_stata` 要把散在多个 block 的 19 个 float64 列合并成一块连续数组，
等于在已占用的 ~16 GB 之上再要第二份 ~13 GB。

**`patch_relative_main.do` 是替代方案**：Stata 列式存储 + 流式 save，没有这个合并开销，
只要装得下整个 full_data（约 19 GB）就能跑。**未跑。**

**结论：不跑也没关系。**
03 / 04 都不读这两列；`figure.ipynb` 也不读；
`code/description/main_os/intensive_margin_analysis.do` 里 `sales_relative_main` 有 20+ 处引用，
但那半边产出的 12 个 `S*_D/E/F_Sales.txt` **论文一处都没引用**。
等哪天 02 重跑一遍，这两列自然就对了。

---

## 还没写的

| 论文章节 | 旧代码 | 状态 |
|---|---|---|
| §3.5 外包份额（横截面）| `code/description/main_os/intensive_margin_analysis.do`（1277 行）| ⬜ **下一个** |
| 稳健性 trim | `code/description/trim/` ×4 | ⬜ 未写，且原件从没跑过 |
| 销售额加权 | `code/description/advisor_revisions/entry_exit_weighted.do` | ⬜ 未写 |

> §4 进入/退出已由 `04_entry.do` 覆盖（2026-09-10 范围调整后并进来的）。

### §3.5 开工前要先走查的三条

来自 9 个 do 文件那轮 review（记录在 `code/description/clean.md` §8.3）。代码位置已定位：

```
L60   reghdfe ln_output, absorb(product_id#year) residuals(product_demand_resid)
L62-66   preserve → keep if is_main == 1 → 取出核心产品那行的残差
L71   drop if is_main == 1          ← 残差算完之后才删的
L77-80   egen z_`var' = std(`var')     ← 全样本算一次
L94   keep if is_outsourcing == 1 → 存 clean_reg_subsample.dta
L690  PART 4 用这个子样本，L790 仍然用 z_ 变量
```

| # | 问题 | 性质 |
|---|---|---|
| 1 | `main_demand_resid` 残差化时次要产品行还在（L71 才删）| **顺序问题，要你判断** |
| 2 | z-score 在 L77 全样本算一次，PART 4 换子样本后没重算 | **确定的技术缺陷**，那几张表的"标准化 β"不能按标准差解读 |
| 3 | PART 4 用 `is_outsourcing == 1` 筛样本但 LHS 仍是 `outsourcing_percen` | **按结果变量选样本** |

### 一个好消息

流程重建**修好了 §3.5 的口径**：它直接吃 `full_data` 的 `is_main` 和相似度列，
旧的是销量口径，新的是 `production_value` 口径 —— 和论文 `Empirical_Report.md` L22
声明的定义（"the product with the highest self-production value, not sales"）终于一致了。

---

## 术语提醒

老师 8/27 定的固定术语里，**去掉 extensive / intensive / entry**。

| 现状 | 评价 |
|---|---|
| `03_choice_set.do` / `results/choice_set/` | ✅ 已避开 |
| `04_entry.do` / `results/entry/` | ⚠️ `entry` 也在禁用词里，可考虑 `04_new_products.do` |
| §3.5 那个将来写成 `05_sourcing.do` | 对应第二步 sourcing |

**代码里的变量名不动**（`output_similarity`、`is_main`、`d_entry`）—— 改列名要牵动一大片，
目前只在文件名和文字层面执行新术语。

---

*事实性内容可在 `../diagnostics/` 的报告和各文件本身复核；与本文档冲突时以原始文件为准。*
