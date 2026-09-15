# Alcohol variable investigation
# Paper Q1-Q4: 3.24+-18.67, 4.29+-39.96, 2.99+-20.49, 3.33+-29.64 (P=0.187, NOT significant)
# Mine (0-impute non-drinkers, filter 777/999): 2.52+-2.55, 2.24+-2.38, 1.99+-2.20, 1.58+-2.11
# Teammate: 2.89+-2.50, 2.68+-2.34, 2.54+-2.14, 2.29+-2.15

library(haven)
library(survey)

d <- readRDS(file.path("data", "analytic_sample.rds"))

read_alq_raw <- function(cycle) {
  fn <- if (cycle == "P") "data/P_ALQ.XPT" else file.path("data", paste0("ALQ_", cycle, ".XPT"))
  x <- read_xpt(fn)
  novar <- if (cycle == "P") "ALQ121" else "ALQ101"
  out <- data.frame(SEQN = x$SEQN, NODRINK = x[[novar]], ALQ130 = x$ALQ130, cycle = cycle)
  out
}
alq_all <- do.call(rbind, lapply(c("G", "H", "I", "P"), read_alq_raw))

cat("Raw ALQ130 value distribution (all cycles pooled), top values:\n")
print(table(alq_all$ALQ130, useNA = "ifany")[order(-as.numeric(names(table(alq_all$ALQ130, useNA = "ifany"))))][1:15])
cat("\nMax ALQ130:", max(alq_all$ALQ130, na.rm = TRUE), "\n")
cat("Values >= 100:\n")
print(table(alq_all$ALQ130[alq_all$ALQ130 >= 100], useNA = "ifany"))
cat("Values in 777-999 range:\n")
print(table(alq_all$ALQ130[alq_all$ALQ130 %in% c(777, 999)]))

d2 <- merge(d[, c("SEQN", "wwi_q", "WTCOMB", "psu_c", "strata_c")], alq_all, by = "SEQN", all.x = TRUE)

test_alc <- function(label, values) {
  d2$alc <- values
  des <- svydesign(ids = ~psu_c, strata = ~strata_c, weights = ~WTCOMB, data = d2, nest = TRUE)
  sub <- subset(des, !is.na(alc))
  m <- svyby(~alc, ~wwi_q, sub, svymean, na.rm = TRUE)
  v <- svyby(~alc, ~wwi_q, sub, svyvar, na.rm = TRUE)
  cat(sprintf("\n%s  (n=%d)\n", label, sum(!is.na(d2$alc))))
  print(data.frame(q = m$wwi_q, mean = round(m$alc, 2), sd = round(sqrt(v$alc), 2)))
}

# H_A: current approach - impute 0 for non-drinkers, filter 777/999
alc_A <- ifelse(alq_all$ALQ130 %in% c(777, 999), NA, alq_all$ALQ130)
alc_A[alq_all$NODRINK %in% c(0, 2)] <- 0
test_alc("H_A: 0-impute non-drinkers, filter 777/999 [current]", alc_A[match(d2$SEQN, alq_all$SEQN)])

# H_B: raw ALQ130 as-is, no 0-imputation, filter 777/999 (drop non-drinkers as NA)
alc_B <- ifelse(alq_all$ALQ130 %in% c(777, 999), NA, alq_all$ALQ130)
test_alc("H_B: raw ALQ130, no 0-impute, filter 777/999", alc_B[match(d2$SEQN, alq_all$SEQN)])

# H_C: raw ALQ130 as-is, NO filtering at all (leave 777/999 as literal numbers)
alc_C <- alq_all$ALQ130
test_alc("H_C: raw ALQ130, NO filtering (777/999 left as literal values)", alc_C[match(d2$SEQN, alq_all$SEQN)])

# H_D: 0-impute non-drinkers, but do NOT filter 777/999
alc_D <- alq_all$ALQ130
alc_D[alq_all$NODRINK %in% c(0, 2)] <- 0
test_alc("H_D: 0-impute non-drinkers, NO filtering of 777/999", alc_D[match(d2$SEQN, alq_all$SEQN)])
