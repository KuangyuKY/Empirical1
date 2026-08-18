*=====================================================================
* 01_cleaning.do —— 4 个 collapsed 年度表  ->  lenth15_year.dta
*
* 清洗逻辑照搬 IO_Table/io_repro/02_cleaning_pipeline.do，
* 唯一区别：collapse 的 by() 里保留 year。
*   （IO 表口径把 2017+2018 合并成一张表，本项目要年度面板）
*
* 输入（$DATA，只读，不修改）
*   buyer_17_collapsed.dta   购方企业id 项目代码 正开票金额 负开票金额
*   buyer_18_collapsed.dta
*   seller_17_collapsed.dta  销方企业id 项目代码 正开票金额 负开票金额
*   seller_18_collapsed.dta
*   bianma_all.dta           货物和劳务名称 合并编码(19位)
*
* 输出（$OUT）
*   lenth15_year.dta   firm_id year product_id(15位) v is_output
*=====================================================================
clear all
set more off

global DATA "G:/Kuangyu_Temp/Data"                       // 原始数据，只读
global OUT  "G:/Kuangyu_Temp/Outsource/Empirical1_data"  // 所有产物落这里
capture mkdir "$OUT"


*########## 0. 编码表 -> product_id_19 ##########
* VM 上的列名是 product_id(str19)，本地旧版叫 合并编码，两种都兼容
use "$DATA/bianma_all.dta", clear
capture rename 合并编码 product_id
rename product_id product_id_19
capture confirm string variable product_id_19
if _rc tostring product_id_19, replace force
keep product_id_19
duplicates drop
save "$OUT/_codetable19.dta", replace
di as result "编码表 19 位码数: " _N


*########## 1. 四张表：改列名 + 加 year + 打 input_output 标 ##########

* ---- buyer 2017（投入侧）----
use "$DATA/buyer_17_collapsed.dta", clear
rename 购方企业id firm_id
rename 项目代码   product_id
rename 正开票金额 v_positive
rename 负开票金额 v_negative
capture confirm string variable product_id
if _rc tostring product_id, replace force
gen year = 2017
gen input_output = "input"
save "$OUT/_buyer17.dta", replace

* ---- buyer 2018（投入侧）----
use "$DATA/buyer_18_collapsed.dta", clear
rename 购方企业id firm_id
rename 项目代码   product_id
rename 正开票金额 v_positive
rename 负开票金额 v_negative
capture confirm string variable product_id
if _rc tostring product_id, replace force
gen year = 2018
gen input_output = "input"
save "$OUT/_buyer18.dta", replace

* ---- seller 2017（产出侧）----
use "$DATA/seller_17_collapsed.dta", clear
rename 销方企业id firm_id
rename 项目代码   product_id
rename 正开票金额 v_positive
rename 负开票金额 v_negative
capture confirm string variable product_id
if _rc tostring product_id, replace force
gen year = 2017
gen input_output = "output"
save "$OUT/_seller17.dta", replace

* ---- seller 2018（产出侧）----
use "$DATA/seller_18_collapsed.dta", clear
rename 销方企业id firm_id
rename 项目代码   product_id
rename 正开票金额 v_positive
rename 负开票金额 v_negative
capture confirm string variable product_id
if _rc tostring product_id, replace force
gen year = 2018
gen input_output = "output"
save "$OUT/_seller18.dta", replace


*########## 2. append 四份 + 算净值 v ##########
use "$OUT/_buyer17.dta", clear
append using "$OUT/_seller17.dta"
append using "$OUT/_buyer18.dta"
append using "$OUT/_seller18.dta"
gen v = v_positive + v_negative
di as result "append 后行数: " _N


*########## 3. 产品码清洗：数值过滤 + 补 19 位 ##########
generate num_data = real(product_id) if !missing(real(product_id))
drop if num_data < 1
drop if num_data > 7000000000000000000
drop if mod(num_data, 1) != 0

gen product_id_19 = product_id + "0000000000000000000"
replace product_id_19 = substr(product_id_19, 1, 19)

generate num_data_19 = real(product_id_19)
drop if num_data_19 == .
drop if num_data_19 < 1000000000000000000
drop if num_data_19 > 7000000000000000000

keep firm_id year product_id_19 input_output v


*########## 4. 并编码表（只留匹配上的）##########
merge m:1 product_id_19 using "$OUT/_codetable19.dta"
gen product = (_merge == 3)
drop _merge
tab product
keep if product == 1
drop product
rename product_id_19 product_id


*########## 5. 按 19 位 collapse（★ by() 保留 year）+ 去非正值 ##########
collapse (sum) v, by(firm_id product_id input_output year)
drop if v <= 0
save "$OUT/1718_cleaned19_year.dta", replace
di as result "19 位清洗后行数: " _N


*########## 6. 截 15 位 -> lenth15_year（只留有产出的企业）##########
use "$OUT/1718_cleaned19_year.dta", clear
replace product_id = substr(product_id, 1, 15)
gen is_output = (input_output == "output")
bysort firm_id: egen num_outputs = total(is_output)
drop if num_outputs < 1
drop num_outputs input_output
collapse (sum) v, by(firm_id year product_id is_output)
save "$OUT/lenth15_year.dta", replace

di as result "lenth15_year 行数: " _N
count if is_output == 1
di as result "  产出行: " r(N)
count if is_output == 0
di as result "  投入行: " r(N)


*########## 7. 清理中间文件 ##########
erase "$OUT/_buyer17.dta"
erase "$OUT/_buyer18.dta"
erase "$OUT/_seller17.dta"
erase "$OUT/_seller18.dta"

di _n as result "==== 完成：$OUT/lenth15_year.dta ===="
