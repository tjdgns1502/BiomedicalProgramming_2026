# Test whether the paper's "SD" column for skewed labs is actually the weighted SE
library(survey)
d <- readRDS(file.path("data", "analytic_sample.rds"))
des <- svydesign(ids = ~psu_c, strata = ~strata_c, weights = ~WTCOMB, data = d, nest = TRUE)

check_se <- function(v, label, paper_sd) {
  sub <- subset(des, !is.na(get(v)))
  m <- svyby(as.formula(paste0("~", v)), ~wwi_q, sub, svymean, na.rm = TRUE)
  cat(sprintf("\n%s\n", label))
  print(names(m))
  print(m)
}

check_se("LBXTR", "Triglycerides", c(63.03, 67.70, 80.28, 61.62))
check_se("LBDLDL", "LDL-C", c(22.37, 23.74, 24.32, 24.87))
check_se("RIDAGEYR", "Age (sanity check - SD should be large & match well already)", c(13.45, 15.05, 15.90, 16.14))
