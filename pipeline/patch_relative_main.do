*=====================================================================
* patch_relative_main.do —— 把 full_data.dta 的两列换成 production 口径
*
*   main_product_output  ->  main_product_production   主产品的 production_value
*   sales_relative_main  ->  production_relative_main  副 production / 主 production
*
* 前置：先跑 patch_relative_main.ipynb 的 Step 1，生成
*       $OUT/main_product_production.dta（12.3M 行查找表）
*
* 为什么用 Stata 不用 pandas：
*   pandas 的 to_stata 会把散在多个 block 的 float64 列合并成一块连续数组，
*   等于要第二份 ~13 GB。Stata 列式存储 + 流式 save，没有这个开销。
*
* 内存：需要能装下整个 full_data（约 19 GB）。装不下就别跑——
*       04 / 05 的回归都不用这两列，等 02 重跑时自然就对了。
*=====================================================================
clear all
set more off

global OUT "G:/Kuangyu_Temp/Outsource/Empirical1_data"

use "$OUT/full_data.dta", clear
di as result "读入: " _N " 行"

drop main_product_output sales_relative_main

merge m:1 firm_id year using "$OUT/main_product_production.dta", nogen

gen production_relative_main = production_value / main_product_production

* 列序对齐 02 的输出
order year firm_id product_id total_output outsourcing_value production_value ///
      outsourcing_percen sales_percen production_relative_main is_main main_product ///
      main_product_production input_similarity output_similarity firm_total_output ///
      firm_total_outsource n_products outsourcing_intensity is_intermediary is_outsourcing

compress
save "$OUT/full_data.dta", replace

* ---- 检查：应恒 <= 1，主产品行恰好 = 1 ----
summarize production_relative_main, detail
count if production_relative_main > 1 + 1e-9 & !missing(production_relative_main)
di as result "> 1 的行数: " r(N) "（应为 0）"
count if is_main == 1 & abs(production_relative_main - 1) > 1e-9 & !missing(production_relative_main)
di as result "主产品行不等于 1 的: " r(N) "（应为 0）"

di _n as result "==== 完成 ===="
