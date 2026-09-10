*=====================================================================
* 03_extensive.do —— Block 1：横截面 extensive margin（论文 §3.3–3.4）
*
* 问题：给定主产品，企业更可能把哪些产品加进产品组合？
* 因变量：d_chosen（这个候选产品被选中没有）+ 三个外包/自产的细分
* 自变量：input_similarity（投入相似度）、output_similarity（产出互补度）
*
* Choice set：每个主产品取 input top30 ∪ output top30，
*             剩下的产品压成一行 OTHER（相似度取均值）代表"低相似度那一堆"。
*
* 输入
*   Empirical1_data/full_data.dta       90,297,401 行 x 30 列
*   ../Data/full_product_similarity.dta 产品对级相似度（单向，代码里翻倍成双向）
*
* 输出
*   Empirical1_data/diversification/*.dta  中间表 + 回归样本（不进 git）
*   Empirical1/results/extensive/*.txt     11 张回归表（进 git）
*   Empirical1/diagnostics/03_extensive.log  全过程 log，含 choice set 规模与覆盖率
*
* 相对原版 diversification_complete.do 的两处改动（其余逐行照搬）
*   1. L32 gsort 加第二排序键 product_id —— 只在 production_value 精确并列时
*      起作用，不改排序语义；目的是和 02 的主产品口径一致、重跑结果稳定。
*   2. L174 删掉 drop _merge —— joinby 不生成 _merge，main_info 和
*      choice_set_union 也都不带这一列，原样跑必然报 "variable not found"。
*
* ★ 内存：PART 3 Step 1 的 joinby 是全流程峰值。
*   去中介后约 1,157 万 firm-year × 平均 ~48 个候选 ≈ 5.5 亿行 × 8 列，
*   粗估 25–30 GB。别的老师同时在用虚拟机时大概率跑不动。
*   降级顺序：① 分年跑（if year == 2017 / 2018）再 append，峰值减半
*             ② top30 降到 top20，候选数 ≈ -1/3
*   div_data.dta 存盘后体积小得多（只留 14 个窄列），后面所有回归都不吃紧。
*=====================================================================

clear all
set more off
set max_memory ., permanently
set matsize 11000

* 切换 VM / 本地只改这一行。下面全部用相对路径——
* Stata 的 clear all 会清掉 global 宏，但不会改工作目录。
cd "G:/Kuangyu_Temp/Outsource"                          // VM
* cd "C:/Users/HKUBS/Documents/aproject/Outsourcing"    // 本地
*
*   ../Data/                        原始数据，只读
*   Empirical1_data/                所有产物
*   Empirical1_data/diversification/  本文件的中间表
*   Empirical1/results/extensive/   回归表，进 git

capture mkdir "Empirical1_data/diversification"
capture mkdir "Empirical1/results"
capture mkdir "Empirical1/results/extensive"

capture log close
log using "Empirical1/diagnostics/03_extensive.log", replace text

global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


*=====================================================================
* PART 1　主产品信息 + 实际选择列表
*=====================================================================

use "Empirical1_data/full_data.dta", clear
drop if is_intermediary == 1

* 主产品 = production_value 最大；并列取 product_id 最小（与 02 同口径）
gsort firm_id year -production_value product_id
by firm_id year: gen prod_rank = _n
gen new_is_main = (prod_rank == 1)

* --- 主产品行 ---
preserve
keep if new_is_main == 1
keep firm_id year product_id firm_total_output n_products
rename product_id main_product_id
compress
save "Empirical1_data/diversification/main_info.dta", replace
restore

* --- 副产品行 = 企业实际做出的"额外选择" ---
preserve
keep if new_is_main == 0
keep firm_id year product_id outsourcing_percen
gen actually_chosen = 1
gen product_has_outsourcing = (outsourcing_percen > 0)
compress
save "Empirical1_data/diversification/actual_choices.dta", replace
restore

use "Empirical1_data/diversification/main_info.dta", clear
count
display "Firm x Year（去中介后）: " r(N)


*=====================================================================
* PART 2　构造 Choice Set（input top30 ∪ output top30 + OTHER）
*=====================================================================

* similarity 原表是单向的（每对只存一次），复制翻转拼成双向
use "../Data/full_product_similarity.dta", clear
rename product_1 p1
rename product_2 p2
save "Empirical1_data/diversification/sim_fwd.dta", replace

rename p1 temp
rename p2 p1
rename temp p2
save "Empirical1_data/diversification/sim_rev.dta", replace

use "Empirical1_data/diversification/sim_fwd.dta", clear
append using "Empirical1_data/diversification/sim_rev.dta"
rename p1 main_product_id
rename p2 candidate_product_id

display "双向 similarity 行数:"
count

* --- input top 30 ---
preserve
gsort main_product_id -input_similarity
by main_product_id: gen rank_input = _n
keep if rank_input <= 30
keep main_product_id candidate_product_id input_similarity output_similarity
gen from_input = 1
tempfile top_input
save `top_input'
restore

* --- output top 30 ---
preserve
gsort main_product_id -output_similarity
by main_product_id: gen rank_output = _n
keep if rank_output <= 30
keep main_product_id candidate_product_id input_similarity output_similarity
gen from_output = 1
tempfile top_output
save `top_output'
restore

* --- 并集 ---
use `top_input', clear
append using `top_output'

bysort main_product_id candidate_product_id: gen n_appear = _N
count if n_appear == 2
local both = r(N) / 2
drop n_appear

duplicates drop main_product_id candidate_product_id, force

display ""
display "============================================="
display "Choice Set 构造"
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
display "  重叠:             `both'"

bysort main_product_id: gen n_candidates = _N
summarize n_candidates
display "平均候选数: " %4.1f r(mean)
drop n_candidates from_input from_output

keep main_product_id candidate_product_id input_similarity output_similarity
compress
save "Empirical1_data/diversification/choice_set_union.dta", replace

* --- OTHER：top30 以外产品的平均 similarity，每个主产品一行 ---
use "Empirical1_data/diversification/sim_fwd.dta", clear
append using "Empirical1_data/diversification/sim_rev.dta"
rename p1 main_product_id
rename p2 candidate_product_id

merge m:1 main_product_id candidate_product_id using "Empirical1_data/diversification/choice_set_union.dta"
gen in_top30 = (_merge == 3)
drop _merge

display ""
display "Top30 内产品对:"
count if in_top30 == 1
display "Top30 外产品对:"
count if in_top30 == 0

keep if in_top30 == 0
collapse (mean) input_similarity output_similarity, by(main_product_id)
gen candidate_product_id = "OTHER"
compress
save "Empirical1_data/diversification/choice_set_other.dta", replace

display "OTHER 类（每个主产品一行）:"
count
summarize input_similarity output_similarity


*=====================================================================
* PART 3　构造回归样本
*=====================================================================

* ===== Step 1：具体产品行 =====
use "Empirical1_data/diversification/main_info.dta", clear
joinby main_product_id using "Empirical1_data/diversification/choice_set_union.dta", unmatched(master)
* 原版这里有一行 drop _merge —— joinby 不生成 _merge，已删

display "展开后（仅 top30 候选）:"
count

rename candidate_product_id product_id
merge m:1 firm_id year product_id using "Empirical1_data/diversification/actual_choices.dta", keep(master match)
gen d_chosen = (_merge == 3)
drop _merge

replace outsourcing_percen = . if d_chosen == 0
replace product_has_outsourcing = . if d_chosen == 0

gen d_outsource    = (d_chosen == 1 & product_has_outsourcing == 1)
gen d_self_produce = (d_chosen == 1 & product_has_outsourcing == 0)
replace d_outsource = 0 if d_chosen == 1 & product_has_outsourcing == .
replace d_self_produce = 0 if d_chosen == 1 & product_has_outsourcing == .

* 50% 阈值的另一套定义
gen d_os50 = (d_chosen == 1 & outsourcing_percen >= 0.5 & outsourcing_percen != .)
gen d_sp50 = (d_chosen == 1 & outsourcing_percen <  0.5 & outsourcing_percen != .)

gen is_other = 0
gen ln_firm_output = ln(firm_total_output + 1)
drop actually_chosen product_has_outsourcing firm_total_output

gegen firm_n = group(firm_id)
gegen prod_n = group(product_id)

* firm_id → firm_n 映射，OTHER 行要用
preserve
keep firm_id firm_n
duplicates drop
compress
save "Empirical1_data/diversification/firm_n_map.dta", replace
restore

keep firm_n prod_n year d_chosen d_outsource d_self_produce d_os50 d_sp50 ///
     outsourcing_percen input_similarity output_similarity ///
     ln_firm_output n_products is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/diversification/div_indiv.dta", replace


* ===== Step 2：OTHER 行（每个 firm-year 一行）=====

* 企业实际选了哪些 top30 以外的产品
use "Empirical1_data/diversification/actual_choices.dta", clear
merge m:1 firm_id year using "Empirical1_data/diversification/main_info.dta", ///
    keepusing(main_product_id firm_total_output n_products) keep(match) nogen

rename product_id candidate_product_id
merge m:1 main_product_id candidate_product_id using "Empirical1_data/diversification/choice_set_union.dta"
gen in_top30 = (_merge == 3)
drop _merge
rename candidate_product_id product_id

keep if in_top30 == 0
drop in_top30

display ""
display "企业选了 top30 以外的产品数:"
count

* 汇总到 firm x year：只要选了任意一个 top30 外产品，d_chosen 就是 1
collapse (max) d_chosen = actually_chosen ///
         (mean) avg_os = outsourcing_percen, ///
    by(firm_id year)

gen d_outsource    = (d_chosen == 1 & avg_os >  0)
gen d_self_produce = (d_chosen == 1 & avg_os == 0)
gen d_os50 = (d_chosen == 1 & avg_os >= 0.5)
gen d_sp50 = (d_chosen == 1 & avg_os <  0.5)
rename avg_os outsourcing_percen
replace outsourcing_percen = . if d_chosen == 0

keep firm_id year d_chosen d_outsource d_self_produce ///
     d_os50 d_sp50 outsourcing_percen
tempfile other_chosen
save `other_chosen'

* 从完整 firm-year 列表左连接：没选 top30 外产品的企业，d_chosen = 0
use "Empirical1_data/diversification/main_info.dta", clear
keep firm_id year main_product_id firm_total_output n_products
merge 1:1 firm_id year using `other_chosen', ///
    keepusing(d_chosen d_outsource d_self_produce d_os50 d_sp50 outsourcing_percen)
replace d_chosen       = 0 if _merge == 1
replace d_outsource    = 0 if _merge == 1
replace d_self_produce = 0 if _merge == 1
replace d_os50         = 0 if _merge == 1
replace d_sp50         = 0 if _merge == 1
replace outsourcing_percen = . if _merge == 1
drop _merge

merge m:1 main_product_id using "Empirical1_data/diversification/choice_set_other.dta", ///
    keepusing(input_similarity output_similarity) keep(match master) nogen

gen is_other = 1
gen ln_firm_output = ln(firm_total_output + 1)
drop firm_total_output main_product_id

merge m:1 firm_id using "Empirical1_data/diversification/firm_n_map.dta", keep(match master) nogen
drop firm_id

* OTHER 当成"第 N+1 个产品"，共用一个 prod_n
preserve
use "Empirical1_data/diversification/div_indiv.dta", clear
summarize prod_n
local max_pn = r(max)
restore
gen prod_n = `max_pn' + 1

keep firm_n prod_n year d_chosen d_outsource d_self_produce d_os50 d_sp50 ///
     outsourcing_percen input_similarity output_similarity ///
     ln_firm_output n_products is_other
recast float input_similarity output_similarity ln_firm_output, force
compress
save "Empirical1_data/diversification/div_other.dta", replace

display ""
display "OTHER 行:"
count
summarize d_chosen d_outsource d_self_produce
summarize input_similarity output_similarity


* ===== Step 3：合并成回归样本 =====
use "Empirical1_data/diversification/div_indiv.dta", clear
append using "Empirical1_data/diversification/div_other.dta"

gen input_x_output = input_similarity * output_similarity
gen input_x_fsize  = input_similarity * ln_firm_output
gen output_x_fsize = output_similarity * ln_firm_output
recast float input_x_output input_x_fsize output_x_fsize, force
compress

display ""
display "============================================="
display "回归样本（含 OTHER）:"
count
count if is_other == 0
display "  具体产品: " r(N)
count if is_other == 1
display "  OTHER:   " r(N)
display ""
summarize d_chosen d_outsource d_self_produce
display ""
display "--- 具体产品 ---"
summarize d_chosen input_similarity output_similarity if is_other == 0
display "--- OTHER ---"
summarize d_chosen input_similarity output_similarity if is_other == 1
display "============================================="

save "Empirical1_data/diversification/div_data.dta", replace

* --- 5% 企业子样本，PPML 用（整企业抽，不是抽行）---
set seed 20260324
gegen firm_tag = tag(firm_n)
gen _rand = runiform() if firm_tag == 1
gegen firm_rand = max(_rand), by(firm_n)
drop _rand firm_tag
keep if firm_rand < 0.05
drop firm_rand

display ""
display "5% PPML 子样本:"
count

compress
save "Empirical1_data/diversification/div_data_5pct.dta", replace


*=====================================================================
*   LPM 回归（全样本 div_data.dta）
*=====================================================================

* ===== A. d_chosen —— 论文 §3.4 主表 =====

use "Empirical1_data/diversification/div_data.dta", clear

reg d_chosen input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store a1

reg d_chosen input_similarity output_similarity ///
    ln_firm_output n_products, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store a2

reghdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store a3

reghdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store a4

reghdfe d_chosen input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store a5

reghdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n#year prod_n) vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "Yes", replace
est store a6

esttab a1 a2 a3 a4 a5 a6 ///
    using "Empirical1/results/extensive/A_Product_Choice.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(firm_fe year_fe prod_fe firmyear_fe N r2_a, ///
          labels("Firm FE" "Year FE" "Product FE" "Firm*Year FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("Product Diversification: d_chosen (0/1)") ///
    mtitles("OLS" "+FC" "Firm+Yr" "Firm+Prod+Yr" "+FC" "FirmYr+Prod")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== A2. d_chosen 交互项 =====

use "Empirical1_data/diversification/div_data.dta", clear

reghdfe d_chosen input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local year_fe "Yes", replace
est store ai1

reghdfe d_chosen input_similarity output_similarity ///
    input_x_output ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local year_fe "Yes", replace
est store ai2

reghdfe d_chosen input_similarity output_similarity ///
    input_x_fsize output_x_fsize ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local year_fe "Yes", replace
est store ai3

esttab ai1 ai2 ai3 ///
    using "Empirical1/results/extensive/A2_Choice_Interaction.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ///
          input_x_output input_x_fsize output_x_fsize ///
          ln_firm_output n_products) ///
    stats(firm_fe prod_fe year_fe N r2_a, ///
          labels("Firm FE" "Product FE" "Year FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %12.0fc 3)) ///
    title("Product Choice: Interaction Effects") ///
    mtitles("Baseline" "In*Out" "Sim*Size")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== B. d_outsource =====

use "Empirical1_data/diversification/div_data.dta", clear

reg d_outsource input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store b1

reg d_outsource input_similarity output_similarity ///
    ln_firm_output n_products, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store b2

reghdfe d_outsource input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store b3

reghdfe d_outsource input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store b4

reghdfe d_outsource input_similarity output_similarity, ///
    absorb(firm_n#year prod_n) vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "Yes", replace
est store b5

esttab b1 b2 b3 b4 b5 ///
    using "Empirical1/results/extensive/B_Outsource_Choice.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(firm_fe year_fe prod_fe firmyear_fe N r2_a, ///
          labels("Firm FE" "Year FE" "Product FE" "Firm*Year FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("Product Diversification: d_outsource (0/1)") ///
    mtitles("OLS" "+FC" "Firm+Prod+Yr" "+FC" "FirmYr+Prod")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== C. d_self_produce =====

use "Empirical1_data/diversification/div_data.dta", clear

reg d_self_produce input_similarity output_similarity, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store c1

reg d_self_produce input_similarity output_similarity ///
    ln_firm_output n_products, vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "No", replace
estadd local firmyear_fe "No", replace
est store c2

reghdfe d_self_produce input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store c3

reghdfe d_self_produce input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local firm_fe "Yes", replace
estadd local year_fe "Yes", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "No", replace
est store c4

reghdfe d_self_produce input_similarity output_similarity, ///
    absorb(firm_n#year prod_n) vce(cluster firm_n)
estadd local firm_fe "No", replace
estadd local year_fe "No", replace
estadd local prod_fe "Yes", replace
estadd local firmyear_fe "Yes", replace
est store c5

esttab c1 c2 c3 c4 c5 ///
    using "Empirical1/results/extensive/C_SelfProduce_Choice.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(firm_fe year_fe prod_fe firmyear_fe N r2_a, ///
          labels("Firm FE" "Year FE" "Product FE" "Firm*Year FE" ///
                 "Observations" "Adj. R-sq") ///
          fmt(%s %s %s %s %12.0fc 3)) ///
    title("Product Diversification: d_self_produce (0/1)") ///
    mtitles("OLS" "+FC" "Firm+Prod+Yr" "+FC" "FirmYr+Prod")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== D. 横向对比：Chosen vs Outsource vs Self-Produce =====

use "Empirical1_data/diversification/div_data.dta", clear

reghdfe d_chosen input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_chosen", replace
est store d1

reghdfe d_outsource input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_outsource", replace
est store d2

reghdfe d_self_produce input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_self_produce", replace
est store d3

esttab d1 d2 d3 ///
    using "Empirical1/results/extensive/D_Comparison.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(dv N r2_a, ///
          labels("Dep. Variable" "Observations" "Adj. R-sq") ///
          fmt(%s %12.0fc 3)) ///
    title("Diversification: Chosen vs Outsource vs Self-Produce (LPM, OS>0)") ///
    mtitles("Chosen" "OS>0%" "SP=0%")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== D2. 横向对比：50% 阈值 =====

use "Empirical1_data/diversification/div_data.dta", clear

reghdfe d_chosen input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_chosen", replace
est store d2_1

reghdfe d_os50 input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "OS>=50%", replace
est store d2_2

reghdfe d_sp50 input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "SP<50%", replace
est store d2_3

esttab d2_1 d2_2 d2_3 ///
    using "Empirical1/results/extensive/D2_Comparison_50pct.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(dv N r2_a, ///
          labels("Dep. Variable" "Observations" "Adj. R-sq") ///
          fmt(%s %12.0fc 3)) ///
    title("Diversification: Chosen vs OS>=50% vs SP<50% (LPM)") ///
    mtitles("Chosen" "OS>=50%" "SP<50%")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


* ===== D3. 连续：已选产品的外包比例 =====

use "Empirical1_data/diversification/div_data.dta", clear
keep if d_chosen == 1

reghdfe outsourcing_percen input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "OS share", replace
est store dcont1

reghdfe outsourcing_percen input_similarity output_similarity ///
    ln_firm_output n_products, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "OS share", replace
est store dcont2

esttab dcont1 dcont2 ///
    using "Empirical1/results/extensive/D3_Continuous.txt", replace ///
    $esttab_opts ///
    order(input_similarity output_similarity ln_firm_output n_products) ///
    stats(dv N r2_a, ///
          labels("Dep. Variable" "Observations" "Adj. R-sq") ///
          fmt(%s %12.0fc 3)) ///
    title("Diversification: OS Share Among Chosen Products (Conditional Intensive Margin)") ///
    mtitles("OS share" "+Controls")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"


*=====================================================================
*   PPML 回归（5% 子样本 div_data_5pct.dta）
*=====================================================================

display ""
display "============================================="
display "PPML: 5% 随机企业子样本"
display "============================================="

capture which ppmlhdfe
if _rc {
    ssc install ppmlhdfe, replace
    ssc install ftools, replace
}

* --- PPML: d_chosen ---
use "Empirical1_data/diversification/div_data_5pct.dta", clear
display "PPML 样本量:"
count

ppmlhdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_chosen", replace
estadd local method "PPML", replace
est store p1

esttab p1 using "Empirical1/results/extensive/PPML_d_chosen.txt", replace ///
    $esttab_opts ///
    stats(dv method N, labels("Dep. Variable" "Method" "Observations") ///
          fmt(%s %s %12.0fc)) ///
    title("PPML: d_chosen (5% sample)")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"

* --- PPML: d_outsource ---
use "Empirical1_data/diversification/div_data_5pct.dta", clear

ppmlhdfe d_outsource input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_outsource", replace
estadd local method "PPML", replace
est store p2

esttab p2 using "Empirical1/results/extensive/PPML_d_outsource.txt", replace ///
    $esttab_opts ///
    stats(dv method N, labels("Dep. Variable" "Method" "Observations") ///
          fmt(%s %s %12.0fc)) ///
    title("PPML: d_outsource (5% sample)")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"

* --- PPML: d_self_produce ---
use "Empirical1_data/diversification/div_data_5pct.dta", clear

ppmlhdfe d_self_produce input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local dv "d_self_produce", replace
estadd local method "PPML", replace
est store p3

esttab p3 using "Empirical1/results/extensive/PPML_d_self_produce.txt", replace ///
    $esttab_opts ///
    stats(dv method N, labels("Dep. Variable" "Method" "Observations") ///
          fmt(%s %s %12.0fc)) ///
    title("PPML: d_self_produce (5% sample)")
est clear
clear all
set max_memory ., permanently
global esttab_opts "b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) nogaps compress"

* --- PPML vs LPM，同一子样本对照 ---
use "Empirical1_data/diversification/div_data_5pct.dta", clear

ppmlhdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "PPML", replace
estadd local dv "d_chosen", replace
est store cmp_p1

ppmlhdfe d_outsource input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "PPML", replace
estadd local dv "d_outsource", replace
est store cmp_p2

ppmlhdfe d_self_produce input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "PPML", replace
estadd local dv "d_self_produce", replace
est store cmp_p3

reghdfe d_chosen input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "LPM", replace
estadd local dv "d_chosen", replace
est store cmp_l1

reghdfe d_outsource input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "LPM", replace
estadd local dv "d_outsource", replace
est store cmp_l2

reghdfe d_self_produce input_similarity output_similarity, ///
    absorb(firm_n prod_n year) vce(cluster firm_n)
estadd local method "LPM", replace
estadd local dv "d_self_produce", replace
est store cmp_l3

esttab cmp_p1 cmp_l1 cmp_p2 cmp_l2 cmp_p3 cmp_l3 ///
    using "Empirical1/results/extensive/PPML_vs_LPM.txt", replace ///
    $esttab_opts ///
    stats(method dv N, ///
          labels("Method" "Dep. Variable" "Observations") ///
          fmt(%s %s %12.0fc)) ///
    title("PPML vs LPM Comparison (5% sample)") ///
    mtitles("PPML" "LPM" "PPML" "LPM" "PPML" "LPM")
est clear
clear all
set max_memory ., permanently


*=====================================================================
* E. 覆盖率诊断 —— choice set 抓住了多少实际选择
*=====================================================================

use "Empirical1_data/diversification/div_data.dta", clear

display ""
display "============================================="
display "覆盖率诊断"
display "============================================="

count
local total = r(N)
summarize d_chosen d_outsource d_self_produce

count if d_chosen == 1
local n_chosen = r(N)
count if d_outsource == 1
local n_os = r(N)
count if d_self_produce == 1
local n_sp = r(N)

display ""
display "选择率: " %6.4f (`n_chosen'/`total')
display "已选中:"
display "  外包: " `n_os' " (" %4.1f (`n_os'/`n_chosen'*100) "%)"
display "  自产: " `n_sp' " (" %4.1f (`n_sp'/`n_chosen'*100) "%)"

preserve
use "Empirical1_data/diversification/actual_choices.dta", clear
count
local total_actual = r(N)
restore

display ""
display "实际副产品总数: " `total_actual'
display "被覆盖: " `n_chosen'
display "覆盖率: " %4.1f (`n_chosen'/`total_actual'*100) "%"

display ""
display "--- Similarity: 选中 vs 未选中 ---"
summarize input_similarity output_similarity if d_chosen == 0
summarize input_similarity output_similarity if d_chosen == 1


*=====================================================================
display ""
display "============================================="
display "03_extensive 全部完成"
display "============================================="
display ""
display "回归表 -> Empirical1/results/extensive/"
display "  LPM（全样本）"
display "    A_Product_Choice.txt       d_chosen 基准        6 列  <- 论文 §3.4"
display "    A2_Choice_Interaction.txt  d_chosen 交互项      3 列"
display "    B_Outsource_Choice.txt     d_outsource 基准     5 列"
display "    C_SelfProduce_Choice.txt   d_self_produce 基准  5 列"
display "    D_Comparison.txt           横向对比 OS>0        3 列"
display "    D2_Comparison_50pct.txt    横向对比 OS>=50%     3 列"
display "    D3_Continuous.txt          已选产品外包比例     2 列"
display "  PPML（5% 子样本）"
display "    PPML_d_chosen.txt / PPML_d_outsource.txt / PPML_d_self_produce.txt"
display "    PPML_vs_LPM.txt            同样本对照"
display ""
display "中间数据 -> Empirical1_data/diversification/"
display "    div_data.dta       全样本回归数据"
display "    div_data_5pct.dta  5% PPML 子样本"
display "============================================="

log close
