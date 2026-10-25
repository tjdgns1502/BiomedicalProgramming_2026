## 05_counterexamples.R ---------------------------------------------------
## Verification task (2): the WMW test is NOT a test of equal medians.
##
## A (minimal)     - medians equal, P(X<Y) = 0.275 exactly. Proves the
##                   point, but the MEANS differ (+-2.25), so Welch also
##                   rejects; it does not show the paradox.
## B (paper-style) - shifted-lognormal pair: mean AND median exactly equal,
##                   SD ratio 1.10. Both of the hypotheses a reader thinks
##                   WMW is testing are TRUE, yet WMW rejects more and more
##                   often as n grows. That is the paradox.
##
## The guide's Counterexample B snippet calls rX(n)/rY(n) separately inside
## each test, i.e. the Welch test and the WMW test see DIFFERENT samples.
## That is a bug; this script uses common random numbers and also
## quantifies what the bug costs.
##
## Standalone:  Rscript R/05_counterexamples.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

B <- 10000L
ALPHA <- 0.05

## ========================================================================
## Counterexample A
## ========================================================================
rX_A <- function(n) ifelse(runif(n) < 0.5, runif(n, -1,   0), runif(n, 0, 10))
rY_A <- function(n) ifelse(runif(n) < 0.5, runif(n, -10,  0), runif(n, 0,  1))

## Exact values, derived in the report:
##   P(X<Y) = 1/4*[ P(X-,Y-) + P(X-,Y+) + P(X+,Y-) + P(X+,Y+) ]
##          = 1/4*[ 0.05     + 1        + 0        + 0.05     ] = 0.275
A_exact <- list(
  p_less = 0.275,
  cliff  = (1 - 0.275) - 0.275,              # = 0.45
  mean_X = 0.5 * (-0.5) + 0.5 * 5,           # = 2.25
  mean_Y = 0.5 * (-5)   + 0.5 * 0.5,         # = -2.25
  median_X = 0, median_Y = 0
)

cat("\n== Counterexample A: minimal construction ==\n")
cat("X = 0.5*U(-1,0) + 0.5*U(0,10);  Y = 0.5*U(-10,0) + 0.5*U(0,1)\n")
cat("exact P(X<Y) = 0.25*(0.05 + 1 + 0 + 0.05) = ", A_exact$p_less, "\n", sep = "")

RNGkind("L'Ecuyer-CMRG"); set.seed(SEED + 500L)
NBIG <- 4e6
xa <- rX_A(NBIG); ya <- rY_A(NBIG)
A_emp <- c(median_X = median(xa), median_Y = median(ya),
           mean_X = mean(xa), mean_Y = mean(ya),
           p_less = mean(xa < ya), cliff = cliff_delta(xa, ya))
cat("\nsimulation with ", format(NBIG, big.mark = ","), " draws:\n", sep = "")
print(round(A_emp, 5))
cat("\n|P(X<Y) simulated - exact| = ",
    signif(abs(A_emp[["p_less"]] - A_exact$p_less), 3),
    "   (MC SE = ", signif(sqrt(0.275 * 0.725 / NBIG), 3), ")\n", sep = "")
cat("Cliff's delta: exact ", A_exact$cliff, ", simulated ",
    round(A_emp[["cliff"]], 5), "\n", sep = "")

## rejection rates at n = 20 per group
streams <- make_streams(1, SEED + 501L); use_stream(streams[[1]])
PA <- vapply(seq_len(B), function(b) three_p(rX_A(20), rY_A(20)), numeric(3))
A_rej <- rowMeans(PA < ALPHA)
cat("\nrejection rates at n = 20 per group (B = ", B, "):\n", sep = "")
print(round(100 * A_rej, 1))
cat("  guide's stated WMW value: ~71%\n")
cat("\n-- the weakness of Counterexample A, stated plainly --\n")
cat("  means differ: ", A_exact$mean_X, " vs ", A_exact$mean_Y,
    " (difference ", A_exact$mean_X - A_exact$mean_Y, ")\n", sep = "")
cat("  so Welch rejects ", round(100 * A_rej[["welch"]], 1),
    "% of the time too. A proves 'WMW is not a median test';\n", sep = "")
cat("  it does NOT prove the paradox, because the t-test is not wrong here.\n")

## ========================================================================
## Counterexample B
## ========================================================================
X <- base_lnorm(3)
Y <- fit_shifted_lnorm(m = X$mean, med = X$median, s = 1.10 * X$sd)
mx <- spec_moments(X); my <- spec_moments(Y)

## P(X < Y) = E_Y[F_X(Y)] = int_0^1 F_X(Q_Y(u)) du, exact to quadrature
p_less_exact_B <- integrate(
  function(u) plnorm(Y$gamma + qlnorm(u, Y$meanlog, Y$sdlog) - X$gamma,
                     X$meanlog, X$sdlog), 0, 1, rel.tol = 1e-12)$value

cat("\n\n== Counterexample B: paper-style construction ==\n")
cat("X: lognormal(meanlog = 0, sdlog = ", round(X$sdlog, 5), ")\n", sep = "")
cat("Y: ", round(Y$gamma, 5), " + lognormal(meanlog = ", round(Y$meanlog, 5),
    ", sdlog = ", round(Y$sdlog, 5), ")\n", sep = "")
cat("\n                    X          Y\n")
cat(sprintf("mean      %10.5f %10.5f   (equal: %s)\n", mx["mean"], my["mean"],
            abs(mx["mean"] - my["mean"]) < 1e-12))
cat(sprintf("median    %10.5f %10.5f   (equal: %s)\n", mx["median"], my["median"],
            abs(mx["median"] - my["median"]) < 1e-12))
cat(sprintf("sd        %10.5f %10.5f   (ratio: %.5f)\n", mx["sd"], my["sd"],
            my["sd"] / mx["sd"]))
cat(sprintf("skewness  %10.5f %10.5f   (NOT equal -- 4 constraints, 3 parameters)\n",
            mx["skew"], my["skew"]))
cat("\nexact P(X < Y) = ", round(p_less_exact_B, 6),
    "   (guide states 0.4824)\n", sep = "")
cat("departure from the null P(X<Y)=0.5 : ",
    round(abs(p_less_exact_B - 0.5), 6), "\n", sep = "")
cat("Cliff's delta (population) = ", round(1 - 2 * p_less_exact_B, 6), "\n", sep = "")

NS_B <- c(25, 50, 100, 250, 500, 1000)
guide_B <- data.frame(n = NS_B,
                      guide_welch = c(4.3, 4.5, 5.0, 4.9, 5.7, 5.1),
                      guide_wmw   = c(5.4, 6.8, 6.9, 10.2, 16.7, 30.0))

streamsB <- make_streams(length(NS_B), SEED + 502L)
resB <- do.call(rbind, lapply(seq_along(NS_B), function(i) {
  n <- NS_B[i]
  use_stream(streamsB[[i]])
  P <- vapply(seq_len(B), function(b) {
    x <- rspec(X, n); y <- rspec(Y, n)     # COMMON random numbers
    three_p(x, y)
  }, numeric(3))
  data.frame(n = n,
             welch   = 100 * mean(P["welch", ]   < ALPHA),
             student = 100 * mean(P["student", ] < ALPHA),
             wmw     = 100 * mean(P["wmw", ]     < ALPHA),
             p_wmw_lt_welch = 100 * mean(P["wmw", ] < P["welch", ]),
             se = 100 * mc_se(0.05, B), row.names = NULL)
}))
resB <- merge(resB, guide_B, by = "n")
resB <- resB[order(resB$n), ]

cat("\n-- rejection rates (%), B = ", B,
    " (the guide used B = 2,000) --\n", sep = "")
print(resB[, c("n", "welch", "guide_welch", "wmw", "guide_wmw",
               "student", "p_wmw_lt_welch")],
      row.names = FALSE, digits = 4)
cat("\nMonte Carlo SE at p=0.05 : ", round(100 * mc_se(0.05, B), 3),
    " pp (guide's B=2,000 gives ", round(100 * mc_se(0.05, 2000), 3),
    " pp)\n", sep = "")

## ---- what the guide's common-random-numbers bug costs ---------------
## Same B, same n, but each test gets its OWN independent sample, exactly
## as the guide's snippet does.
cat("\n-- the guide's snippet draws a fresh sample for each test --\n")
streamsC <- make_streams(length(NS_B), SEED + 503L)
resC <- do.call(rbind, lapply(seq_along(NS_B), function(i) {
  n <- NS_B[i]
  use_stream(streamsC[[i]])
  P <- vapply(seq_len(B), function(b) {
    pw <- welch_p(rspec(X, n), rspec(Y, n))   # one sample
    pm <- wmw_p(rspec(X, n), rspec(Y, n))     # a DIFFERENT sample
    c(welch = pw, wmw = pm)
  }, numeric(2))
  data.frame(n = n,
             welch_sep = 100 * mean(P["welch", ] < ALPHA),
             wmw_sep   = 100 * mean(P["wmw", ]   < ALPHA),
             p_wmw_lt_welch_sep = 100 * mean(P["wmw", ] < P["welch", ]),
             row.names = NULL)
}))
crn <- merge(resB[, c("n", "welch", "wmw", "p_wmw_lt_welch")], resC, by = "n")
print(crn, row.names = FALSE, digits = 4)
cat("\nMarginal rejection rates agree (both are unbiased). What breaks is the\n")
cat("PAIRED quantity P(p_WMW < p_Welch): with independent samples it is\n")
cat("estimated with much larger variance and loses its meaning as a\n")
cat("within-sample comparison, which is exactly what the paper's Table 5 is.\n")

## variance of the paired estimate vs the unpaired one, at n = 250
use_stream(make_streams(1, SEED + 504L)[[1]])
rep_var <- function(paired, reps = 40, n = 250, b = 1000) {
  vapply(seq_len(reps), function(r) {
    if (paired) {
      P <- vapply(seq_len(b), function(i) {
        x <- rspec(X, n); y <- rspec(Y, n); tp <- three_p(x, y)
        c(tp[["welch"]], tp[["wmw"]])
      }, numeric(2))
    } else {
      P <- vapply(seq_len(b), function(i) {
        c(welch_p(rspec(X, n), rspec(Y, n)), wmw_p(rspec(X, n), rspec(Y, n)))
      }, numeric(2))
    }
    mean(P[2, ] < P[1, ])
  }, numeric(1))
}
v_paired <- rep_var(TRUE); v_indep <- rep_var(FALSE)
cat("\nSD of the estimated P(p_WMW < p_Welch) across 40 independent runs of\n")
cat("B = 1,000 at n = 250:\n")
cat("  common random numbers : ", round(100 * sd(v_paired), 3), " pp\n", sep = "")
cat("  independent samples   : ", round(100 * sd(v_indep),  3), " pp\n", sep = "")
cat("  variance ratio        : ", round(var(v_indep) / var(v_paired), 2),
    "x\n", sep = "")

cat("\n-- how to read this --\n")
cat("WMW's rising rejection rate is POWER, not Type I error: its own null\n")
cat("hypothesis P(X<Y) = 0.5 is false here (P = ", round(p_less_exact_B, 4),
    ").\n", sep = "")
cat("The error is in translating that p-value into 'the medians differ',\n")
cat("when the medians are identical by construction.\n")

saveRDS(list(
  A = list(exact = A_exact, empirical = A_emp, n_draws = NBIG,
           rejection_n20 = A_rej, B = B),
  B = list(X = X, Y = Y, mom_X = mx, mom_Y = my,
           p_less_exact = p_less_exact_B,
           cliff = 1 - 2 * p_less_exact_B,
           results = resB, guide = guide_B, B = B, ns = NS_B),
  crn = list(comparison = crn,
             sd_paired = sd(v_paired), sd_indep = sd(v_indep),
             var_ratio = var(v_indep) / var(v_paired))
), file.path(RES_DIR, "05_counterexamples.rds"))
cat("\nsaved -> results/05_counterexamples.rds\n")
