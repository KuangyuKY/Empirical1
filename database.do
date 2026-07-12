

use "G:\Kuangyu_Temp\single_product\1718_total_cleaned_by_year1.dta", clear
cd "G:\Kuangyu_Temp\Outsource"

collapse (sum) v, by (firm_id product_id input_output year)
drop if v <= 0
save 1718_total_cleaned1, replace

replace product_id = substr(product_id, 1, 15)
bysort firm_id (product_id): gen is_output =  (input_output == "output")
bysort firm_id: egen num_outputs = total (is_output)
drop if num_outputs<1
keep firm_id year product_id v is_output
save lenth15, replace