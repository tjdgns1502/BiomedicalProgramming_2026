# v2 of 03_table1_stats.R - supersedes it for final results.
# Keeps 03_table1_stats.R untouched (v1, first pass) so the revision from v1
# to v2 stays visible as a diff between two files, not a silent in-place edit.
# Reads data/analytic_sample_v2.rds (built by 12_build_table1_v2.R) and writes
# output/table1_v2.csv, so v1's output/table1.csv is untouched too.
#
# Compute survey-weighted Table 1 (characteristics by WWI quartile)

library(survey)

d <- readRDS(file.path("data", "analytic_sample_v2.rds"))
d$q_num <- as.numeric(d$wwi_q)

# ADDED IN v2: mean imputation for 5 continuous covariates.
# A teammate's independent reproduction (Teammate_analysis/R/06_diagnose_discrepancies.R,
# "검정 B/D") found the paper mean-imputed missing values of these 5 continuous
# covariates with the (unweighted) overall sample mean before computing Table 1
# stats, rather than doing available-case analysis (what v1 / 03_table1_stats.R
# did). Evidence: for Triglycerides/LDL-C (~54% missing - fasting subsample
# only) and PIR/HDL-C/Total cholesterol (~5-10% missing), the paper's SD is
# smaller than the available-case SD by almost exactly sqrt(observed fraction)
# - the signature of mean imputation. Average alcohol consumption is NOT
# imputed (available-case, per the paper).
impute_vars <- c("INDFMPIR", "LBXTR", "LBDLDL", "LBDHDD", "LBXTC")
for (v in impute_vars) {
  d[[v]][is.na(d[[v]])] <- mean(d[[v]], na.rm = TRUE)
}

des <- svydesign(
  ids = ~psu_c, strata = ~strata_c, weights = ~WTCOMB,
  data = d, nest = TRUE
)

fmt1 <- function(x, digits = 2) formatC(x, format = "f", digits = digits)

# ---- Continuous variables: weighted mean +/- SD, p from weighted linear regression ----
cont_vars <- c(
  Age = "RIDAGEYR", PIR = "INDFMPIR", Weight = "BMXWT",
  `Average alcohol consumption` = "ALCOHOL",
  Triglycerides = "LBXTR", `HDL-C` = "LBDHDD", `LDL-C` = "LBDLDL",
  `Total cholesterol` = "LBXTC", BMI = "BMXBMI", `Waist circumference` = "BMXWAIST"
)

cont_results <- list()
for (label in names(cont_vars)) {
  v <- cont_vars[[label]]
  sub <- subset(des, !is.na(get(v)))
  means <- svyby(as.formula(paste0("~", v)), ~wwi_q, sub, svymean, na.rm = TRUE)
  vars  <- svyby(as.formula(paste0("~", v)), ~wwi_q, sub, svyvar, na.rm = TRUE)
  sds <- sqrt(vars[[v]])
  cellstr <- paste0(fmt1(means[[v]]), " ± ", fmt1(sds))

  # CHANGED IN v2: P-value is a simple weighted linear regression F-test
  # (lm with weights=WTCOMB), NOT the complex-survey-design F-test that v1
  # used (svyglm/regTermTest). Verified against the one paper P-value precise
  # enough to distinguish the two methods (Average alcohol consumption,
  # P=0.187): only the simple weighted-lm F-test reproduces it exactly - the
  # design-based test gives a different value. See
  # Teammate_analysis/R/05_compare_table1.R ("p_method").
  dv <- d[!is.na(d[[v]]), ]
  fit <- lm(as.formula(paste0(v, " ~ wwi_q")), data = dv, weights = WTCOMB)
  pval <- anova(fit)["wwi_q", "Pr(>F)"]

  cont_results[[label]] <- c(cellstr, format.pval(pval, digits = 3, eps = 0.001))
}

# ---- Categorical variables: weighted %, p from weighted chi-square ----
cat_vars <- list(
  Sex = "sex", `Race/ethnicity` = "race", `Education level` = "education",
  Smoking = "smoking", Diabetes = "diabetes", `High blood pressure` = "hbp",
  `Coronary heart disease` = "chd", Cancer = "cancer", Stroke = "stroke"
)

cat_results <- list()
for (label in names(cat_vars)) {
  v <- cat_vars[[label]]
  sub <- subset(des, !is.na(get(v)))
  props <- svyby(as.formula(paste0("~", v)), ~wwi_q, sub, svymean, na.rm = TRUE)
  lvls <- levels(d[[v]])
  # rows = levels, cols = quartiles (Q1..Q4)
  pct <- sapply(lvls, function(l) {
    fmt1(100 * props[[paste0(v, l)]][match(c("Q1", "Q2", "Q3", "Q4"), props$wwi_q)])
  })
  pct <- t(pct)  # levels x quartiles

  test <- svychisq(as.formula(paste0("~", v, " + wwi_q")), sub, statistic = "Chisq")
  pval <- test$p.value

  cat_results[[label]] <- list(levels = lvls, pct = pct, p = format.pval(pval, digits = 3, eps = 0.001))
}

# ---- N per quartile ----
n_per_q <- table(d$wwi_q)

# ---- Assemble & print ----
cat("Table 1 (v2). Basic characteristics of participants by weight-adjusted waist index quartile\n")
cat(sprintf("%-30s %10s %10s %10s %10s %10s\n", "Characteristic", "Q1", "Q2", "Q3", "Q4", "P value"))
cat(sprintf("%-30s %10s %10s %10s %10s\n", "", paste0("N=", n_per_q[1]), paste0("N=", n_per_q[2]),
            paste0("N=", n_per_q[3]), paste0("N=", n_per_q[4])))

cat(sprintf("%-30s %10s %10s %10s %10s %10s\n", "Age (years)",
            cont_results$Age[1], cont_results$Age[2], cont_results$Age[3], cont_results$Age[4], cont_results$Age[5]))

for (label in names(cat_vars)) {
  r <- cat_results[[label]]
  cat(sprintf("%-30s %10s %10s %10s %10s %10s\n", label, "", "", "", "", r$p))
  for (i in seq_along(r$levels)) {
    cat(sprintf("  %-28s %10s %10s %10s %10s\n", r$levels[i],
                r$pct[i, 1], r$pct[i, 2], r$pct[i, 3], r$pct[i, 4]))
  }
}

for (label in setdiff(names(cont_vars), "Age")) {
  r <- cont_results[[label]]
  cat(sprintf("%-30s %10s %10s %10s %10s %10s\n", label, r[1], r[2], r[3], r[4], r[5]))
}

# ---- Save as CSV ----
out_rows <- list()
out_rows[[length(out_rows) + 1]] <- data.frame(Characteristic = "Age (years)",
  Q1 = cont_results$Age[1], Q2 = cont_results$Age[2], Q3 = cont_results$Age[3], Q4 = cont_results$Age[4],
  P = cont_results$Age[5])
for (label in names(cat_vars)) {
  r <- cat_results[[label]]
  out_rows[[length(out_rows) + 1]] <- data.frame(Characteristic = label, Q1 = "", Q2 = "", Q3 = "", Q4 = "", P = r$p)
  for (i in seq_along(r$levels)) {
    out_rows[[length(out_rows) + 1]] <- data.frame(
      Characteristic = paste0("  ", r$levels[i]),
      Q1 = r$pct[i, 1], Q2 = r$pct[i, 2], Q3 = r$pct[i, 3], Q4 = r$pct[i, 4], P = "")
  }
}
for (label in setdiff(names(cont_vars), "Age")) {
  r <- cont_results[[label]]
  out_rows[[length(out_rows) + 1]] <- data.frame(Characteristic = label,
    Q1 = r[1], Q2 = r[2], Q3 = r[3], Q4 = r[4], P = r[5])
}
out_df <- do.call(rbind, out_rows)
out_path <- file.path("output", "table1_v2.csv")
res <- try(write.csv(out_df, out_path, row.names = FALSE, fileEncoding = "UTF-8"), silent = TRUE)
if (inherits(res, "try-error")) {
  out_path <- file.path("output", paste0("table1_v2_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  write.csv(out_df, out_path, row.names = FALSE, fileEncoding = "UTF-8")
}
message(sprintf("Saved %s", out_path))
