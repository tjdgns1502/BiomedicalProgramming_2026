## 02_pvalue_uniformity.R ------------------------------------------------
## Null p-value distributions of four k-group tests, k = 4 groups (the
## paper's quartile groups):
##
##   anova    one-way ANOVA F test         oneway.test(var.equal = TRUE)
##   welch    Welch ANOVA                  oneway.test(var.equal = FALSE)
##   kruskal  Kruskal-Wallis               kruskal.test (chi-square approx.)
##   jt       Jonckheere-Terpstra trend    PMCMRplus::jonckheereTest
##                                         (two-sided, normal approximation,
##                                          no continuity correction: the
##                                          package defaults, stated here)
##
## Scenarios
##   null_equal   all groups N(0, 1), n per group in 10, 50, 200.
##                Every test's null is true; target p ~ U(0, 1).
##   contrast     equal means, unequal SDs and unequal n, with the largest
##                SD in the smallest group: n = 10/20/30/40, SD = 3/2/1.5/1.
##                Mean equality holds, so ANOVA and Welch should still reject
##                5%; classic ANOVA is expected to break, Welch should not.
##                Kruskal-Wallis and JT test identical distributions, which
##                is false here, so their rejection rate is not a type I
##                error rate and gets no target.
##
## The data are continuous with no ties, so none of the statistics is
## discrete and uniformity is the correct target for every test with a
## true null.
##
## Pass rule, fixed before running, for each (scenario, test) with a true
## null that is not an expected break: (1) 0.05 lies inside the 99% Monte
## Carlo interval of the rejection rate, (2) KS test against U(0, 1) gives
## p >= 0.01. That is 12 null rows + contrast Welch = 13 checks per rule,
## so about 0.13 false fails per rule are expected. The contrast ANOVA row
## (expected_break = TRUE) is the demonstration, not a check: it is kept
## out of the pass count and reported on its own line.
##
## Runs standalone from a clean R session:  Rscript R/02_pvalue_uniformity.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(ggplot2)
  library(PMCMRplus)
})

B      <- 1000L       # quick run; use 10000L for the final run
ALPHA  <- 0.05
SEED0  <- 20260929L   # condition i uses seed SEED0 + i
Z99    <- qnorm(0.995)
N_BINS <- 20L

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

TESTS <- c("anova", "welch", "kruskal", "jt")

## ========================================================================
## 1. Group sizes and SDs per scenario
## ========================================================================

design <- function(scenario, n) {
  switch(scenario,
    null_equal = list(n = rep(n, 4),            sd = rep(1, 4)),
    contrast   = list(n = c(10, 20, 30, 40),    sd = c(3, 2, 1.5, 1)),
    stop("unknown scenario: ", scenario))
}

## All four tests on the same simulated data set.
all_p <- function(y, g) {
  c(anova   = oneway.test(y ~ g, var.equal = TRUE)$p.value,
    welch   = oneway.test(y ~ g, var.equal = FALSE)$p.value,
    kruskal = kruskal.test(y, g)$p.value,
    jt      = jonckheereTest(y, g)$p.value)
}

## ========================================================================
## 2. One condition: B data sets, four p-values each
## ========================================================================

run_condition <- function(condition, scenario, n, seed) {
  d <- design(scenario, n)
  g <- factor(rep(seq_along(d$n), d$n))
  set.seed(seed)
  P <- t(replicate(B, all_p(rnorm(sum(d$n), mean = 0, sd = rep(d$sd, d$n)), g)))

  h0_true <- if (scenario == "null_equal") rep(TRUE, 4) else TESTS %in% c("anova", "welch")
  est <- colMeans(P <= ALPHA)
  se  <- sqrt(est * (1 - est) / B)
  ks  <- lapply(TESTS, function(t) suppressWarnings(ks.test(P[, t], "punif")))

  summ <- data.frame(
    condition = condition, scenario = scenario,
    n = if (scenario == "null_equal") as.character(n) else paste(d$n, collapse = "/"),
    test = TESTS, h0_true = h0_true,
    expected_break = scenario == "contrast" & TESTS == "anova",
    target = ifelse(h0_true, ALPHA, NA),
    estimate = unname(est), se = unname(se),
    lower = unname(est - Z99 * se), upper = unname(est + Z99 * se),
    ks_stat = vapply(ks, function(x) unname(x$statistic), numeric(1)),
    ks_p    = vapply(ks, function(x) x$p.value, numeric(1)),
    seed = seed)

  pvals <- data.frame(condition = condition, scenario = scenario, n = summ$n[1],
                      test = rep(TESTS, each = B), p = as.vector(P))
  list(summ = summ, pvals = pvals)
}

## ========================================================================
## 3. Condition grid: three null sizes plus the contrast scenario
## ========================================================================

grid <- rbind(
  expand.grid(scenario = "null_equal", n = c(10, 50, 200), stringsAsFactors = FALSE),
  data.frame(scenario = "contrast", n = NA))
grid$condition <- seq_len(nrow(grid))
grid$seed      <- SEED0 + grid$condition

t0  <- Sys.time()
out <- Map(run_condition, grid$condition, grid$scenario, grid$n, grid$seed)
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))

res   <- do.call(rbind, lapply(out, `[[`, "summ"))
pvals <- do.call(rbind, lapply(out, `[[`, "pvals"))

is_check      <- res$h0_true & !res$expected_break
res$rate_pass <- ifelse(is_check, res$target >= res$lower & res$target <= res$upper, NA)
res$ks_pass   <- ifelse(is_check, res$ks_p >= 0.01, NA)

out_csv <- file.path(TAB_DIR, "02_pvalue_uniformity.csv")
write.csv(res, out_csv, row.names = FALSE)

## ========================================================================
## 4. Console summary
## ========================================================================

n_chk <- sum(is_check)
cat(sprintf("B = %d, %d conditions x %d tests, %d s\n", B, nrow(grid), length(TESTS), elapsed))
cat(sprintf("rejection-rate pass: %d / %d, KS pass: %d / %d  (expected false fails per rule: %.2f)\n",
            sum(res$rate_pass, na.rm = TRUE), n_chk,
            sum(res$ks_pass, na.rm = TRUE), n_chk, 0.01 * n_chk))
for (i in which(res$expected_break)) {
  cat(sprintf("expected break (not a check): %s %s, n = %s: rejection rate %.3f [99%% MC %.3f, %.3f] vs nominal %.2f, KS p = %.3g\n",
              res$scenario[i], res$test[i], res$n[i], res$estimate[i],
              res$lower[i], res$upper[i], ALPHA, res$ks_p[i]))
}
show <- res
show[c("estimate", "lower", "upper", "ks_stat")] <- round(show[c("estimate", "lower", "upper", "ks_stat")], 3)
show$ks_p <- signif(show$ks_p, 3)
print(show[c("scenario", "n", "test", "expected_break", "target", "estimate",
             "lower", "upper", "rate_pass", "ks_p", "ks_pass")], row.names = FALSE)
cat("\nWritten:", out_csv, "\n")

## ========================================================================
## 5. Figures: histograms with the uniform reference line, and QQ plots
## ========================================================================

pvals$panel <- factor(ifelse(pvals$scenario == "null_equal",
                             paste0("null, n = ", pvals$n),
                             paste0("contrast, n = ", pvals$n)),
                      levels = unique(ifelse(grid$scenario == "null_equal",
                                             paste0("null, n = ", grid$n),
                                             "contrast, n = 10/20/30/40")))
pvals$test <- factor(pvals$test, levels = TESTS)

p_hist <- ggplot(pvals, aes(p)) +
  geom_histogram(breaks = seq(0, 1, length.out = N_BINS + 1),
                 fill = "grey70", colour = "grey30", linewidth = 0.2) +
  geom_hline(yintercept = B / N_BINS, colour = "#C0392B", linewidth = 0.6) +
  facet_grid(test ~ panel) +
  labs(x = "p-value", y = "Count",
       title = "Null p-value distributions (4 groups)",
       subtitle = sprintf("Red line: expected count per bin under U(0,1) = B / %d = %g",
                          N_BINS, B / N_BINS)) +
  theme_bw(base_size = 10)

out_hist <- file.path(FIG_DIR, "02_pvalue_histograms.png")
ggsave(out_hist, p_hist, width = 11, height = 8, dpi = 150)

p_qq <- ggplot(pvals, aes(sample = p)) +
  stat_qq(distribution = qunif, size = 0.4) +
  geom_abline(slope = 1, intercept = 0, colour = "#C0392B") +
  facet_grid(test ~ panel) +
  labs(x = "U(0,1) quantile", y = "Observed p-value quantile",
       title = "QQ plots of null p-values against U(0,1)") +
  coord_equal() +
  theme_bw(base_size = 10)

out_qq <- file.path(FIG_DIR, "02_pvalue_qq.png")
ggsave(out_qq, p_qq, width = 11, height = 10, dpi = 150)
cat("Written:", out_hist, "\nWritten:", out_qq, "\n")
