## 12_pvalue_uniformity_v2.R ---------------------------------------------
## v2 of R/02_pvalue_uniformity.R: same scenarios, tests, pass rule and
## figures. Two changes, see CHANGES_v2.md:
##   - the condition grid runs in parallel (future.apply) with one
##     independent L'Ecuyer-CMRG stream per condition;
##   - PMCMRplus::jonckheereTest is replaced by jt_p() (R/00_sim_utils.R),
##     proven bitwise identical on 1500 data sets by R/10_verify_jt_fast.R.
##
##   anova    oneway.test(var.equal = TRUE)
##   welch    oneway.test(var.equal = FALSE)
##   kruskal  kruskal.test (chi-square approximation)
##   jt       jt_p(): two-sided, normal approximation, no continuity
##            correction (PMCMRplus defaults)
##
## Scenarios: null_equal (4 x N(0,1), n per group 10 / 50 / 200) and
## contrast (equal means, n = 10/20/30/40, SD = 3/2/1.5/1). In contrast,
## classic ANOVA is the expected break (reported on its own line, not in the
## pass count); Kruskal-Wallis and JT have a false null and no target.
##
## Pass rule for the 13 checks (12 null rows + contrast Welch): 0.05 inside
## the 99% Monte Carlo interval of the rejection rate, and KS p >= 0.01.
##
## Arguments (all optional):
##   --B=10000          replicates per condition (default 10000)
##   --rng=streams      'streams' (L'Ecuyer-CMRG) or 'legacy' (v1 seeding)
##   --workers=7        parallel workers; 1 = sequential
##   --outdir=<path>    where tables/ and figures/ go (default output/)
##
## Rscript R/12_pvalue_uniformity_v2.R --B=10000
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "00_sim_utils.R"))

B       <- as.integer(cli_arg("B", 10000))
RNG     <- cli_arg("rng", "streams")
WORKERS <- as.integer(cli_arg("workers", availableCores(omit = 1)))
OUT     <- cli_arg("outdir", file.path(PROJ, "output"))
ALPHA   <- 0.05
SEED0   <- 20260929L
Z99     <- qnorm(0.995)
N_BINS  <- 20L

TAB_DIR <- file.path(OUT, "tables")
FIG_DIR <- file.path(OUT, "figures")
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
TAG <- sprintf("12_pvalue_uniformity_v2_B%d", B)

TESTS <- c("anova", "welch", "kruskal", "jt")

## ========================================================================
## 1. Group sizes and SDs per scenario (unchanged from v1)
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
    jt      = jt_p(y, g))
}

## ========================================================================
## 2. One condition: B data sets, four p-values each
## ========================================================================

## In streams mode future.apply has already set this condition's stream;
## in legacy mode the v1 seed is set here.
run_condition <- function(condition, scenario, n, legacy_seed) {
  d <- design(scenario, n)
  g <- factor(rep(seq_along(d$n), d$n))
  if (!is.na(legacy_seed))
    set.seed(legacy_seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
             sample.kind = "Rejection")
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
    ks_p    = vapply(ks, function(x) x$p.value, numeric(1)))

  pvals <- data.frame(condition = condition, scenario = scenario, n = summ$n[1],
                      test = rep(TESTS, each = B), p = as.vector(P))
  list(summ = summ, pvals = pvals)
}

## ========================================================================
## 3. Condition grid, run in parallel
## ========================================================================

grid <- rbind(
  expand.grid(scenario = "null_equal", n = c(10, 50, 200), stringsAsFactors = FALSE),
  data.frame(scenario = "contrast", n = NA))
grid$condition <- seq_len(nrow(grid))
seeds <- sim_seeds(nrow(grid), SEED0, RNG)

t0  <- Sys.time()
out <- run_grid(run_condition, grid$condition, grid$scenario, grid$n,
                seeds = seeds, workers = WORKERS)
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))

res   <- do.call(rbind, lapply(out, `[[`, "summ"))
pvals <- do.call(rbind, lapply(out, `[[`, "pvals"))
res$seed <- seeds$label[res$condition]

is_check      <- res$h0_true & !res$expected_break
res$rate_pass <- ifelse(is_check, res$target >= res$lower & res$target <= res$upper, NA)
res$ks_pass   <- ifelse(is_check, res$ks_p >= 0.01, NA)

out_csv <- file.path(TAB_DIR, paste0(TAG, ".csv"))
write.csv(res, out_csv, row.names = FALSE)

## ========================================================================
## 4. Console summary
## ========================================================================

n_chk <- sum(is_check)
cat(sprintf("B = %d, rng = %s, workers = %d, %d conditions x %d tests, %d s\n",
            B, RNG, WORKERS, nrow(grid), length(TESTS), elapsed))
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
## 5. Figures (unchanged from v1)
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

out_hist <- file.path(FIG_DIR, paste0(TAG, "_histograms.png"))
ggsave(out_hist, p_hist, width = 11, height = 8, dpi = 150)

p_qq <- ggplot(pvals, aes(sample = p)) +
  stat_qq(distribution = qunif, size = 0.4) +
  geom_abline(slope = 1, intercept = 0, colour = "#C0392B") +
  facet_grid(test ~ panel) +
  labs(x = "U(0,1) quantile", y = "Observed p-value quantile",
       title = "QQ plots of null p-values against U(0,1)") +
  coord_equal() +
  theme_bw(base_size = 10)

out_qq <- file.path(FIG_DIR, paste0(TAG, "_qq.png"))
ggsave(out_qq, p_qq, width = 11, height = 10, dpi = 150)
cat("Written:", out_hist, "\nWritten:", out_qq, "\n")
