# Triglycerides / LDL-C use the fasting subsample -> need WTSAF2YR / WTSAFPRP,
# not the MEC exam weight. Paper TG Q1-Q4: 107.49, 117.45, 124.53, 126.97
# Paper LDL Q1-Q4: 109.30, 113.27, 113.47, 111.61
# Current (MEC weight) TG: 93.86, 117.76, 132.16, 136.11
# Current (MEC weight) LDL: 106.50, 115.23, 116.24, 111.23

library(haven)
library(survey)

d <- readRDS(file.path("data", "analytic_sample.rds"))

read_trig <- function(cycle) {
  fn <- if (cycle == "P") "data/P_TRIGLY.XPT" else file.path("data", paste0("TRIGLY_", cycle, ".XPT"))
  x <- read_xpt(fn)
  wt_var <- if (cycle == "P") "WTSAFPRP" else "WTSAF2YR"
  x <- x[, c("SEQN", wt_var, "LBXTR", "LBDLDL")]
  names(x)[names(x) == wt_var] <- "WTSAF"
  x$cycle <- cycle
  x
}
trig_all <- do.call(rbind, lapply(c("G", "H", "I", "P"), read_trig))

d2 <- merge(d[, c("SEQN", "wwi_q", "psu_c", "strata_c")], trig_all, by = "SEQN", all.x = TRUE)

period_years <- c(G = 2, H = 2, I = 2, P = 3.2)
total_years <- sum(period_years)
d2$WTSAFCOMB <- d2$WTSAF * (period_years[d2$cycle] / total_years)
d2$WTSAFCOMB[is.na(d2$WTSAFCOMB)] <- 0

cat("N with non-missing fasting weight & TG:", sum(!is.na(d2$WTSAFCOMB) & d2$WTSAFCOMB > 0 & !is.na(d2$LBXTR)), "\n")

des_saf <- svydesign(ids = ~psu_c, strata = ~strata_c, weights = ~WTSAFCOMB, data = d2, nest = TRUE)

sub_tr <- subset(des_saf, !is.na(LBXTR) & WTSAFCOMB > 0)
m_tr <- svyby(~LBXTR, ~wwi_q, sub_tr, svymean, na.rm = TRUE)
v_tr <- svyby(~LBXTR, ~wwi_q, sub_tr, svyvar, na.rm = TRUE)
cat("\nTG with fasting weight:\n")
print(data.frame(q = m_tr$wwi_q, mean = round(m_tr$LBXTR, 2), sd = round(sqrt(v_tr$LBXTR), 2)))

sub_ld <- subset(des_saf, !is.na(LBDLDL) & WTSAFCOMB > 0)
m_ld <- svyby(~LBDLDL, ~wwi_q, sub_ld, svymean, na.rm = TRUE)
v_ld <- svyby(~LBDLDL, ~wwi_q, sub_ld, svyvar, na.rm = TRUE)
cat("\nLDL with fasting weight:\n")
print(data.frame(q = m_ld$wwi_q, mean = round(m_ld$LBDLDL, 2), sd = round(sqrt(v_ld$LBDLDL), 2)))
