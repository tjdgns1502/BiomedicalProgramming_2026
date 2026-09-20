## 06_permutation_effectsize.R --------------------------------------------
## Three things the paper's argument depends on but does not itself show:
##
##   (1) A permutation test is NOT automatically safe. Permuting the RAW
##       mean difference tests exchangeability, not equal means, so under
##       heteroscedasticity with unequal n it has the wrong size -- the
##       same failure mode as Student's t. Permuting the WELCH statistic
##       (a studentized permutation test) fixes it.
##   (2) The WMW rank-sum test IS a permutation test on ranks. Shown by
##       complete enumeration, so it is an identity, not an approximation.
##   (3) Paired vs unpaired: Var(d) = s1^2 + s2^2 - 2 rho s1 s2.
##       Naming discipline: rank-sum (independent) vs signed-rank (paired).
##
## Standalone:  Rscript R/06_permutation_effectsize.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

ALPHA <- 0.05

## ========================================================================
## (1) raw vs studentized permutation test under heteroscedasticity
## ========================================================================
## p-value convention throughout: (1 + #{as extreme}) / (B + 1), so that a
## permutation p-value can never be exactly 0.
perm_two <- function(x, y, Bp = 499L) {
  n1 <- length(x); n2 <- length(y); N <- n1 + n2
  z <- c(x, y)
  obs_raw  <- mean(x) - mean(y)
  obs_stud <- (mean(x) - mean(y)) / sqrt(var(x) / n1 + var(y) / n2)

  M  <- matrix(z[as.vector(replicate(Bp, sample.int(N)))], nrow = N)
  xs <- M[seq_len(n1), , drop = FALSE]
  ys <- M[(n1 + 1L):N, , drop = FALSE]
  mx <- colMeans(xs); my <- colMeans(ys)
  vx <- (colSums(xs^2) - n1 * mx^2) / (n1 - 1)
  vy <- (colSums(ys^2) - n2 * my^2) / (n2 - 1)

  raw  <- mx - my
  stud <- raw / sqrt(vx / n1 + vy / n2)
  c(raw  = (1 + sum(abs(raw)  >= abs(obs_raw)  - 1e-12)) / (Bp + 1),
    stud = (1 + sum(abs(stud) >= abs(obs_stud) - 1e-12)) / (Bp + 1))
}

DESIGNS <- data.frame(
  n1  = c(10, 10, 40, 25, 10),
  n2  = c(40, 40, 10, 25, 40),
  sd1 = c( 3,  1,  3,  3,  1),
  sd2 = c( 1,  1,  1,  1,  3)
)
DESIGNS$label <- sprintf("n=%d:%d, sd=%g:%g", DESIGNS$n1, DESIGNS$n2,
                         DESIGNS$sd1, DESIGNS$sd2)
BSIM <- 2000L; BPERM <- 499L

cat("\n== (1) permutation tests under heteroscedasticity ==\n")
cat("equal means everywhere, so every rejection is a Type I error\n")
cat("B_sim = ", BSIM, ", B_perm = ", BPERM, ", alpha = ", ALPHA, "\n\n", sep = "")

streams <- make_streams(nrow(DESIGNS), SEED + 600L)
perm_res <- do.call(rbind, lapply(seq_len(nrow(DESIGNS)), function(i) {
  d <- DESIGNS[i, ]
  use_stream(streams[[i]])
  P <- vapply(seq_len(BSIM), function(b) {
    x <- rnorm(d$n1, 0, d$sd1); y <- rnorm(d$n2, 0, d$sd2)
    pp <- perm_two(x, y, BPERM)
    c(perm_raw = pp[["raw"]], perm_stud = pp[["stud"]],
      welch = welch_p(x, y), student = student_p(x, y), wmw = wmw_p(x, y))
  }, numeric(5))
  data.frame(label = d$label,
             perm_raw = 100 * mean(P["perm_raw", ] < ALPHA),
             perm_stud = 100 * mean(P["perm_stud", ] < ALPHA),
             welch = 100 * mean(P["welch", ] < ALPHA),
             student = 100 * mean(P["student", ] < ALPHA),
             wmw = 100 * mean(P["wmw", ] < ALPHA),
             row.names = NULL)
}))
print(perm_res, row.names = FALSE, digits = 3)
cat("\nMC SE at 5% with B_sim = ", BSIM, " : ",
    round(100 * mc_se(0.05, BSIM), 2), " pp\n", sep = "")
cat("\nThe raw-mean-difference permutation test tracks Student's t, not\n")
cat("Welch's: it inflates when the small group has the larger SD and turns\n")
cat("conservative when the large group does. Studentizing repairs it.\n")

## ========================================================================
## (2) the rank permutation test IS the WMW test -- by enumeration
## ========================================================================
cat("\n\n== (2) rank permutation test == WMW, by complete enumeration ==\n")
set.seed(SEED + 601L)
n1e <- 6L; n2e <- 7L; Ne <- n1e + n2e
enum_check <- do.call(rbind, lapply(1:25, function(rep) {
  x <- rnorm(n1e, 0, 1); y <- rnorm(n2e, 0.8, 2)
  z <- c(x, y); r <- rank(z)
  obs <- sum(r[seq_len(n1e)])
  combos <- combn(Ne, n1e)                    # all C(13,6) = 1716 splits
  stats <- colSums(matrix(r[combos], nrow = n1e))
  mu <- n1e * (Ne + 1) / 2
  ## two-sided exact permutation p-value on the rank-sum statistic
  p_perm <- mean(abs(stats - mu) >= abs(obs - mu) - 1e-12)
  p_exact <- suppressWarnings(wilcox.test(x, y, exact = TRUE)$p.value)
  c(n_perms = ncol(combos), p_perm = p_perm, p_wilcox_exact = p_exact,
    diff = abs(p_perm - p_exact))
}))
cat("permutations enumerated per replicate: ", enum_check[1, "n_perms"],
    "  (C(13,6))\n", sep = "")
cat("max |p_permutation - p_wilcox(exact)| over 25 replicates: ",
    signif(max(enum_check[, "diff"]), 3), "\n", sep = "")
cat("identical to machine precision: ", max(enum_check[, "diff"]) < 1e-12,
    "\n", sep = "")
cat("\nSo WMW's null really is 'the labels are exchangeable', which is why it\n")
cat("reacts to a difference in spread and not only to a difference in\n")
cat("location. That is the whole mechanism behind the paper.\n")

## ========================================================================
## (3) paired vs unpaired
## ========================================================================
cat("\n\n== (3) paired t / signed-rank vs independent t / rank-sum ==\n")
NP <- 30L; S1 <- 1; S2 <- 2; DELTA <- 0.8
RHOS <- c(-0.5, 0, 0.3, 0.6, 0.9)
BP <- 10000L

streams3 <- make_streams(length(RHOS), SEED + 602L)
paired_res <- do.call(rbind, lapply(seq_along(RHOS), function(i) {
  rho <- RHOS[i]
  use_stream(streams3[[i]])
  out <- vapply(seq_len(BP), function(b) {
    z1 <- rnorm(NP); z2 <- rho * z1 + sqrt(1 - rho^2) * rnorm(NP)
    x <- S1 * z1; y <- DELTA + S2 * z2          # true mean difference -DELTA
    d <- x - y
    c(paired   = t.test(d)$p.value,
      unpaired = welch_p(x, y),
      signrank = suppressWarnings(
        wilcox.test(d, exact = FALSE, correct = FALSE)$p.value),
      ranksum  = wmw_p(x, y),
      var_d    = var(d))
  }, numeric(5))
  data.frame(rho = rho,
             theory_var_d = S1^2 + S2^2 - 2 * rho * S1 * S2,
             empirical_var_d = mean(out["var_d", ]),
             power_paired_t = 100 * mean(out["paired", ] < ALPHA),
             power_unpaired_t = 100 * mean(out["unpaired", ] < ALPHA),
             power_signed_rank = 100 * mean(out["signrank", ] < ALPHA),
             power_rank_sum = 100 * mean(out["ranksum", ] < ALPHA),
             row.names = NULL)
}))
cat("n pairs = ", NP, ", sd1 = ", S1, ", sd2 = ", S2,
    ", true mean difference = ", -DELTA, ", B = ", BP, "\n\n", sep = "")
print(paired_res, row.names = FALSE, digits = 4)
cat("\nmax |theoretical Var(d) - empirical| : ",
    signif(max(abs(paired_res$theory_var_d - paired_res$empirical_var_d)), 3),
    "\n", sep = "")
cat("Var(d) = s1^2 + s2^2 - 2*rho*s1*s2 is confirmed; positive rho shrinks\n")
cat("it, which is where the paired design's extra power comes from.\n")
cat("\nNaming: the PAIRED rank test is Wilcoxon's SIGNED-RANK test; the\n")
cat("independent-samples one is the RANK-SUM test. Same R function,\n")
cat("different statistic, different null.\n")

## ========================================================================
## (4) effect sizes for Counterexample B
## ========================================================================
cat("\n\n== (4) effect sizes, Counterexample B ==\n")
X <- base_lnorm(3)
Y <- fit_shifted_lnorm(X$mean, X$median, 1.10 * X$sd)
p_less_pop <- integrate(function(u)
  plnorm(Y$gamma + qlnorm(u, Y$meanlog, Y$sdlog), X$meanlog, X$sdlog),
  0, 1, rel.tol = 1e-12)$value

NS_E <- c(25, 50, 100, 250, 500, 1000)
streams4 <- make_streams(length(NS_E), SEED + 603L)
NREP <- 2000L
eff <- do.call(rbind, lapply(seq_along(NS_E), function(i) {
  n <- NS_E[i]
  use_stream(streams4[[i]])
  E <- vapply(seq_len(NREP), function(b) {
    x <- rspec(X, n); y <- rspec(Y, n)
    c(d = cohen_d(x, y), g = hedges_g(x, y), glass = glass_delta(x, y),
      cliff = cliff_delta(x, y), cles = cles(x, y),
      p_welch = welch_p(x, y), p_wmw = wmw_p(x, y))
  }, numeric(7))
  data.frame(n = n,
             cohen_d = mean(E["d", ]), hedges_g = mean(E["g", ]),
             glass_delta = mean(E["glass", ]),
             cliff_delta = mean(E["cliff", ]), cles = mean(E["cles", ]),
             median_p_welch = median(E["p_welch", ]),
             median_p_wmw = median(E["p_wmw", ]),
             row.names = NULL)
}))
cat("population values: P(X<Y) = CLES = ", round(p_less_pop, 5),
    " , Cliff's delta = ", round(1 - 2 * p_less_pop, 5),
    " , true mean difference = 0\n\n", sep = "")
print(eff, row.names = FALSE, digits = 4)
cat("\nThe point of the table: every effect size is essentially CONSTANT in n,\n")
cat("while the WMW p-value collapses toward 0. The effect (Cliff's delta\n")
cat("about ", round(1 - 2 * p_less_pop, 3), ") is real but tiny; only the\n", sep = "")
cat("p-value creates the impression that it grows with the study.\n")

saveRDS(list(permutation = perm_res, designs = DESIGNS,
             B_sim = BSIM, B_perm = BPERM,
             enumeration = enum_check,
             enum_max_diff = max(enum_check[, "diff"]),
             paired = paired_res, paired_B = BP,
             paired_params = list(n = NP, sd1 = S1, sd2 = S2, delta = DELTA),
             effect_sizes = eff, p_less_pop = p_less_pop, eff_reps = NREP),
        file.path(RES_DIR, "06_permutation_effectsize.rds"))
cat("\nsaved -> results/06_permutation_effectsize.rds\n")
