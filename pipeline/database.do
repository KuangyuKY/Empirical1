* ============================================================
* database.do —— 原始交易数据 → lenth15
* 超大原始文件的 collapse 在 Stata 里做（VM 能开、精确、无分块问题）
* 由 notebook 通过 StataMP-64 /e do 调用
*
* 路径约定：
*   代码       G:\Kuangyu_Temp\Outsource\Empirical1\   （git 同步，两边共享）
*   生成数据   G:\Kuangyu_Temp\Outsource\replicate\    （只在 VM，不进 git）
*   原始/输入  G:\Kuangyu_Temp\single_product\ 、 G:\Kuangyu_Temp\Outsource\
*
* 产出：G:\Kuangyu_Temp\Outsource\replicate\lenth15.dta
* ============================================================

* 原始（已按年清洗）交易数据 —— 输入，保持原位
use "G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta", clear

* 所有生成数据落到 replicate 数据文件夹
capture mkdir "G:\Kuangyu_Temp\Outsource\replicate"
cd "G:\Kuangyu_Temp\Outsource\replicate"

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
