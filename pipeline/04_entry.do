*=====================================================================
* 04_entry.do —— 2017→2018 增量：新增产品与产品退出
*
* 用面板增量回应 reverse causality：核心产品由 2017 定，对 2018 的结果是预定的。
*
* 三个样本
*   A  2017 单产品 & 2018 仍在营的企业        ← 核心产品无歧义
*   B  两年都在的全部企业，10% 随机抽样
*   C  2017 年的全部副产品，看谁退出
*
* 五张表（每个样本只保留第一张和最后一张）
*   A_Entry.txt              新增产品 d_entry           5 列
*   A_Entry_Continuous.txt   新增产品的外包份额          1 列
*   B_Entry.txt              同上，Sample B             5 列
*   B_Entry_Continuous.txt   同上，Sample B             1 列
*   C_Exit.txt               产品退出 d_exit            4 列
*
* 前置：先跑 03_choice_set.do，本文件直接读它的 choice_set / sim_bi，不重建。
*
* 输入
*   Empirical1_data/full_data.dta         （只读 7 列）
*   Empirical1_data/entry/choice_set.dta
*   Empirical1_data/entry/choice_set_other.dta
*   Empirical1_data/entry/sim_bi.dta
*
* 输出
*   Empirical1/results/entry/             5 张 .txt 表（进 git）
*   Empirical1/diagnostics/04_entry.log   全过程 log（进 git）
*
*-----------------------------------------------------------------
* 相对 code/description/entry_exit/entry_exit_analysis.do 的改动
*   1. choice set 不再重建，读 03 的产出（原文件 PART 2 与 03 完全重复）
*   2. 砍掉 4 张分解表（Def1 OS>0 / Def2 OS>=50%，A 和 B 各两张）
*   3. gsort 加第二排序键 product_id —— 只在 production_value 精确并列时起作用
*   4. （勘误）原文件 joinby 后的 drop _merge 是对的，已恢复：带 unmatched() 时
*      joinby 会生成 _merge，不删的话下一个 merge 报 r(110)（2026-09-13 本地实测）
*   5. 6 处 merge 补 keep(master match) —— Stata 的 merge 默认全外连接，
*      原文件不带 keep 会把 using 端对不上的行整个带进来：
*        L314 Sample B OTHER 合 prods_2017：全体企业的 2017 产品混进来，
*             使每家 B 企业都在 collapse 里有分组，OTHER 行 d_entry 全部变 1（改变结果）
*        L281 Sample B 展开合 prods_2017：多带进约 4,300 万行，峰值内存涨约 3 倍
*        L195/L318 合 choice_set、L116/L136 新增/退出识别：垃圾行或分母虚高，不改回归
*   其余逐行照搬。
*
* 内存：峰值是 Sample A 的 joinby——137 万家 × ~54.6 候选 ≈ 7,500 万行。
*       Sample B 是 10% 抽样，~47 万 × ~52 ≈ 2,500 万行，只有 A 的三分之一。
*
* 注释里别写"斜杠紧跟星号"：Stata 会把它当成块注释开头，没有闭合的话从那一行
* 起整个文件都变成注释、一行都不执行（2026-09-13 本文件第 27 行就踩过）。
*=====================================================================

clear all
set more off
set max_memory ., permanently
set matsize 11000

* 切换 VM / 本地只改这一行（clear all 会清 global 但不改工作目录）
* VM 上用这一行：
cd "G:/Kuangyu_Temp/Outsource"
* 本地用这一行（切换时：上面的 cd 前加 *，下面这行去掉 *）：
* cd "C:/Users/HKUBS/Documents/aproject/Outsourcing"

capture mkdir "Empirical1_data/entry"
capture mkdir "Empirical1/results"
capture mkdir "Empirical1/results/entry"

capture log close
log using "Empirical1/diagnostics/04_entry.log", replace text

global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


*=====================================================================
* PART 0　基础数据：分年的产品列表与核心产品
*=====================================================================

use firm_id year product_id production_value outsourcing_percen total_output n_products firm_total_output is_intermediary using "Empirical1_data/full_data.dta", clear
drop if is_intermediary == 1
drop is_intermediary

* --- 2017 年核心产品（production_value 最大，并列取 product_id 最小）---
preserve
keep if year == 2017
gsort firm_id -production_value product_id
by firm_id: gen rank = _n
keep if rank == 1
keep firm_id product_id n_products firm_total_output
rename product_id     main_pid
rename n_products     n_products_2017
rename firm_total_output firm_output_2017
compress
save "Empirical1_data/entry/main_2017.dta", replace
restore

* --- 2017 年所有产品 ---
preserve
keep if year == 2017
keep firm_id product_id
compress
save "Empirical1_data/entry/prods_2017.dta", replace
restore

* --- 2018 年所有产品（带外包信息）---
preserve
keep if year == 2018
keep firm_id product_id outsourcing_percen production_value total_output
compress
save "Empirical1_data/entry/prods_2018.dta", replace
restore

* --- 2018 年仍在营的企业 ---
preserve
keep if year == 2018
keep firm_id
duplicates drop
save "Empirical1_data/entry/firms_2018.dta", replace
restore


*=====================================================================
* PART 1　识别新增与退出
*=====================================================================

* --- 新增：2018 有、2017 没有 ---
use "Empirical1_data/entry/prods_2018.dta", clear
merge m:1 firm_id product_id using "Empirical1_data/entry/prods_2017.dta", keep(master match)
gen is_new = (_merge == 1)
drop _merge

display ""
display "============================================="
display "新增 vs 存续"
tab is_new
display "============================================="

preserve
keep if is_new == 1
gen product_has_os = (outsourcing_percen > 0)
keep firm_id product_id outsourcing_percen product_has_os production_value total_output
compress
save "Empirical1_data/entry/new_prods_2018.dta", replace
restore

* --- 退出：2017 有、2018 没有 ---
use "Empirical1_data/entry/prods_2017.dta", clear
merge m:1 firm_id product_id using "Empirical1_data/entry/prods_2018.dta", keep(master match)
gen is_exit = (_merge == 1)
drop _merge

display ""
display "退出 vs 存续"
tab is_exit


*=====================================================================
* PART 2　Sample A —— 2017 单产品 → 2018 新增
*=====================================================================

display ""
display "============================================="
display "Sample A: 2017 单产品 -> 2018 多产品"
display "============================================="

use "Empirical1_data/entry/main_2017.dta", clear
keep if n_products_2017 == 1
merge m:1 firm_id using "Empirical1_data/entry/firms_2018.dta", keep(match) nogen
display "2017 单产品 & 2018 仍在营:"
count
save "Empirical1_data/entry/sample_A_firms.dta", replace

* --- Step 1：具体产品行 ---
joinby main_pid using "Empirical1_data/entry/choice_set.dta", unmatched(master)
* 带 unmatched() 的 joinby 会生成 _merge，先删掉，否则下一个 merge 报 r(110)
drop _merge
drop if product_id == main_pid

display "展开后:"
count

merge m:1 firm_id product_id using "Empirical1_data/entry/new_prods_2018.dta", keep(master match)
gen d_entry = (_merge == 3)
drop _merge

gen is_other = 0
gen ln_firm_output = ln(firm_output_2017 + 1)
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)

preserve
keep firm_id firm_n
duplicates drop
save "Empirical1_data/entry/firm_n_map_A.dta", replace
restore

keep firm_n prod_n d_entry outsourcing_percen input_similarity output_similarity ln_firm_output n_products_2017 is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/entry/sample_A_indiv.dta", replace

* --- Step 2：OTHER 行（每个企业一行）---
use "Empirical1_data/entry/new_prods_2018.dta", clear
merge m:1 firm_id using "Empirical1_data/entry/sample_A_firms.dta", keep(match) nogen

merge m:1 main_pid product_id using "Empirical1_data/entry/choice_set.dta", keep(master match)
gen in_top30 = (_merge == 3)
drop _merge
keep if in_top30 == 0
drop in_top30

display "Sample A：top30 以外的新增产品:"
count

* 这里每一行都是新增产品，所以 d_entry 恒为 1
collapse (mean) avg_os = outsourcing_percen, by(firm_id)
gen d_entry = 1
rename avg_os outsourcing_percen
tempfile other_A
save `other_A'

* 从完整企业列表左连接：没在 top30 外新增的，d_entry = 0
use "Empirical1_data/entry/sample_A_firms.dta", clear
merge 1:1 firm_id using `other_A', keepusing(d_entry outsourcing_percen)
replace d_entry = 0 if _merge == 1
replace outsourcing_percen = . if _merge == 1
drop _merge

merge m:1 main_pid using "Empirical1_data/entry/choice_set_other.dta", keepusing(input_similarity output_similarity) keep(match master) nogen

gen is_other = 1
gen ln_firm_output = ln(firm_output_2017 + 1)
merge m:1 firm_id using "Empirical1_data/entry/firm_n_map_A.dta", keep(match master) nogen

* OTHER 当成"第 N+1 个产品"，共用一个 prod_n
preserve
use "Empirical1_data/entry/sample_A_indiv.dta", clear
summarize prod_n
local max_pn = r(max)
restore
gen prod_n = `max_pn' + 1

keep firm_n prod_n d_entry outsourcing_percen input_similarity output_similarity ln_firm_output n_products_2017 is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/entry/sample_A_other.dta", replace

display "Sample A OTHER 行:"
count
summarize d_entry

* --- Step 3：合并 ---
use "Empirical1_data/entry/sample_A_indiv.dta", clear
append using "Empirical1_data/entry/sample_A_other.dta"

display ""
display "Sample A 最终（含 OTHER）:"
count
summarize d_entry
save "Empirical1_data/entry/sample_A.dta", replace


*=====================================================================
* PART 3　Sample B —— 全部企业，10% 随机抽样
*=====================================================================

display ""
display "============================================="
display "Sample B: 全部企业（10% 抽样）"
display "============================================="

use "Empirical1_data/entry/main_2017.dta", clear
merge m:1 firm_id using "Empirical1_data/entry/firms_2018.dta", keep(match) nogen
display "两年都在的企业:"
count

set seed 20260312
gen u = runiform()
keep if u < 0.10
drop u
display "10% 随机样本:"
count
save "Empirical1_data/entry/sample_B_firms.dta", replace

* --- Step 1：具体产品行 ---
joinby main_pid using "Empirical1_data/entry/choice_set.dta", unmatched(master)
* 带 unmatched() 的 joinby 会生成 _merge，先删掉，否则下一个 merge 报 r(110)
drop _merge
drop if product_id == main_pid

* 排除 2017 年已经有的副产品
merge m:1 firm_id product_id using "Empirical1_data/entry/prods_2017.dta", keep(master match)
drop if _merge == 3
drop _merge

display "Sample B 展开后（已排除 2017 已有）:"
count

merge m:1 firm_id product_id using "Empirical1_data/entry/new_prods_2018.dta", keep(master match)
gen d_entry = (_merge == 3)
drop _merge

gen is_other = 0
gen ln_firm_output = ln(firm_output_2017 + 1)
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)

preserve
keep firm_id firm_n
duplicates drop
save "Empirical1_data/entry/firm_n_map_B.dta", replace
restore

keep firm_n prod_n d_entry outsourcing_percen input_similarity output_similarity ln_firm_output n_products_2017 is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/entry/sample_B_indiv.dta", replace

* --- Step 2：OTHER 行 ---
use "Empirical1_data/entry/new_prods_2018.dta", clear
merge m:1 firm_id using "Empirical1_data/entry/sample_B_firms.dta", keep(match) nogen

merge m:1 firm_id product_id using "Empirical1_data/entry/prods_2017.dta", keep(master match)
drop if _merge == 3
drop _merge

merge m:1 main_pid product_id using "Empirical1_data/entry/choice_set.dta", keep(master match)
gen in_top30 = (_merge == 3)
drop _merge
keep if in_top30 == 0
drop in_top30

display "Sample B：top30 以外的新增产品:"
count

collapse (mean) avg_os = outsourcing_percen, by(firm_id)
gen d_entry = 1
rename avg_os outsourcing_percen
tempfile other_B
save `other_B'

use "Empirical1_data/entry/sample_B_firms.dta", clear
merge 1:1 firm_id using `other_B', keepusing(d_entry outsourcing_percen)
replace d_entry = 0 if _merge == 1
replace outsourcing_percen = . if _merge == 1
drop _merge

merge m:1 main_pid using "Empirical1_data/entry/choice_set_other.dta", keepusing(input_similarity output_similarity) keep(match master) nogen

gen is_other = 1
gen ln_firm_output = ln(firm_output_2017 + 1)
merge m:1 firm_id using "Empirical1_data/entry/firm_n_map_B.dta", keep(match master) nogen

preserve
use "Empirical1_data/entry/sample_B_indiv.dta", clear
summarize prod_n
local max_pn = r(max)
restore
gen prod_n = `max_pn' + 1

keep firm_n prod_n d_entry outsourcing_percen input_similarity output_similarity ln_firm_output n_products_2017 is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/entry/sample_B_other.dta", replace

display "Sample B OTHER 行:"
count
summarize d_entry

* --- Step 3：合并 ---
use "Empirical1_data/entry/sample_B_indiv.dta", clear
append using "Empirical1_data/entry/sample_B_other.dta"

display ""
display "Sample B 最终（含 OTHER）:"
count
summarize d_entry
save "Empirical1_data/entry/sample_B.dta", replace


*=====================================================================
* PART 4　Sample C —— 产品退出
*         不需要 choice set，直接用企业实际的副产品
*=====================================================================

display ""
display "============================================="
display "Sample C: 产品退出"
display "============================================="

use "Empirical1_data/entry/prods_2017.dta", clear
merge m:1 firm_id using "Empirical1_data/entry/main_2017.dta", keep(match) nogen
drop if product_id == main_pid

merge m:1 main_pid product_id using "Empirical1_data/entry/sim_bi.dta", keep(match) nogen

merge m:1 firm_id product_id using "Empirical1_data/entry/prods_2018.dta", keep(master match)
gen d_exit = (_merge == 1)
drop _merge

display "退出率:"
summarize d_exit

gen ln_firm_output = ln(firm_output_2017 + 1)
gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)

keep firm_n prod_n d_exit input_similarity output_similarity ln_firm_output n_products_2017
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/entry/sample_C.dta", replace

display ""
display "Sample C 行数:"
count


*=====================================================================
*   回归
*=====================================================================

* ===== A1. Sample A 新增产品 =====

use "Empirical1_data/entry/sample_A.dta", clear
display ""
display "============================================="
display "A1: Sample A 新增产品"
display "============================================="
count

reg d_entry input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store ae1

reg d_entry input_similarity output_similarity ln_firm_output, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store ae2

reghdfe d_entry input_similarity output_similarity, absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No", replace
est store ae3

reghdfe d_entry input_similarity output_similarity, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
est store ae4

reghdfe d_entry input_similarity output_similarity ln_firm_output, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
est store ae5

esttab ae1 ae2 ae3 ae4 ae5 using "Empirical1/results/entry/A_Entry.txt", replace $esttab_opts order(input_similarity output_similarity ln_firm_output) stats(firm_fe prod_fe N r2_a, labels("Firm FE" "Product FE" "Observations" "Adj. R-sq") fmt(%s %s %12.0fc 3)) title("Sample A (Single to Multi): New Product Entry") mtitles("OLS" "+FC" "FirmFE" "Firm+Prod" "+FC")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== A2. Sample A 新增产品的外包份额 =====

use "Empirical1_data/entry/sample_A.dta", clear
keep if d_entry == 1

reghdfe outsourcing_percen input_similarity output_similarity, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local dv "OS share", replace
est store acont

esttab acont using "Empirical1/results/entry/A_Entry_Continuous.txt", replace $esttab_opts stats(dv N r2_a, labels("Dep. Variable" "Observations" "Adj. R-sq") fmt(%s %12.0fc 3)) title("Sample A: OS Share Among New Products (Firm + Product FE)") mtitles("OS share")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== B1. Sample B 新增产品 =====

use "Empirical1_data/entry/sample_B.dta", clear
display ""
display "============================================="
display "B1: Sample B 新增产品"
display "============================================="
count

reg d_entry input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store be1

reg d_entry input_similarity output_similarity ln_firm_output n_products_2017, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store be2

reghdfe d_entry input_similarity output_similarity, absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No", replace
est store be3

reghdfe d_entry input_similarity output_similarity, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
est store be4

reghdfe d_entry input_similarity output_similarity ln_firm_output n_products_2017, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
est store be5

esttab be1 be2 be3 be4 be5 using "Empirical1/results/entry/B_Entry.txt", replace $esttab_opts order(input_similarity output_similarity ln_firm_output n_products_2017) stats(firm_fe prod_fe N r2_a, labels("Firm FE" "Product FE" "Observations" "Adj. R-sq") fmt(%s %s %12.0fc 3)) title("Sample B (All Firms): New Product Entry 2017-2018") mtitles("OLS" "+FC" "FirmFE" "Firm+Prod" "+FC")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== B2. Sample B 新增产品的外包份额 =====

use "Empirical1_data/entry/sample_B.dta", clear
keep if d_entry == 1

reghdfe outsourcing_percen input_similarity output_similarity, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local dv "OS share", replace
est store bcont

esttab bcont using "Empirical1/results/entry/B_Entry_Continuous.txt", replace $esttab_opts stats(dv N r2_a, labels("Dep. Variable" "Observations" "Adj. R-sq") fmt(%s %12.0fc 3)) title("Sample B: OS Share Among New Products (Firm + Product FE)") mtitles("OS share")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== C. Sample C 产品退出 =====

use "Empirical1_data/entry/sample_C.dta", clear
display ""
display "============================================="
display "C: Sample C 产品退出"
display "============================================="
count

reg d_exit input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store ce1

reg d_exit input_similarity output_similarity ln_firm_output, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local prod_fe "No", replace
est store ce2

reghdfe d_exit input_similarity output_similarity, absorb(firm_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "No", replace
est store ce3

reghdfe d_exit input_similarity output_similarity, absorb(firm_n prod_n) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
est store ce4

esttab ce1 ce2 ce3 ce4 using "Empirical1/results/entry/C_Exit.txt", replace $esttab_opts order(input_similarity output_similarity ln_firm_output) stats(firm_fe prod_fe N r2_a, labels("Firm FE" "Product FE" "Observations" "Adj. R-sq") fmt(%s %s %12.0fc 3)) title("Product Exit 2017-2018: d_exit") mtitles("OLS" "+FC" "FirmFE" "Firm+Prod")
est clear
clear all


*=====================================================================
display ""
display "============================================="
display "04_entry 全部完成"
display "============================================="
display ""
display "回归表 -> Empirical1/results/entry/"
display "    A_Entry.txt              Sample A 新增产品        5 列"
display "    A_Entry_Continuous.txt   Sample A 新增品外包份额  1 列"
display "    B_Entry.txt              Sample B 新增产品        5 列"
display "    B_Entry_Continuous.txt   Sample B 新增品外包份额  1 列"
display "    C_Exit.txt               产品退出                 4 列"
display ""
display "预期方向"
display "    Entry:  两个相似度都为正（越像越可能加）"
display "    Exit:   两个相似度都为负（越像越不容易退）"
display "    OS share: demand complementarity 为正、input similarity 为负"
display "============================================="

log close
