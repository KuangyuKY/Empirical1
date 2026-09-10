*=====================================================================
* 03_choice_set.do —— Choice set 构造 + 覆盖率诊断
*
* 每个核心产品取 input top30 ∪ demand-complementarity top30 作候选集，
* 其余 ~2,720 个产品压成一行 OTHER（相似度取均值）。
* 全部在**产品对层面**算完，不按企业展开——展开是 04 的事。
*
* 输入
*   Empirical1_data/full_data.dta        90,297,401 行 x 30 列（只读 5 列）
*   ../Data/full_product_similarity.dta  产品对级相似度（单向，本文件翻成双向）
*
* 输出（Empirical1_data/entry/，不进 git）
*   sim_bi.dta          双向相似度，2 x 3,857,253 行   ← 04 的 Sample C 要用
*   choice_set.dta      main_pid product_id input_similarity output_similarity
*   choice_set_other.dta  main_pid input_similarity output_similarity（每个核心产品一行）
*
* 输出（进 git）
*   results/choice_set/coverage.txt         覆盖率表（论文 §3.1）
*   diagnostics/03_choice_set.log           全过程 log
*
*-----------------------------------------------------------------
* ★ 本文件是 03_extensive.do 的替代品，全样本横截面回归已砍掉
*
*   原 03_extensive.do 把每个 firm-year 配上 ~54 个候选后跑 LPM/PPML，
*   展开后 625,619,601 行、joinby 峰值 25–30 GB，在 VM 上跑不出来。
*   现在只做产品对层面的 choice set（~14 万行），回归改由 04 在
*   Sample A/B/C 上做——Sample A 只有 74,943,790 行，少 88%。
*
*   那两张进论文的图（选择提升 lift、相似度 vs 销量排名）**不依赖 choice set**，
*   它们在 figure.ipynb 里直接从产品对层面算，不受影响。
*
* 相对 diversification_complete.do 的两处改动
*   1. gsort 加第二排序键 product_id —— 只在 production_value 精确并列时起作用，
*      不改排序语义；和 02 的核心产品口径一致，重跑结果稳定。
*   2. 删掉 joinby 后的 drop _merge —— joinby 不生成 _merge，原样跑必报错。
*
* 列名统一用 main_pid / product_id（04 直接吃，不用改名）。
*=====================================================================

clear all
set more off
set max_memory ., permanently

* 切换 VM / 本地只改这一行。下面全用相对路径——
* Stata 的 clear all 会清掉 global 宏，但不改工作目录。
cd "G:/Kuangyu_Temp/Outsource"                          // VM
* cd "C:/Users/HKUBS/Documents/aproject/Outsourcing"    // 本地
*
*   ../Data/                      原始数据，只读
*   Empirical1_data/entry/        本文件与 04 的中间表
*   Empirical1/results/choice_set/  覆盖率表，进 git

capture mkdir "Empirical1_data/entry"
capture mkdir "Empirical1/results"
capture mkdir "Empirical1/results/choice_set"

capture log close
log using "Empirical1/diagnostics/03_choice_set.log", replace text


*=====================================================================
* PART 1　双向 similarity
*         原表每对只存一次，复制翻转拼成双向
*=====================================================================

use "../Data/full_product_similarity.dta", clear
keep product_1 product_2 input_similarity output_similarity
rename product_1 main_pid
rename product_2 product_id
save "Empirical1_data/entry/sim_fwd.dta", replace

rename main_pid temp
rename product_id main_pid
rename temp product_id
save "Empirical1_data/entry/sim_rev.dta", replace

use "Empirical1_data/entry/sim_fwd.dta", clear
append using "Empirical1_data/entry/sim_rev.dta"
compress
save "Empirical1_data/entry/sim_bi.dta", replace

display ""
display "============================================="
display "双向 similarity 行数:"
count
display "  （应为单向 3,857,253 的两倍）"
display "============================================="


*=====================================================================
* PART 2　Choice set：input top30 ∪ output top30
*=====================================================================

* --- input top 30 ---
preserve
gsort main_pid -input_similarity product_id
by main_pid: gen ri = _n
keep if ri <= 30
keep main_pid product_id input_similarity output_similarity
gen from_input = 1
tempfile ti
save `ti'
restore

* --- output top 30 ---
preserve
gsort main_pid -output_similarity product_id
by main_pid: gen ro = _n
keep if ro <= 30
keep main_pid product_id input_similarity output_similarity
gen from_output = 1
tempfile to
save `to'
restore

* --- 并集 ---
use `ti', clear
append using `to'

bysort main_pid product_id: gen n_appear = _N
count if n_appear == 2
local both = r(N) / 2
drop n_appear

duplicates drop main_pid product_id, force

display ""
display "============================================="
display "Choice set 构造（产品对层面）"
display "============================================="
count
local total_pairs = r(N)
count if from_input == 1 & from_output == .
local only_input = r(N)
count if from_input == . & from_output == 1
local only_output = r(N)
display "总候选对: `total_pairs'"
display "  仅 input top30:  `only_input'"
display "  仅 output top30: `only_output'"
display "  两者重叠:         `both'"

bysort main_pid: gen nc = _N
summarize nc
display "平均每个核心产品的候选数: " %5.1f r(mean)
drop nc from_input from_output

compress
save "Empirical1_data/entry/choice_set.dta", replace

* --- OTHER：top30 以外产品的平均相似度，每个核心产品一行 ---
use "Empirical1_data/entry/sim_bi.dta", clear
merge m:1 main_pid product_id using "Empirical1_data/entry/choice_set.dta"
gen in_top30 = (_merge == 3)
drop _merge

display ""
display "Top30 内产品对:"
count if in_top30 == 1
display "Top30 外产品对:"
count if in_top30 == 0

keep if in_top30 == 0
collapse (mean) input_similarity output_similarity, by(main_pid)
compress
save "Empirical1_data/entry/choice_set_other.dta", replace

display "OTHER（每个核心产品一行）:"
count
summarize input_similarity output_similarity


*=====================================================================
* PART 3　覆盖率诊断（论文 §3.1 那张表）
*
*   分母 = 企业实际生产的全部副产品
*   分子 = 其中落在自家核心产品 top-N 候选集里的
*   销售额覆盖率按 total_output 加权
*=====================================================================

* --- 企业实际的核心产品 / 副产品（只读 5 列，19 GB → 约 3 GB）---
use firm_id year product_id production_value total_output is_intermediary ///
    using "Empirical1_data/full_data.dta", clear
drop if is_intermediary == 1
drop is_intermediary

* 核心产品 = production_value 最大，并列取 product_id 最小（与 02 同口径）
gsort firm_id year -production_value product_id
by firm_id year: gen prod_rank = _n

preserve
keep if prod_rank == 1
keep firm_id year product_id
rename product_id main_pid
compress
save "Empirical1_data/entry/main_info_all.dta", replace
restore

keep if prod_rank > 1
keep firm_id year product_id total_output
merge m:1 firm_id year using "Empirical1_data/entry/main_info_all.dta", ///
    keepusing(main_pid) keep(match) nogen
compress
save "Empirical1_data/entry/actual_secondary.dta", replace

display ""
display "============================================="
display "实际副产品总数:"
count
local tot_n = r(N)
summarize total_output, meanonly
local tot_v = r(sum)
display "实际副产品销售额合计: " %15.0fc `tot_v'
display "============================================="

* --- 逐个 N 算覆盖率 ---
tempname cov
tempfile cs
postfile `cov' topn avg_cand cov_n cov_v using "Empirical1_data/entry/_cov.dta", replace

foreach N in 30 50 100 {
    use "Empirical1_data/entry/sim_bi.dta", clear

    gsort main_pid -input_similarity product_id
    by main_pid: gen ri = _n
    gsort main_pid -output_similarity product_id
    by main_pid: gen ro = _n
    keep if ri <= `N' | ro <= `N'
    keep main_pid product_id
    duplicates drop main_pid product_id, force

    bysort main_pid: gen nc = _N
    summarize nc, meanonly
    local avg = r(mean)
    drop nc

    save `cs', replace

    use "Empirical1_data/entry/actual_secondary.dta", clear
    merge m:1 main_pid product_id using `cs', keep(master match)
    gen covered = (_merge == 3)
    drop _merge

    count if covered == 1
    local cn = r(N)
    summarize total_output if covered == 1, meanonly
    local cv = r(sum)

    post `cov' (`N') (`avg') (`cn'/`tot_n'*100) (`cv'/`tot_v'*100)
}
postclose `cov'

use "Empirical1_data/entry/_cov.dta", clear
label var topn     "Top-N"
label var avg_cand "Avg candidates"
label var cov_n    "Count coverage (%)"
label var cov_v    "Sales coverage (%)"

display ""
display "============================================="
display "覆盖率（论文 §3.1）"
display "============================================="
list, noobs clean

outsheet using "Empirical1/results/choice_set/coverage.txt", replace


*=====================================================================
display ""
display "============================================="
display "03_choice_set 完成"
display "============================================="
display ""
display "中间表 -> Empirical1_data/entry/"
display "    sim_bi.dta             双向相似度（04 的 Sample C 要用）"
display "    choice_set.dta         top30 并集"
display "    choice_set_other.dta   OTHER 行的相似度"
display "    main_info_all.dta      每个 firm-year 的核心产品"
display "    actual_secondary.dta   企业实际的副产品"
display ""
display "结果 -> Empirical1/results/choice_set/coverage.txt"
display ""
display "下一步：04_entry.do"
display "============================================="

log close
