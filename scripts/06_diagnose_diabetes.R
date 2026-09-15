# Diabetes coding investigation
# Paper Q1-Q4 Yes%: 3.01, 8.60, 14.85, 26.76 (unweighted N/A - these are weighted %)
# Mine (DIQ010: 1=Yes,2=No; else NA): 2.01, 7.13, 11.93, 24.38
# Teammate (closer to paper): 3.05, 8.77, 15.06, 26.93

d <- readRDS(file.path("data", "analytic_sample.rds"))
library(haven)

read_diq <- function(cycle) {
  fn <- if (cycle == "P") "data/P_DIQ.XPT" else file.path("data", paste0("DIQ_", cycle, ".XPT"))
  read_xpt(fn)[, c("SEQN", "DIQ010")]
}
diq_all <- do.call(rbind, lapply(c("G", "H", "I", "P"), read_diq))

cat("DIQ010 raw distribution (full pool):\n")
print(table(diq_all$DIQ010, useNA = "ifany"))

d2 <- merge(d[, c("SEQN", "wwi_q", "WTCOMB", "psu_c", "strata_c")], diq_all, by = "SEQN", all.x = TRUE)
cat("\nDIQ010 distribution within analytic sample:\n")
print(table(d2$DIQ010, useNA = "ifany"))

library(survey)
test_coding <- function(label, yes_codes, no_codes) {
  d2$diab <- factor(ifelse(d2$DIQ010 %in% yes_codes, "Yes",
                     ifelse(d2$DIQ010 %in% no_codes, "No", NA)),
                     levels = c("Yes", "No"))
  des <- svydesign(ids = ~psu_c, strata = ~strata_c, weights = ~WTCOMB, data = d2, nest = TRUE)
  sub <- subset(des, !is.na(diab))
  p <- svyby(~diab, ~wwi_q, sub, svymean, na.rm = TRUE)
  yes_pct <- 100 * p$diabYes[match(c("Q1","Q2","Q3","Q4"), p$wwi_q)]
  cat(sprintf("%-45s Yes%%: %s  (n non-missing=%d)\n", label,
              paste(sprintf("%.2f", yes_pct), collapse = ", "), sum(!is.na(d2$diab))))
}

test_coding("H1: Yes={1} No={2}              [current]", 1, 2)
test_coding("H2: Yes={1,3} No={2}  (borderline->Yes)", c(1, 3), 2)
test_coding("H3: Yes={1} No={2,3}  (borderline->No)", 1, c(2, 3))
test_coding("H4: Yes={1} No={2,3,7,9} (DK/refused->No)", 1, c(2, 3, 7, 9))
test_coding("H5: Yes={1} No={2,9} (DK->No, borderline excl)", 1, c(2, 9))
