## paper_tables.R ----------------------------------------------------------
## Numbers printed in Li et al. 2023 (BMC Public Health 23:1122), typed in
## by hand from the PDF (pages 4-7) so the step-A scripts (00-02) can work
## without NHANES. Values are as printed: not recomputed, not corrected.
## The ledger (output/tables/ledger.csv) is the authoritative copy for
## comparison with our results; this file only feeds the paper-only checks.
##
## t23     Tables 2 and 3: cases/total and OR (95% CI) for Models 1-3.
##         Reference rows have or = 1 and empty CIs.
##         Table 2 strata: all / nonsmoking / smoking. Table 3: age<45 / age>=45.
## ptrend  P-trend as printed, per table x exposure x stratum x model.
## t1cat   Table 1 categorical rows: n and weighted % per group.
## t1cont  Table 1 continuous rows: weighted mean (SE) per group, p.
## t1p     Table 1 p-value per categorical variable.
##
## source("R/paper_tables.R")
## ------------------------------------------------------------------------

t23 <- read.csv(strip.white = TRUE, text = "
table,exposure,stratum,level,cases,total,or1,lo1,hi1,or2,lo2,hi2,or3,lo3,hi3
Table 2,oral,all,Excellent/Very good,3185,6769,1,,,1,,,1,,
Table 2,oral,all,Good,3757,7536,1.23,1.12,1.35,1.14,1.03,1.26,1.13,1.02,1.27
Table 2,oral,all,Fair,2620,4994,1.48,1.32,1.65,1.32,1.17,1.49,1.30,1.15,1.47
Table 2,oral,all,Poor,1455,2501,1.84,1.58,2.15,1.49,1.24,1.79,1.48,1.22,1.79
Table 2,oral,nonsmoking,Excellent/Very good,1801,4151,1,,,1,,,1,,
Table 2,oral,nonsmoking,Good,2004,4320,1.19,1.03,1.38,1.12,0.99,1.27,1.12,0.98,1.27
Table 2,oral,nonsmoking,Fair,1293,2529,1.20,1.02,1.42,1.51,1.27,1.79,1.49,1.26,1.77
Table 2,oral,nonsmoking,Poor,521,882,1.49,1.22,1.82,1.67,1.29,2.16,1.62,1.24,2.12
Table 2,oral,smoking,Excellent/Very good,1384,2618,1,,,1,,,1,,
Table 2,oral,smoking,Good,1753,3216,1.22,1.07,1.38,1.12,0.96,1.31,1.13,0.96,1.33
Table 2,oral,smoking,Fair,1327,2465,1.73,1.49,2.02,1.11,0.94,1.30,1.11,0.93,1.32
Table 2,oral,smoking,Poor,934,1619,2.33,1.88,2.89,1.29,1.02,1.63,1.31,1.03,1.67
Table 2,perio,all,No,8839,17717,1,,,1,,,1,,
Table 2,perio,all,Yes,2178,4083,1.35,1.22,1.49,1.20,1.08,1.34,1.21,1.09,1.35
Table 2,perio,nonsmoking,No,4664,10018,1,,,1,,,1,,
Table 2,perio,nonsmoking,Yes,955,1864,1.41,1.20,1.66,1.19,0.99,1.44,1.22,1.01,1.47
Table 2,perio,smoking,No,4175,7699,1,,,1,,,1,,
Table 2,perio,smoking,Yes,1223,2219,1.24,1.06,1.44,1.14,0.98,1.34,1.16,0.98,1.37
Table 3,oral,age<45,Excellent/Very good,415,2053,1,,,1,,,1,,
Table 3,oral,age<45,Good,552,2298,1.23,1.04,1.46,1.12,0.94,1.34,1.11,0.93,1.33
Table 3,oral,age<45,Fair,438,1598,1.50,1.25,1.80,1.32,1.11,1.58,1.27,1.05,1.53
Table 3,oral,age<45,Poor,218,640,2.14,1.60,2.86,1.81,1.35,2.41,1.71,1.29,2.28
Table 3,oral,age>=45,Excellent/Very good,2770,4716,1,,,1,,,1,,
Table 3,oral,age>=45,Good,3205,5238,1.16,1.05,1.29,1.11,0.99,1.24,1.10,0.98,1.24
Table 3,oral,age>=45,Fair,2182,3396,1.33,1.15,1.53,1.26,1.08,1.45,1.25,1.07,1.46
Table 3,oral,age>=45,Poor,1237,1861,1.45,1.25,1.68,1.31,1.11,1.54,1.29,1.07,1.55
Table 3,perio,age<45,No,1243,5381,1,,,1,,,1,,
Table 3,perio,age<45,Yes,380,1208,1.71,1.43,2.04,1.52,1.29,1.81,1.51,1.27,1.79
Table 3,perio,age>=45,No,7596,12336,1,,,1,,,1,,
Table 3,perio,age>=45,Yes,1798,2875,1.08,0.96,1.21,1.05,0.93,1.18,1.05,0.92,1.20
")

ptrend <- read.csv(strip.white = TRUE, text = "
table,exposure,stratum,model,p_text
Table 2,oral,all,1,<0.001
Table 2,oral,all,2,<0.001
Table 2,oral,all,3,<0.001
Table 2,oral,nonsmoking,1,<0.001
Table 2,oral,nonsmoking,2,<0.001
Table 2,oral,nonsmoking,3,0.032
Table 2,oral,smoking,1,<0.001
Table 2,oral,smoking,2,0.03
Table 2,oral,smoking,3,0.013
Table 2,perio,all,1,<0.001
Table 2,perio,all,2,<0.001
Table 2,perio,all,3,<0.001
Table 2,perio,nonsmoking,1,<0.001
Table 2,perio,nonsmoking,2,0.066
Table 2,perio,nonsmoking,3,0.041
Table 2,perio,smoking,1,0.006
Table 2,perio,smoking,2,0.097
Table 2,perio,smoking,3,0.080
Table 3,oral,age<45,1,<0.001
Table 3,oral,age<45,2,<0.001
Table 3,oral,age<45,3,<0.001
Table 3,oral,age>=45,1,<0.001
Table 3,oral,age>=45,2,<0.001
Table 3,oral,age>=45,3,0.001
Table 3,perio,age<45,1,<0.001
Table 3,perio,age<45,2,<0.001
Table 3,perio,age<45,3,<0.001
Table 3,perio,age>=45,1,0.21
Table 3,perio,age>=45,2,0.444
Table 3,perio,age>=45,3,0.444
")

## Table 1, categorical rows. n_* unweighted, pct_* weighted, as printed.
t1cat <- read.csv(strip.white = TRUE, text = "
variable,level,n_non,pct_non,n_htn,pct_htn
Sex,Male,5140,46.74,5412,48.93
Sex,Female,5643,53.26,5606,51.07
Race,Mexican American,1753,9.21,1283,5.90
Race,Other Hispanic,1193,6.14,1060,4.90
Race,Non-Hispanic White,4363,67.38,4469,68.23
Race,Non-Hispanic Black,1742,8.35,2964,13.68
Race,Other/Multi-racial,1732,8.91,1241,7.29
Smoking,Yes,4520,42.01,5398,49.76
Smoking,No,6263,57.99,5619,50.24
Periodontal,Yes,1905,16.47,2178,19.92
Periodontal,No,8878,83.53,8839,80.08
Oral,Excellent/Very good,3584,40.87,3185,34.83
Oral,Good,3779,34.00,3757,34.00
Oral,Fair,2374,17.53,2620,19.91
Oral,Poor,1046,7.60,1455,11.27
Education,<High school,2374,13.77,2923,17.13
Education,High school,2147,19.45,2669,25.11
Education,>High school,6252,66.74,5407,57.66
Education,Missing,10,0.01,18,0.11
BMI,<18.5,232,1.83,312,2.41
BMI,18.5-24.9,3330,31.28,1949,16.17
BMI,25-29.9,3757,35.15,3450,31.41
BMI,>=30,3440,31.51,5286,49.83
BMI,Missing,24,0.23,20,0.18
Sleep,<7,7679,68.23,7672,67.52
Sleep,7-9,2737,28.93,2747,27.53
Sleep,>9,367,2.84,598,4.95
Alcohol,No drinks,337,3.07,615,4.87
Alcohol,<=1 drink/week,4745,45.21,4039,39.46
Alcohol,>1 drink/week,2145,25.24,2072,23.82
Alcohol,Missing,3556,26.48,4291,31.84
Physical activity,Inactive,4390,44.76,3976,41.37
Physical activity,Active,6384,55.20,7037,58.62
Physical activity,Missing,9,0.05,4,0.01
History of CVD,Yes,537,4.31,2257,17.90
History of CVD,No,10218,95.53,8681,81.54
History of CVD,Missing,28,0.16,79,0.55
Diabetes,Yes,874,5.79,2872,21.86
Diabetes,No,732,6.93,1232,12.00
Diabetes,Missing,9177,87.28,6913,66.14
")

## Table 1, continuous rows: weighted mean (SE) per group, as printed.
t1cont <- read.csv(strip.white = TRUE, text = "
variable,mean_non,se_non,mean_htn,se_htn,p_text
Age,47.95,0.24,59.04,0.21,<0.001
Total cholesterol,197.71,0.67,195.03,0.80,<0.001
Triglyceride,146.27,1.85,172.62,1.90,<0.001
Creatinine,0.85,0.00,0.95,0.01,<0.001
HDL,55.11,0.31,52.64,0.29,<0.001
HbA1c,5.55,0.01,5.98,0.01,<0.001
Sodium,3575.03,25.86,3476.48,25.77,<0.001
Fat,85.55,0.66,81.87,0.63,<0.001
")

## Table 1, p-value per categorical variable, as printed.
t1p <- read.csv(strip.white = TRUE, text = "
variable,p_text
Sex,0.015
Race,<0.001
Smoking,<0.001
Periodontal,<0.001
Oral,<0.001
Education,<0.001
BMI,<0.001
Sleep,<0.001
Alcohol,<0.001
Physical activity,<0.001
History of CVD,<0.001
Diabetes,<0.001
")

N_NON <- 10783L   # Table 1 header, non-hypertension
N_HTN <- 11017L   # Table 1 header, hypertension
N_ALL <- 21800L
