## 05_diagnostics.R ------------------------------------------------------
## One-way ANOVA of the frailty index (FI) across quartiles of each marker
## (our sample quartiles, from R/04), its four residual diagnostic plots,
## Levene (Brown-Forsythe) and Bartlett tests, and a recommended omnibus
## test per marker.
##
## Normality: no normality test is run. With N = 14054 (about 3500 per
## group) Shapiro-Wilk cannot even be computed (limit 5000) and any
## normality test (Anderson-Darling, KS, ...) rejects for trivial departures,
## because its power goes to 1 as N grows. The QQ and residual plots decide
## how non-normal the residuals are, and at this N the group means are close
## to normal by the central limit theorem regardless.
##
## Recommendation rule (fixed before looking at results):
##   Levene p < 0.05  -> Welch ANOVA (means, unequal variances)
##   otherwise        -> classic one-way ANOVA
##   Kruskal-Wallis is reported for every marker as the rank-based
##   sensitivity analysis: FI is right-skewed and discrete (values k / items),
##   so a shift in the whole distribution can differ from a shift in means.
##
## Levene: car is not installed; car::leveneTest's default (center = median,
## the Brown-Forsythe variant) is the one-way ANOVA F on |y - group median|,
## computed directly below.
##
## Outputs
##   output/tables/05_diagnostics.csv
##   output/figures/05_residuals_<marker>.png   (residuals vs fitted, normal
##       QQ, scale-location, residuals vs leverage)
##
## Rscript R/05_diagnostics.R
## ------------------------------------------------------------------------

set.seed(20261005L)   # no random numbers are drawn; seeded by convention

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")

d <- readRDS(file.path(PROJ, "data", "processed", "analytic_quartiles.rds"))
MARKERS <- c("NLR", "MLR", "SIRI", "SII")

levene_bf <- function(y, g) {
  z <- abs(y - ave(y, g, FUN = median))
  a <- anova(lm(z ~ g))
  c(F = a[["F value"]][1], p = a[["Pr(>F)"]][1])
}

skewness <- function(x) mean((x - mean(x))^3) / sd(x)^3

diagnose <- function(m) {
  g   <- d[[paste0("q_", m, "_ours")]]
  fit <- aov(fi_score ~ g, data = data.frame(fi_score = d$fi_score, g = g))
  r   <- residuals(fit)

  png(file.path(FIG_DIR, sprintf("05_residuals_%s.png", m)), width = 1400, height = 1100, res = 150)
  op <- par(mfrow = c(2, 2), oma = c(0, 0, 2, 0))
  plot(fit, which = c(1, 2, 3, 5), sub.caption = "")
  mtext(sprintf("aov(FI ~ %s quartile), N = %d", m, length(r)), outer = TRUE, cex = 1.1)
  par(op); dev.off()

  lev <- levene_bf(d$fi_score, g)
  bar <- bartlett.test(d$fi_score, g)
  sds <- tapply(d$fi_score, g, sd)
  data.frame(marker = m,
             anova_F = summary(fit)[[1]][["F value"]][1],
             anova_p = summary(fit)[[1]][["Pr(>F)"]][1],
             resid_skewness = skewness(r),
             sd_Q1 = sds[[1]], sd_Q2 = sds[[2]], sd_Q3 = sds[[3]], sd_Q4 = sds[[4]],
             sd_ratio_max_min = max(sds) / min(sds),
             levene_F = lev[["F"]], levene_p = lev[["p"]],
             bartlett_K2 = unname(bar$statistic), bartlett_p = bar$p.value,
             recommended = if (lev[["p"]] < 0.05) "Welch ANOVA" else "one-way ANOVA",
             sensitivity = "Kruskal-Wallis")
}

res <- do.call(rbind, Map(diagnose, MARKERS))
write.csv(res, file.path(TAB_DIR, "05_diagnostics.csv"), row.names = FALSE)

show <- res
num <- vapply(show, is.numeric, logical(1)); show[num] <- lapply(show[num], signif, 4)
print(t(show))
