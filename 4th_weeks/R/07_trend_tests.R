## 07_trend_tests.R ------------------------------------------------------
## Trend tests of the frailty index (FI) across marker quartiles, and the
## paper's Table 2 and Table 3 logistic models (frail = FI > 0.3).
##
## 1. Trend on FI (unweighted, our sample quartiles, N = 14054)
##    linear   lm(FI ~ quartile score 1-4): slope and its t-test p
##    JT       PMCMRplus::jonckheereTest(FI, quartile), two-sided; FI has
##             ties, so PMCMRplus applies its tie-corrected variance (warning
##             expected). R/00_sim_utils.R's jt_p() is not used: it is only
##             proven equal to PMCMRplus for untied data.
##
## 2. Table 2: frail ~ log(marker) + covariates, OR per 1-unit increase in
##    ln(marker); OR per 1-unit log10(marker) = OR_ln ^ ln(10) is also given
##    because the paper does not say which log it used.
## 3. Table 3: frail ~ quartile (Q1 = reference) + covariates; P for trend
##    from the same model with the quartile score (1-4) as a continuous term.
##    Event / N per quartile are unweighted counts.
##
## Covariates (paper Methods / Table 2 footnote):
##   Model 1: age (continuous), sex, NHANES cycle, race/ethnicity
##   Model 2: Model 1 + education, family PIR (<=1.0 / 1.1-3.0 / >3.0),
##            drinking (yes / no / missing), smoking, BMI category, physical
##            activity, total energy intake, self-reported diabetes and
##            hypertension
##
## Weighting: the paper does not state whether its models are weighted, so
## every model is fitted both ways:
##   weighted    svyglm(family = quasibinomial) on the saved design
##               (built on the full file, then subset); Wald CI and p with
##               the model's residual df (design df + 1 - number of
##               coefficients: 123 for Model 1, 109 for Model 2), as
##               svyglm's own summary() and confint() use
##   unweighted  glm(family = binomial); Wald CI (normal quantile)
## Table 3 is fitted with both quartile versions from R/04 (ours, paper).
##
## Outputs
##   output/tables/07_trend_fi.csv
##   output/tables/07_table2_logistic.csv
##   output/tables/07_table3_quartiles.csv
##
## Rscript R/07_trend_tests.R
## ------------------------------------------------------------------------

set.seed(20261007L)   # no random numbers are drawn; seeded by convention

suppressPackageStartupMessages({
  library(survey)
  library(PMCMRplus)
})

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")

d <- readRDS(file.path(PROJ, "data", "processed", "analytic_quartiles.rds"))
MARKERS <- c("NLR", "MLR", "SIRI", "SII")

## Covariate coding shared by glm and svyglm
prep <- function(x) {
  x$sex_f   <- factor(x$sex)
  x$cycle_f <- factor(x$cycle)
  x$race_f  <- relevel(factor(x$race_cat), ref = "Non-Hispanic White")
  x$educ_f  <- relevel(factor(x$educ_cat), ref = "less than high school")
  x$pir_f   <- factor(x$pir_cat, levels = c("<=1.0", "1.1-3.0", ">3.0"))
  x$drink_f <- factor(x$drinker_cat, levels = c("No", "Yes", "Missing data"))
  x$bmi_f   <- factor(x$bmi_cat)
  x$pa_f    <- factor(x$pa_cat, levels = c("never", "moderate", "active"))
  x
}
d <- prep(d)

## Marker terms: ln(marker), quartile factors and quartile scores, both versions
marker_grid <- expand.grid(marker = MARKERS, version = c("ours", "paper"), stringsAsFactors = FALSE)
d[paste0("ln_", MARKERS)] <- Map(function(m) log(d[[m]]), MARKERS)
d[paste0("qs_", marker_grid$marker, "_", marker_grid$version)] <-
  Map(function(m, v) as.numeric(d[[paste0("q_", m, "_", v)]]), marker_grid$marker, marker_grid$version)

## Survey design (saved by R/20), with the new variables attached by SEQN
des <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_svydesign.rds"))
stopifnot(nrow(des$variables) == nrow(d))
idx <- match(des$variables$SEQN, d$SEQN)
stopifnot(!anyNA(idx))
des$variables <- d[idx, ]

COV <- list(
  model1 = "age + sex_f + cycle_f + race_f",
  model2 = paste("age + sex_f + cycle_f + race_f + educ_f + pir_f + drink_f + smoker +",
                 "bmi_f + pa_f + energy_kcal + diabetes_cov + hypertension"))

fit_logit <- function(rhs, weighting) {
  f <- as.formula(paste("frail_num ~", rhs))
  if (weighting == "weighted") svyglm(f, design = des, family = quasibinomial())
  else glm(f, data = d, family = binomial())
}

wald <- function(fit, term, weighting) {
  b  <- coef(fit)[[term]]
  se <- sqrt(diag(vcov(fit)))[[term]]
  q  <- if (weighting == "weighted") qt(0.975, fit$df.residual) else qnorm(0.975)
  p  <- if (weighting == "weighted") 2 * pt(-abs(b / se), fit$df.residual) else 2 * pnorm(-abs(b / se))
  c(beta = b, se = se, or = exp(b), lcl = exp(b - q * se), ucl = exp(b + q * se), p = p)
}

## ========================================================================
## 1. Trend tests on FI
## ========================================================================

trend_fi <- do.call(rbind, Map(function(m) {
  qs <- d[[paste0("qs_", m, "_ours")]]
  lmf <- summary(lm(d$fi_score ~ qs))$coefficients
  jt  <- suppressWarnings(jonckheereTest(d$fi_score, d[[paste0("q_", m, "_ours")]]))
  data.frame(marker = m,
             linear_slope_per_quartile = lmf["qs", "Estimate"],
             linear_se = lmf["qs", "Std. Error"],
             linear_p = lmf["qs", "Pr(>|t|)"],
             jt_JT = unname(jt$estimates), jt_z = unname(jt$statistic), jt_p = jt$p.value)
}, MARKERS))
write.csv(trend_fi, file.path(TAB_DIR, "07_trend_fi.csv"), row.names = FALSE)

## ========================================================================
## 2. Table 2: continuous ln(marker)
## ========================================================================

t2_grid <- expand.grid(marker = MARKERS, model = names(COV), weighting = c("weighted", "unweighted"),
                       stringsAsFactors = FALSE)
table2 <- do.call(rbind, Map(function(m, mod, w) {
  term <- paste0("ln_", m)
  fit  <- fit_logit(paste(term, "+", COV[[mod]]), w)
  est  <- wald(fit, term, w)
  data.frame(marker = m, model = mod, weighting = w, n = nobs(fit),
             or_per_ln = est[["or"]], lcl = est[["lcl"]], ucl = est[["ucl"]], p = est[["p"]],
             or_per_log10 = est[["or"]]^log(10),
             lcl_log10 = est[["lcl"]]^log(10), ucl_log10 = est[["ucl"]]^log(10))
}, t2_grid$marker, t2_grid$model, t2_grid$weighting))
write.csv(table2, file.path(TAB_DIR, "07_table2_logistic.csv"), row.names = FALSE)

## ========================================================================
## 3. Table 3: quartiles, P for trend from the quartile score
## ========================================================================

t3_grid <- expand.grid(marker = MARKERS, model = names(COV), weighting = c("weighted", "unweighted"),
                       version = c("ours", "paper"), stringsAsFactors = FALSE)
table3 <- do.call(rbind, Map(function(m, mod, w, v) {
  qv <- paste0("q_", m, "_", v); sv <- paste0("qs_", m, "_", v)
  fit_q <- fit_logit(paste(qv, "+", COV[[mod]]), w)
  fit_t <- fit_logit(paste(sv, "+", COV[[mod]]), w)
  p_trend <- wald(fit_t, sv, w)[["p"]]
  q_est <- do.call(rbind, Map(function(q) {
    e <- wald(fit_q, paste0(qv, q), w)
    data.frame(quartile = q, or = e[["or"]], lcl = e[["lcl"]], ucl = e[["ucl"]], p = e[["p"]])
  }, c("Q2", "Q3", "Q4")))
  q_est <- rbind(data.frame(quartile = "Q1", or = 1, lcl = NA, ucl = NA, p = NA), q_est)
  g <- d[[qv]]
  data.frame(marker = m, model = mod, weighting = w, quartile_version = v, q_est,
             events = as.vector(tapply(d$frail_num, g, sum)), n = as.vector(table(g)),
             p_trend = p_trend)
}, t3_grid$marker, t3_grid$model, t3_grid$weighting, t3_grid$version))
rownames(table3) <- NULL
write.csv(table3, file.path(TAB_DIR, "07_table3_quartiles.csv"), row.names = FALSE)

## ========================================================================
## 4. Console, with the paper's values alongside
## ========================================================================

cat("Trend of FI across quartiles (unweighted):\n")
print(data.frame(marker = trend_fi$marker,
                 slope = signif(trend_fi$linear_slope_per_quartile, 3),
                 linear_p = signif(trend_fi$linear_p, 3),
                 JT_z = round(trend_fi$jt_z, 2), JT_p = signif(trend_fi$jt_p, 3)), row.names = FALSE)

paper_t2 <- data.frame(marker = rep(MARKERS, 2), model = rep(c("model1", "model2"), each = 4),
                       paper = c("4.85 (3.60, 6.54)", "3.46 (2.41, 4.95)", "4.09 (3.24, 5.17)", "2.39 (1.84, 3.11)",
                                 "3.45 (2.52, 4.73)", "3.58 (2.44, 5.25)", "2.77 (2.17, 3.55)", "1.89 (1.44, 2.48)"))
ci <- function(o, l, u) sprintf("%.2f (%.2f, %.2f)", o, l, u)
t2s <- reshape(transform(table2, ln = ci(or_per_ln, lcl, ucl), log10 = ci(or_per_log10, lcl_log10, ucl_log10))[
                 c("marker", "model", "weighting", "ln", "log10")],
               idvar = c("marker", "model"), timevar = "weighting", direction = "wide")
cat("\nTable 2, OR (95% CI) per unit of log(marker):\n")
print(merge(paper_t2, t2s, sort = FALSE), row.names = FALSE)

cat("\nTable 3, our sample quartiles, OR (95% CI) and P for trend:\n")
t3o <- table3[table3$quartile_version == "ours", ]
t3o$or_ci <- ifelse(t3o$quartile == "Q1", "Ref", ci(t3o$or, t3o$lcl, t3o$ucl))
t3o$key <- paste(t3o$model, t3o$weighting)
t3w <- reshape(t3o[c("marker", "quartile", "events", "n", "key", "or_ci")],
               idvar = c("marker", "quartile", "events", "n"), timevar = "key", direction = "wide")
names(t3w) <- sub("^or_ci\\.", "", names(t3w))
print(t3w, row.names = FALSE)
pt <- unique(t3o[c("marker", "model", "weighting", "p_trend")])
cat("\nP for trend (quartile score), our quartiles:\n")
print(transform(pt, p_trend = signif(p_trend, 3)), row.names = FALSE)
