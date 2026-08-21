# 新旧 `full_data.dta` 对比报告

生成时间：2026-08-19 00:10

- 旧：`G:\Kuangyu_Temp\Outsource\full_data.dta`
- 新：`G:\Kuangyu_Temp\Outsource\Empirical1_data\full_data.dta`

主产品口径：旧 = `total_output` 最大，新 = `production_value` 最大。
受此影响的列（`is_main` / `main_product_output` / `sales_relative_main` /
`input_similarity` / `output_similarity`）差异属预期。

## 1 规模

```
                    旧         新    差     差%
行数           90296650  90297401  751  0.001
企业数           7191877   7191900   23  0.000
产品数              2778      2778    0  0.000
firm-year 数  12339537  12339578   41  0.000

分年:
           旧行数       新行数     旧企业数     新企业数  行数差  企业数差
year                                                 
2017  40884935  40885627  5719292  5719322  692    30
2018  49411715  49411774  6620245  6620256   59    11

企业集合:
两边都有          0
仅旧有     7191877
仅新有     7191900
```

## 2 列集

```
旧 30 列 | 新 30 列 | 相同 = True
仅旧有: []
仅新有: []
```

## 3 数值列总和

```
应当一致的列中的异常:
                                    旧             新      rel_diff note
year                     1.821778e+11  1.821793e+11  8.315099e-06     
total_output             4.192567e+14  4.192571e+14  1.086691e-06     
production_value         2.684758e+14  2.684762e+14  1.697341e-06     
outsourcing_percen       2.346131e+07  2.346148e+07  7.160741e-06     
sales_percen             1.233954e+07  1.233958e+07  3.322653e-06     
firm_total_output        1.385214e+16  1.385235e+16  1.502581e-05     
firm_total_outsource     5.543867e+15  5.543906e+15  7.072125e-06     
n_products               6.393973e+09  6.394029e+09  8.830973e-06     
outsourcing_intensity    2.488804e+07  2.488816e+07  4.779850e-06     
is_intermediary          2.864264e+06  2.864284e+06  6.982597e-06     
is_outsourcing           7.542093e+07  7.542138e+07  6.006290e-06     
total_output_p           6.767844e+19  6.767918e+19  1.096298e-05     
total_outsourcing_p      2.022618e+19  2.022635e+19  8.542530e-06     
total_production_p       4.745226e+19  4.745283e+19  1.199468e-05     
num_years                1.805933e+08  1.805948e+08  8.317031e-06     
num_firms                1.054959e+13  1.054975e+13  1.528007e-05     
num_firms_outsourcing    4.877710e+12  4.877784e+12  1.516272e-05     
avg_output_per_firm      5.573152e+14  5.573152e+14  1.346028e-08     
avg_output_per_year      3.383922e+19  3.383959e+19  1.096298e-05     
pct_firms_outsourcing    3.594112e+07  3.594138e+07  7.121872e-06     
outsourcing_intensity_p  1.876566e+07  1.876579e+07  7.331171e-06     

全列:
                                    旧             新      rel_diff         note
year                     1.821778e+11  1.821793e+11  8.320000e-06             
total_output             4.192567e+14  4.192571e+14  1.090000e-06             
outsourcing_value        1.507809e+14  1.507809e+14  0.000000e+00             
production_value         2.684758e+14  2.684762e+14  1.700000e-06             
outsourcing_percen       2.346131e+07  2.346148e+07  7.160000e-06             
sales_percen             1.233954e+07  1.233958e+07  3.320000e-06             
sales_relative_main      1.824201e+07  1.621005e+14  8.886113e+06  预期不同(主产品口径)
is_main                  1.233954e+07  1.233958e+07  3.320000e-06  预期不同(主产品口径)
main_product_output      7.505524e+15  6.646056e+15  1.145114e-01  预期不同(主产品口径)
input_similarity         3.268500e+07  3.275889e+07  2.260560e-03  预期不同(主产品口径)
output_similarity        2.449329e+07  2.413324e+07  1.469968e-02  预期不同(主产品口径)
firm_total_output        1.385214e+16  1.385235e+16  1.503000e-05             
firm_total_outsource     5.543867e+15  5.543906e+15  7.070000e-06             
n_products               6.393973e+09  6.394029e+09  8.830000e-06             
outsourcing_intensity    2.488804e+07  2.488816e+07  4.780000e-06             
is_intermediary          2.864264e+06  2.864284e+06  6.980000e-06             
is_outsourcing           7.542093e+07  7.542138e+07  6.010000e-06             
total_output_p           6.767844e+19  6.767918e+19  1.096000e-05             
total_outsourcing_p      2.022618e+19  2.022635e+19  8.540000e-06             
total_production_p       4.745226e+19  4.745283e+19  1.199000e-05             
num_years                1.805933e+08  1.805948e+08  8.320000e-06             
num_firms                1.054959e+13  1.054975e+13  1.528000e-05             
num_firms_outsourcing    4.877710e+12  4.877784e+12  1.516000e-05             
avg_output_per_firm      5.573152e+14  5.573152e+14  1.000000e-08             
avg_output_per_year      3.383922e+19  3.383959e+19  1.096000e-05             
pct_firms_outsourcing    3.594112e+07  3.594138e+07  7.120000e-06             
outsourcing_intensity_p  1.876566e+07  1.876579e+07  7.330000e-06             
```

## 4 关键统计量

```
                        旧             新          差
firm-year 数  1.233954e+07  1.233958e+07  41.000000
中介占比         6.237000e-02  6.237000e-02   0.000000
外包企业占比       5.556500e-01  5.556480e-01  -0.000002
平均外包强度       2.081740e-01  2.081740e-01  -0.000000
总产出(万亿)      4.192567e+02  4.192571e+02   0.000456
```
