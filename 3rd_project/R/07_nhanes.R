## 07_nhanes.R ------------------------------------------------------------
## The same three tests on real, heavily right-skewed data.
##
## Source: Week 2 analytic sample,
##   ../2nd_weeks/data/analytic_sample_v2.rds   (23,389 rows, NHANES
##   2011-2012, 2013-2014, 2015-2016 and 2017-2020 pre-pandemic)
##
## Variables (justified in the report):
##   LBXTR  serum triglycerides, mg/dL -- skewness ~11, the textbook
##          right-skewed biomarker and the guide's first suggestion.
##   LBDHDD HDL cholesterol, mg/dL     -- skewness ~1.2, a mildly skewed
##          contrast on a much larger n.
##   split: sex (Male / Female).
##
## IMPORTANT LIMITATION, stated up front: NHANES is a stratified, clustered,
## weighted sample. Everything below except the svyttest block is UNWEIGHTED.
## Unweighted tests are legitimate for comparing TESTS to each other on
## realistically shaped data -- which is this assignment's purpose -- but
## they do not estimate population quantities.
##
## Standalone:  Rscript R/07_nhanes.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

DATA <- normalizePath(file.path(PROJ, "..", "2nd_weeks", "data",
                                "analytic_sample_v2.rds"), mustWork = FALSE)
if (!file.exists(DATA))
  stop("Week 2 analytic sample not found at: ", DATA,
       "\nPlease supply the path.")
d <- readRDS(DATA)
cat("\n== NHANES ==\n")
cat("source : ", DATA, "\n", sep = "")
cat("rows   : ", nrow(d), " | cols: ", ncol(d), "\n", sep = "")
cat("cycles : ", paste(names(table(d$cycle)), collapse = ", "), "\n", sep = "")

samp_skew <- function(v) { v <- v[is.finite(v)]
  m <- mean(v); s <- sqrt(mean((v - m)^2)); mean((v - m)^3) / s^3 }

VARS <- c(LBXTR = "Triglycerides (mg/dL)", LBDHDD = "HDL cholesterol (mg/dL)")
GROUP <- "sex"

## ------------------------------------------------------------------
## missing data, documented explicitly (complete-case analysis)
## ------------------------------------------------------------------
cat("\n-- missing data (complete-case analysis) --\n")
miss <- do.call(rbind, lapply(names(VARS), function(v) {
  keep <- !is.na(d[[v]]) & !is.na(d[[GROUP]])
  data.frame(variable = v, label = VARS[[v]],
             n_total = nrow(d),
             n_missing_value = sum(is.na(d[[v]])),
             n_missing_group = sum(is.na(d[[GROUP]])),
             n_complete = sum(keep),
             pct_dropped = round(100 * (1 - sum(keep) / nrow(d)), 1),
             row.names = NULL)
}))
print(miss, row.names = FALSE)
cat("\nLBXTR is measured only on the fasting subsample, which is why more\n")
cat("than half the rows drop. That is by design, not data loss.\n")

## ------------------------------------------------------------------
## descriptives and full-sample tests
## ------------------------------------------------------------------
full <- list()
desc_all <- list(); test_all <- list(); eff_all <- list()

for (v in names(VARS)) {
  keep <- !is.na(d[[v]]) & !is.na(d[[GROUP]])
  dd <- d[keep, c(v, GROUP, "WTCOMB", "psu_c", "strata_c")]
  names(dd)[1] <- "value"
  x <- dd$value[dd[[GROUP]] == "Male"]      # group 1
  y <- dd$value[dd[[GROUP]] == "Female"]    # group 2

  desc <- data.frame(
    variable = v, label = VARS[[v]],
    group = c("Male", "Female"),
    n = c(length(x), length(y)),
    mean = c(mean(x), mean(y)), median = c(median(x), median(y)),
    sd = c(sd(x), sd(y)), iqr = c(IQR(x), IQR(y)),
    skewness = c(samp_skew(x), samp_skew(y)),
    min = c(min(x), min(y)), max = c(max(x), max(y)),
    row.names = NULL)

  tests <- data.frame(
    variable = v, label = VARS[[v]],
    welch_p = welch_p(x, y), welch_df = welch_df(x, y),
    student_p = student_p(x, y), wmw_p = wmw_p(x, y),
    mean_diff = mean(x) - mean(y),
    sd_ratio = sd(x) / sd(y),
    row.names = NULL)
  ## confirm the fast functions against base R on the real data too
  tests$welch_p_base   <- t.test(x, y)$p.value
  tests$student_p_base <- t.test(x, y, var.equal = TRUE)$p.value
  tests$wmw_p_base <- suppressWarnings(
    wilcox.test(x, y, exact = FALSE, correct = FALSE)$p.value)

  eff <- data.frame(
    variable = v, label = VARS[[v]],
    cohen_d = cohen_d(x, y), hedges_g = hedges_g(x, y),
    glass_delta = glass_delta(x, y), cliff_delta = cliff_delta(x, y),
    cles = cles(x, y), row.names = NULL)

  ci_w <- t.test(x, y)$conf.int
  ci_s <- t.test(x, y, var.equal = TRUE)$conf.int
  hl <- suppressWarnings(wilcox.test(x, y, conf.int = TRUE,
                                     exact = FALSE, correct = FALSE))

  full[[v]] <- list(x = x, y = y, desc = desc, tests = tests, eff = eff,
                    ci_welch = as.numeric(ci_w), ci_student = as.numeric(ci_s),
                    hl_est = unname(hl$estimate),
                    hl_ci = as.numeric(hl$conf.int),
                    data = dd)
  desc_all[[v]] <- desc; test_all[[v]] <- tests; eff_all[[v]] <- eff
}
desc_all <- do.call(rbind, desc_all)
test_all <- do.call(rbind, test_all)
eff_all  <- do.call(rbind, eff_all)

cat("\n-- descriptives by sex --\n")
print(desc_all[, c("variable", "group", "n", "mean", "median", "sd", "iqr",
                   "skewness", "max")], row.names = FALSE, digits = 4)
cat("\n-- full-sample tests (unweighted) --\n")
print(test_all[, c("variable", "welch_p", "student_p", "wmw_p", "welch_df",
                   "mean_diff", "sd_ratio")], row.names = FALSE, digits = 4)
cat("\nagreement with base R on the real data:\n")
cat("  max |welch_p - t.test|        : ",
    signif(max(abs(test_all$welch_p - test_all$welch_p_base)), 3), "\n", sep = "")
cat("  max |student_p - t.test|      : ",
    signif(max(abs(test_all$student_p - test_all$student_p_base)), 3), "\n", sep = "")
cat("  max |wmw_p - wilcox.test|     : ",
    signif(max(abs(test_all$wmw_p - test_all$wmw_p_base)), 3), "\n", sep = "")
cat("\n-- effect sizes --\n")
print(eff_all[, c("variable", "cohen_d", "hedges_g", "glass_delta",
                  "cliff_delta", "cles")], row.names = FALSE, digits = 4)

cat("\n-- interval estimates (note the scale mismatch) --\n")
for (v in names(VARS)) {
  f <- full[[v]]
  cat(sprintf("%-7s Welch mean diff  95%% CI : [%8.3f, %8.3f]\n",
              v, f$ci_welch[1], f$ci_welch[2]))
  cat(sprintf("%-7s Hodges-Lehmann   95%% CI : [%8.3f, %8.3f]  (est %.3f)\n",
              "", f$hl_ci[1], f$hl_ci[2], f$hl_est))
}
cat("The Hodges-Lehmann interval estimates the median of all pairwise\n")
cat("differences, NOT the difference in means. Same units, different\n")
cat("estimand -- they are not interchangeable.\n")

## ------------------------------------------------------------------
## design-based reference (survey package)
## ------------------------------------------------------------------
cat("\n-- design-based reference: survey::svyttest --\n")
svy_res <- NULL
if (requireNamespace("survey", quietly = TRUE)) {
  suppressPackageStartupMessages(library(survey))
  old <- options(survey.lonely.psu = "adjust")
  svy_res <- do.call(rbind, lapply(names(VARS), function(v) {
    dd <- full[[v]]$data
    dd$grp <- factor(dd[[GROUP]], levels = c("Female", "Male"))
    des <- svydesign(ids = ~psu_c, strata = ~strata_c, weights = ~WTCOMB,
                     data = dd, nest = TRUE)
    tt <- svyttest(value ~ grp, des)
    data.frame(variable = v, label = VARS[[v]],
               svy_diff = unname(tt$estimate), svy_p = tt$p.value,
               svy_df = unname(tt$parameter),
               svy_lo = confint(tt)[1], svy_hi = confint(tt)[2],
               unweighted_welch_p = full[[v]]$tests$welch_p,
               unweighted_diff = -full[[v]]$tests$mean_diff,
               row.names = NULL)
  }))
  options(old)
  print(svy_res, row.names = FALSE, digits = 4)
  cat("\n(svy_diff is Male - Female, matching unweighted_diff's sign.)\n")
  cat("\nWEIGHT CAVEAT: WTCOMB is the MEC examination weight. It is the\n")
  cat("correct weight for LBDHDD. LBXTR comes from the FASTING subsample,\n")
  cat("whose design-correct weight is WTSAF2YR; that variable is not in the\n")
  cat("Week 2 analytic file, so the triglyceride svyttest row is indicative\n")
  cat("only and its standard error is not design-correct.\n")
} else {
  cat("survey package not available -- skipped.\n")
}

## ------------------------------------------------------------------
## subsampling experiment
## ------------------------------------------------------------------
## Repeatedly subsample n per group WITHOUT replacement from the observed
## data and watch the Welch / WMW p-value gap open up as n grows.
NS_SUB <- c(25, 50, 100, 250, 500, 1000, 2500)
NREP <- 2000L
cat("\n-- subsampling experiment (", NREP, " draws per n) --\n", sep = "")

sub_res <- do.call(rbind, lapply(names(VARS), function(v) {
  x0 <- full[[v]]$x; y0 <- full[[v]]$y
  ns <- NS_SUB[NS_SUB <= min(length(x0), length(y0))]
  streams <- make_streams(length(ns), SEED + 700L + 10L * match(v, names(VARS)))
  do.call(rbind, lapply(seq_along(ns), function(i) {
    n <- ns[i]
    use_stream(streams[[i]])
    P <- vapply(seq_len(NREP), function(b) {
      x <- x0[sample.int(length(x0), n)]
      y <- y0[sample.int(length(y0), n)]
      tp <- three_p(x, y)
      c(tp[["welch"]], tp[["wmw"]], cliff_delta(x, y))
    }, numeric(3))
    data.frame(
      variable = v, label = VARS[[v]], n = n,
      rej_welch = 100 * mean(P[1, ] < 0.05),
      rej_wmw   = 100 * mean(P[2, ] < 0.05),
      median_p_welch = median(P[1, ]), median_p_wmw = median(P[2, ]),
      p_wmw_lt_welch = 100 * mean(P[2, ] < P[1, ]),
      mean_log10_ratio = mean(log10(pmax(P[2, ], 1e-300)) -
                                log10(pmax(P[1, ], 1e-300))),
      mean_cliff = mean(P[3, ]),
      row.names = NULL)
  }))
}))
print(sub_res[, c("variable", "n", "rej_welch", "rej_wmw", "median_p_welch",
                  "median_p_wmw", "p_wmw_lt_welch", "mean_cliff")],
      row.names = FALSE, digits = 4)
cat("\nmean_log10_ratio is the average of log10(p_WMW) - log10(p_Welch):\n")
print(sub_res[, c("variable", "n", "mean_log10_ratio")],
      row.names = FALSE, digits = 3)
cat("\nNote: unlike the simulation, the null is NOT true here -- the two\n")
cat("groups genuinely differ in both location and spread -- so these are\n")
cat("POWER curves, not Type I error curves. What carries over from the\n")
cat("paper is that WMW's p-value falls faster than Welch's as n grows.\n")

saveRDS(list(source = DATA, vars = VARS, group = GROUP,
             missing = miss, descriptives = desc_all, tests = test_all,
             effects = eff_all, full = full, survey = svy_res,
             subsample = sub_res, ns_sub = NS_SUB, nrep = NREP),
        file.path(RES_DIR, "07_nhanes.rds"))
cat("\nsaved -> results/07_nhanes.rds\n")
