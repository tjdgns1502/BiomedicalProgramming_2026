# Compute survey-weighted Table 1 (characteristics by WWI quartile)

library(survey)

d <- readRDS(file.path("data", "analytic_sample.rds"))
d$q_num <- as.numeric(d$wwi_q)

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

  fit <- svyglm(as.formula(paste0(v, " ~ q_num")), design = sub)
  pval <- summary(fit)$coefficients["q_num", "Pr(>|t|)"]

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
cat("Table 1. Basic characteristics of participants by weight-adjusted waist index quartile\n")
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
out_path <- file.path("output", "table1.csv")
res <- try(write.csv(out_df, out_path, row.names = FALSE, fileEncoding = "UTF-8"), silent = TRUE)
if (inherits(res, "try-error")) {
  out_path <- file.path("output", paste0("table1_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
  write.csv(out_df, out_path, row.names = FALSE, fileEncoding = "UTF-8")
}
message(sprintf("Saved %s", out_path))
