## 40_fisher_size.R -------------------------------------------------------
## Verification task 1: the actual size of Fisher's exact test is below the
## nominal alpha (it is conservative), compared with Pearson chi-square,
## Yates-corrected chi-square and the Fisher mid-p.
##
## Design: two independent binomials, x1 ~ Bin(n, pi), x2 ~ Bin(n, pi)
## (H0 true: p1 = p2 = pi), equal n per group, two-sided, alpha = 0.05.
##
## Exact size (no simulation error). Every test here has a p-value that is a
## function of (x1, x2) only - Fisher conditions on the margins, so pi does
## not enter. For each n the rejection matrix R[x1, x2] is computed ONCE over
## all (n+1)^2 outcomes; then for any pi
##     size(pi) = sum( R * outer(dbinom(0:n, n, pi), dbinom(0:n, n, pi)) ),
## so the whole pi grid costs one outer product per pi, no re-testing.
## Tables with a zero margin (x1 + x2 = 0 or 2n) give no chi-square
## statistic (NaN): counted as not rejected; Fisher gives p = 1 there.
##
## Mid-p (two-sided, same ordering as fisher.test): sum of the conditional
## hypergeometric probabilities of tables less likely than the observed one,
## plus half the probability of tables exactly as likely (relative tolerance
## 1e-7, the one fisher.test uses).
##
## Monte Carlo check of the enumeration (monte-carlo-verification skill):
##   conditions  n in N_GRID x pi in PI_MC x 4 tests
##   target      exact size from the enumeration above
##   estimate    rejection rate over B simulated tables, each tested with a
##               direct fisher.test / chisq.test call (not the R lookup), so
##               the check is independent of the enumeration code for Fisher,
##               Pearson and Yates. Mid-p uses the same midp_p() in both, so
##               for mid-p only the binomial weighting is checked.
##   pass        target inside estimate +/- 2.576 * sqrt(est (1 - est) / B)
##               (99%); with k conditions, k * 0.01 false fails are expected.
##   seed        SEED0 + condition index (n x pi), one per condition.
##
## Outputs:
##   output/tables/40_fisher_size_exact.csv   n, pi, test, size  (pi grid)
##   output/tables/40_fisher_size_mc.csv      condition, n, pi, test, seed,
##                                            target, estimate, se, lower,
##                                            upper, pass
##   output/tables/40_fisher_size_summary.csv per n x test: max and mean size
##                                            over pi, share of pi with
##                                            size > alpha
##   output/figures/40_fisher_size_curve.png  size curves, MC points with
##                                            99% error bars, alpha line
##
## Rscript R/40_fisher_size.R [--B=10000]
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")

arg_B <- sub("^--B=", "", grep("^--B=", commandArgs(TRUE), value = TRUE))
B      <- if (length(arg_B)) as.integer(arg_B) else 10000L
ALPHA  <- 0.05
N_GRID <- c(5L, 10L, 20L, 50L, 100L, 200L)
PI_GRID <- seq(0.01, 0.99, by = 0.01)
PI_MC  <- c(0.1, 0.3, 0.5)
TESTS  <- c("fisher", "midp", "pearson", "yates")
SEED0  <- 20261007L
Z99    <- qnorm(0.995)

## --- p-values for one 2 x 2 outcome --------------------------------------
tab2 <- function(x1, x2, n) matrix(c(x1, n - x1, x2, n - x2), 2)

midp_p <- function(x1, x2, n) {
  m <- x1 + x2                       # column total of "events"
  lo <- max(0, m - n); hi <- min(n, m)
  d  <- dhyper(lo:hi, n, n, m)       # x1 given the margins
  d_obs <- dhyper(x1, n, n, m)
  tol <- 1 + 1e-7
  sum(d[d < d_obs / tol]) + 0.5 * sum(d[d <= d_obs * tol & d >= d_obs / tol])
}

pvals <- function(x1, x2, n) {
  t <- tab2(x1, x2, n)
  c(fisher  = fisher.test(t)$p.value,
    midp    = midp_p(x1, x2, n),
    pearson = suppressWarnings(chisq.test(t, correct = FALSE)$p.value),
    yates   = suppressWarnings(chisq.test(t, correct = TRUE)$p.value))
}

## --- exact size by enumeration --------------------------------------------
reject_matrices <- function(n) {
  g <- expand.grid(x1 = 0:n, x2 = 0:n)
  p <- t(mapply(pvals, g$x1, g$x2, MoreArgs = list(n = n)))
  lapply(setNames(TESTS, TESTS), function(ts) {
    r <- !is.na(p[, ts]) & p[, ts] <= ALPHA
    matrix(r, n + 1, n + 1)          # row = x1, col = x2 (expand.grid order)
  })
}

t0 <- Sys.time()
RM <- setNames(lapply(N_GRID, reject_matrices), N_GRID)
cat(sprintf("rejection matrices for n = %s: %.1f s\n",
            paste(N_GRID, collapse = ", "),
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

exact_size <- function(n, pi, ts) {
  w <- dbinom(0:n, n, pi)
  sum(RM[[as.character(n)]][[ts]] * outer(w, w))
}

exact <- do.call(rbind, lapply(N_GRID, function(n) do.call(rbind,
  lapply(PI_GRID, function(pi) data.frame(n = n, pi = pi, test = TESTS,
    size = vapply(TESTS, function(ts) exact_size(n, pi, ts), 0))))))
rownames(exact) <- NULL

## --- Monte Carlo check ----------------------------------------------------
cond <- expand.grid(pi = PI_MC, n = N_GRID)
cond$seed <- SEED0 + seq_len(nrow(cond))

t0 <- Sys.time()
mc <- do.call(rbind, lapply(seq_len(nrow(cond)), function(i) {
  n <- cond$n[i]; pi <- cond$pi[i]
  set.seed(cond$seed[i])
  x1 <- rbinom(B, n, pi); x2 <- rbinom(B, n, pi)
  p <- t(mapply(pvals, x1, x2, MoreArgs = list(n = n)))
  rej <- colMeans(!is.na(p) & p <= ALPHA)
  est <- rej[TESTS]
  se  <- sqrt(est * (1 - est) / B)
  target <- vapply(TESTS, function(ts) exact_size(n, pi, ts), 0)
  data.frame(condition = paste0("n", n, "_pi", pi, "_", TESTS), n = n, pi = pi,
             test = TESTS, seed = cond$seed[i], target = target,
             estimate = est, se = se, lower = est - Z99 * se,
             upper = est + Z99 * se,
             pass = target >= est - Z99 * se & target <= est + Z99 * se)
}))
rownames(mc) <- NULL
cat(sprintf("Monte Carlo, %d conditions x B = %d: %.1f s\n", nrow(mc), B,
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

## --- summaries -------------------------------------------------------------
summ <- do.call(rbind, lapply(split(exact, list(exact$n, exact$test)), function(d)
  data.frame(n = d$n[1], test = d$test[1], max_size = max(d$size),
             pi_at_max = d$pi[which.max(d$size)], mean_size = mean(d$size),
             share_pi_above_alpha = mean(d$size > ALPHA))))
summ <- summ[order(summ$test, summ$n), ]
rownames(summ) <- NULL

write.csv(exact, file.path(TAB_DIR, "40_fisher_size_exact.csv"), row.names = FALSE)
write.csv(mc,    file.path(TAB_DIR, "40_fisher_size_mc.csv"),    row.names = FALSE)
write.csv(summ,  file.path(TAB_DIR, "40_fisher_size_summary.csv"), row.names = FALSE)

## --- figure ----------------------------------------------------------------
lab <- c(fisher = "Fisher exact", midp = "Fisher mid-p",
         pearson = "Pearson chi-square", yates = "Yates chi-square")
exact$test_lab <- factor(lab[exact$test], levels = lab)
mc$test_lab    <- factor(lab[mc$test], levels = lab)
panel_lv <- paste0("n = ", N_GRID, " per group")   # numeric, not alphabetic, order
exact$panel <- factor(paste0("n = ", exact$n, " per group"), levels = panel_lv)
mc$panel    <- factor(paste0("n = ", mc$n, " per group"), levels = panel_lv)
fig <- ggplot(exact, aes(pi, size, colour = test_lab)) +
  geom_hline(yintercept = ALPHA, linetype = "dashed", colour = "grey30") +
  geom_line(linewidth = 0.5) +
  geom_pointrange(data = mc, aes(y = estimate, ymin = lower, ymax = upper),
                  size = 0.15, position = position_dodge(width = 0.04)) +
  facet_wrap(~ panel, ncol = 3) +
  scale_colour_manual(values = c("#1b6ca8", "#7fb3d5", "#c0392b", "#e59866"),
                      name = NULL) +
  labs(x = expression(pi ~ "(common event probability under H0)"),
       y = "Actual size (alpha = 0.05)",
       title = "Size of two-sample tests for a 2 x 2 table",
       subtitle = sprintf("Lines: exact size by enumeration. Points: Monte Carlo, B = %d, 99%% interval.", B)) +
  theme_bw(base_size = 10) + theme(legend.position = "bottom")
ggsave(file.path(FIG_DIR, "40_fisher_size_curve.png"), fig, width = 9, height = 6, dpi = 150)

## --- console ---------------------------------------------------------------
cat(sprintf("\nMC check: %d / %d conditions pass (expected false fails ~ %.2f)\n",
            sum(mc$pass), nrow(mc), 0.01 * nrow(mc)))
if (any(!mc$pass)) print(mc[!mc$pass, c("condition", "target", "estimate", "lower", "upper")])
cat("\nFisher exact: size <= alpha at every pi and n? ",
    all(exact$size[exact$test == "fisher"] <= ALPHA), "\n\n")
print(within(summ, { max_size <- round(max_size, 4); mean_size <- round(mean_size, 4)
                     share_pi_above_alpha <- round(share_pi_above_alpha, 2) }),
      row.names = FALSE)
