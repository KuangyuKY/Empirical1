* ============================================================
* database.do —— 原始交易数据 → lenth15
* 超大原始文件的 collapse 在 Stata 里做（VM 能开、精确、无分块问题）
* 由 notebook 通过 StataMP-64 /e do 调用
* 产出：G:\Kuangyu_Temp\Outsource\lenth15.dta
* ============================================================

use "G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta", clear
cd "G:\Kuangyu_Temp\Outsource"

* 1) 聚合到 firm × product × input_output × year（精确求和，红冲对冲）
collapse (sum) v, by(firm_id product_id input_output year)
drop if v <= 0
save 1718_total_cleaned1, replace

* 2) 截前 15 位、标记产出、仅保留至少有一条产出记录的企业
replace product_id = substr(product_id, 1, 15)
bysort firm_id (product_id): gen is_output = (input_output == "output")
bysort firm_id: egen num_outputs = total(is_output)
drop if num_outputs < 1
keep firm_id year product_id v is_output
save lenth15, replace
