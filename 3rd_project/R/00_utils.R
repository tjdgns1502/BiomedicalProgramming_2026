## 00_utils.R ------------------------------------------------------------
## Fast two-sample test statistics, effect sizes, and distribution fitting.
##
## Everything here is written to be called millions of times inside a
## simulation loop, so there are no formula interfaces, no S3 class
## construction, and no argument checking beyond what is needed.
##
## Runs standalone from a clean R session.
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

RES_DIR <- file.path(PROJ, "results")
FIG_DIR <- file.path(PROJ, "figs")
dir.create(RES_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

## ========================================================================
## 1. Fast test statistics
## ========================================================================

## Satterthwaite degrees of freedom for the Welch test.
##   nu = (a + b)^2 / (a^2/(n1-1) + b^2/(n2-1)),  a = s1^2/n1, b = s2^2/n2
welch_df <- function(x, y) {
  n1 <- length(x); n2 <- length(y)
  a <- var(x) / n1; b <- var(y) / n2
  (a + b)^2 / (a^2 / (n1 - 1) + b^2 / (n2 - 1))
}

## Two-sided Welch t-test p-value (var.equal = FALSE; R's t.test default).
welch_p <- function(x, y) {
  n1 <- length(x); n2 <- length(y)
  a <- var(x) / n1; b <- var(y) / n2
  tt <- (mean(x) - mean(y)) / sqrt(a + b)
  df <- (a + b)^2 / (a^2 / (n1 - 1) + b^2 / (n2 - 1))
  2 * pt(-abs(tt), df)
}

## Two-sided Student (pooled-variance) t-test p-value (var.equal = TRUE).
student_p <- function(x, y) {
  n1 <- length(x); n2 <- length(y)
  df <- n1 + n2 - 2
  sp2 <- ((n1 - 1) * var(x) + (n2 - 1) * var(y)) / df
  tt <- (mean(x) - mean(y)) / sqrt(sp2 * (1 / n1 + 1 / n2))
  2 * pt(-abs(tt), df)
}

## Wilcoxon-Mann-Whitney rank-sum p-value, normal approximation with
## tie-corrected variance and NO continuity correction.
## Reproduces wilcox.test(x, y, exact = FALSE, correct = FALSE)$p.value.
wmw_p <- function(x, y) {
  n1 <- as.numeric(length(x)); n2 <- as.numeric(length(y))
  r <- rank(c(x, y))
  U <- sum(r[seq_len(n1)]) - n1 * (n1 + 1) / 2   # Mann-Whitney U for x
  N <- n1 + n2
  nt <- tabulate(match(r, sort(unique(r))))       # tie-group sizes
  sigma <- sqrt((n1 * n2 / 12) *
                  ((N + 1) - sum(nt^3 - nt) / (N * (N - 1))))
  2 * pnorm(-abs((U - n1 * n2 / 2) / sigma))
}

## Mann-Whitney U for x (number of pairs with x > y, ties counted 1/2),
## computed from ranks so it is O(N log N) rather than O(n1*n2).
## Doubles throughout: n1*n2 overflows integer once n exceeds ~46000, which
## happens in the 2e6-draw validation runs.
mw_u <- function(x, y) {
  n1 <- as.numeric(length(x))
  sum(rank(c(x, y))[seq_len(length(x))]) - n1 * (n1 + 1) / 2
}

## All three p-values from ONE sample pair (common random numbers).
three_p <- function(x, y) {
  n1 <- length(x); n2 <- length(y)
  vx <- var(x); vy <- var(y); md <- mean(x) - mean(y)
  a <- vx / n1; b <- vy / n2

  dfw <- (a + b)^2 / (a^2 / (n1 - 1) + b^2 / (n2 - 1))
  pw  <- 2 * pt(-abs(md / sqrt(a + b)), dfw)

  dfs <- n1 + n2 - 2
  sp2 <- ((n1 - 1) * vx + (n2 - 1) * vy) / dfs
  ps  <- 2 * pt(-abs(md / sqrt(sp2 * (1 / n1 + 1 / n2))), dfs)

  r <- rank(c(x, y))
  U <- sum(r[seq_len(n1)]) - n1 * (n1 + 1) / 2
  N <- n1 + n2
  nt <- tabulate(match(r, sort(unique(r))))
  sigma <- sqrt((n1 * n2 / 12) *
                  ((N + 1) - sum(nt^3 - nt) / (N * (N - 1))))
  pm <- 2 * pnorm(-abs((U - n1 * n2 / 2) / sigma))

  c(welch = pw, student = ps, wmw = pm)
}

## ========================================================================
## 2. Effect sizes
## ========================================================================

cohen_d <- function(x, y) {
  n1 <- length(x); n2 <- length(y)
  sp <- sqrt(((n1 - 1) * var(x) + (n2 - 1) * var(y)) / (n1 + n2 - 2))
  (mean(x) - mean(y)) / sp
}

## Small-sample bias correction; N = n1 + n2.
hedges_g <- function(x, y) {
  N <- length(x) + length(y)
  cohen_d(x, y) * (1 - 3 / (4 * N - 9))
}

## Standardised by the control group's SD only. `control` picks which
## argument plays the control role; with unequal variances the pooled SD
## has no clear meaning, which is why Glass's Delta is used here.
glass_delta <- function(x, y, control = c("y", "x")) {
  control <- match.arg(control)
  s <- if (control == "y") sd(y) else sd(x)
  (mean(x) - mean(y)) / s
}

## Cliff's delta = P(X > Y) - P(X < Y) = 2U/(n1 n2) - 1.
cliff_delta <- function(x, y) {
  n1 <- as.numeric(length(x)); n2 <- as.numeric(length(y))
  2 * mw_u(x, y) / (n1 * n2) - 1
}

## Common-language effect size, CLES = P(X < Y) (ties split evenly).
## Equals 1 - U/(n1 n2); note CLES = (1 - cliff_delta)/2.
cles <- function(x, y) {
  n1 <- as.numeric(length(x)); n2 <- as.numeric(length(y))
  1 - mw_u(x, y) / (n1 * n2)
}

## ========================================================================
## 3. Distribution construction
## ========================================================================
## Target: a pair (X, Y) with
##     mean(Y)   == mean(X)
##     median(Y) == median(X)
##     sd(Y)     == ratio * sd(X)
## X is a 2-parameter base (lognormal or gamma) with a prescribed
## skewness; Y is the corresponding 3-parameter SHIFTED family.
##
## Four targets (mean, median, sd, skewness) against three parameters
## means skewness cannot also be held equal -- see report. Skewness of Y
## is whatever falls out.
##
## Both constructions are scale-equivariant: multiplying X and Y by the
## same constant leaves ratio, skewness and P(X < Y) unchanged. The base
## scale is therefore arbitrary and is fixed by median(X) = 1 throughout,
## which also matches the guide's reference table.

## ---- lognormal -----------------------------------------------------
## Skewness of a lognormal depends on sdlog alone:
##   skew = (e^{s^2} + 2) * sqrt(e^{s^2} - 1)
## Solve for sdlog given a target skewness.
sdlog_for_skew <- function(skew) {
  f <- function(s) (exp(s^2) + 2) * sqrt(exp(s^2) - 1) - skew
  uniroot(f, c(1e-6, 5), tol = .Machine$double.eps^0.75)$root
}

## Base X: lognormal with median 1 (meanlog = 0) and the target skewness.
base_lnorm <- function(skew) {
  sdl <- sdlog_for_skew(skew)
  k <- exp(sdl^2 / 2)
  list(family = "lognormal", meanlog = 0, sdlog = sdl, gamma = 0,
       mean = k, median = 1, sd = k * sqrt(exp(sdl^2) - 1), skew = skew)
}

## Shifted lognormal  Y = g + exp(mu + sigma Z),  A = e^mu, k = e^{sigma^2/2}.
##   median: g + A       = med
##   mean:   g + A k     = m     =>  A = (m - med) / (k - 1)
##   sd:     A k sqrt(k^2 - 1) = s
## Substituting A leaves ONE equation in k:
##   (m - med) * k * sqrt((k + 1)/(k - 1)) = s
## The left side is minimised at k = golden ratio (1+sqrt(5))/2, so there
## are two roots. The admissible branch is k in (1, phi): it is the one
## that contains the base distribution itself at ratio = 1, and it is
## decreasing in k, so a larger SD means a smaller k (less skewed).
PHI <- (1 + sqrt(5)) / 2

fit_shifted_lnorm <- function(m, med, s) {
  d <- m - med
  stopifnot(d > 0, s > 0)
  g <- function(k) d * k * sqrt((k + 1) / (k - 1)) - s
  lo <- 1 + 1e-12
  if (g(PHI) > 0)
    stop(sprintf("target sd %.6g is below the attainable minimum %.6g",
                 s, d * PHI * sqrt((PHI + 1) / (PHI - 1))))
  ## g(lo) = +Inf > 0 and g(PHI) <= 0: bracketed on the (1, phi) branch.
  k <- uniroot(g, c(lo, PHI), tol = .Machine$double.eps^0.75)$root
  A <- d / (k - 1)
  sdl <- sqrt(2 * log(k))
  list(family = "lognormal", meanlog = log(A), sdlog = sdl, gamma = med - A,
       mean = med - A + A * k, median = med,
       sd = A * k * sqrt(k^2 - 1), skew = (k^2 + 2) * sqrt(k^2 - 1),
       resid = abs(g(k)))
}

## ---- gamma ---------------------------------------------------------
## Skewness of a gamma depends on shape alone: skew = 2/sqrt(shape).
shape_for_skew <- function(skew) 4 / skew^2

## Base X: gamma with median 1 and the target skewness.
base_gamma <- function(skew) {
  k <- shape_for_skew(skew)
  th <- 1 / qgamma(0.5, shape = k)          # scale making median 1
  list(family = "gamma", shape = k, scale = th, gamma = 0,
       mean = k * th, median = 1, sd = th * sqrt(k), skew = skew)
}

## Shifted gamma  Y = g + Gamma(shape = k, scale = th).
##   median: g + th q(k) = med,  q(k) = qgamma(0.5, k, scale = 1)
##   mean:   g + th k    = m     =>  th = (m - med) / (k - q(k))
##   sd:     th sqrt(k)  = s
## leaving ONE equation in k:  (m - med) * sqrt(k) / (k - q(k)) = s.
## As with the lognormal the left side has an interior minimum, so the
## branch containing the base shape is selected numerically.
## Shape at which the attainable SD is minimised, and the corresponding
## skewness. Computed once and cached: this is the boundary past which the
## construction reverses direction (see GAMMA_BOUNDARY below).
gamma_kmin <- local({
  cached <- NULL
  function() {
    if (is.null(cached)) {
      hh0 <- function(k) sqrt(k) / (k - qgamma(0.5, shape = k))
      grid <- exp(seq(log(1e-2), log(1e4), length.out = 4000))
      v <- vapply(grid, hh0, numeric(1))
      i <- which.min(v)
      cached <<- optimize(hh0, c(grid[max(i - 1, 1)],
                                 grid[min(i + 1, length(grid))]),
                          tol = 1e-12)$minimum
    }
    cached
  }
})

## `branch`:
##   "continuity" - the branch containing the base shape, so that Y -> X
##                  continuously as ratio -> 1. This is the default and the
##                  primary construction used throughout the project.
##   "other"      - the second exact solution, on the far side of the
##                  attainable-SD minimum. Used only for sensitivity.
fit_shifted_gamma <- function(m, med, s, k_base,
                              branch = c("continuity", "other")) {
  branch <- match.arg(branch)
  d <- m - med
  stopifnot(d > 0, s > 0)
  hh <- function(k) d * sqrt(k) / (k - qgamma(0.5, shape = k))
  kmin <- gamma_kmin()

  left <- (k_base < kmin)
  if (branch == "other") left <- !left
  if (left) {
    lo <- 1e-6;  hi <- kmin                # hh decreasing in k here
  } else {
    lo <- kmin;  hi <- 1e7                 # hh increasing in k here
  }
  if ((hh(lo) - s) * (hh(hi) - s) > 0)
    stop(sprintf("target sd %.6g not attainable on this branch (min %.6g)",
                 s, hh(kmin)))
  k <- uniroot(function(k) hh(k) - s, c(lo, hi),
               tol = .Machine$double.eps^0.75)$root
  th <- d / (k - qgamma(0.5, shape = k))
  g <- med - th * qgamma(0.5, shape = k)       # shift set by the MEDIAN condition
  list(family = "gamma", shape = k, scale = th, gamma = g,
       mean = g + th * k,                      # recomputed, not copied
       median = g + th * qgamma(0.5, shape = k),
       sd = th * sqrt(k), skew = 2 / sqrt(k),
       resid = abs(hh(k) - s), branch = if (left) "left" else "right")
}

## Boundary skewness of each family: the base skewness at which the
## attainable-SD curve turns over. A base MORE skewed than this lies on the
## reversing branch, where making Y wider makes it MORE skewed instead of
## less. gamma ~ 3.748, lognormal ~ 5.874 (the latter is exactly
## (phi^2 + 2) sqrt(phi^2 - 1), since the lognormal turnover is at
## k = e^{sigma^2/2} = phi).
GAMMA_BOUNDARY_SKEW <- function() 2 / sqrt(gamma_kmin())
LNORM_BOUNDARY_SKEW <- function() (PHI^2 + 2) * sqrt(PHI^2 - 1)

## ---- alternative 3-constraint construction (sensitivity only) -------
## The paper asks for equal mean, median, SD-ratio AND equal skewness:
## four constraints on three parameters. The main construction drops
## "equal skewness". This one instead drops "equal median" and keeps
## {mean, skewness, SD ratio}. For any location-scale-shifted family that
## forces Y to be X rescaled about its own mean:
##     Y = mean_X + ratio * (X - mean_X)
## so skewness is preserved exactly and the median moves by
##     median_Y - median_X = (ratio - 1) * (mean_X - median_X).
fit_scale_about_mean <- function(X, ratio) {
  m <- X$mean
  if (X$family == "lognormal") {
    ## m + r*(g + e^{mu+sZ} - m) = (m + r*(g - m)) + e^{mu+log r + sZ}
    list(family = "lognormal", meanlog = X$meanlog + log(ratio),
         sdlog = X$sdlog, gamma = m + ratio * (X$gamma - m),
         mean = m, median = m + ratio * (X$median - m),
         sd = ratio * X$sd, skew = X$skew, resid = 0, branch = "scale")
  } else {
    list(family = "gamma", shape = X$shape, scale = ratio * X$scale,
         gamma = m + ratio * (X$gamma - m),
         mean = m, median = m + ratio * (X$median - m),
         sd = ratio * X$sd, skew = X$skew, resid = 0, branch = "scale")
  }
}

## ---- samplers ------------------------------------------------------
## A "spec" is any list from base_* / fit_shifted_*.
rspec <- function(spec, n) {
  if (spec$family == "lognormal")
    spec$gamma + rlnorm(n, meanlog = spec$meanlog, sdlog = spec$sdlog)
  else
    spec$gamma + rgamma(n, shape = spec$shape, scale = spec$scale)
}

## Exact (population) moments implied by a spec, recomputed from the
## parameters -- used to check the fit rather than trusting the targets.
spec_moments <- function(spec) {
  if (spec$family == "lognormal") {
    A <- exp(spec$meanlog); k <- exp(spec$sdlog^2 / 2)
    c(mean = spec$gamma + A * k,
      median = spec$gamma + A,
      sd = A * k * sqrt(k^2 - 1),
      skew = (k^2 + 2) * sqrt(k^2 - 1))
  } else {
    k <- spec$shape; th <- spec$scale
    c(mean = spec$gamma + k * th,
      median = spec$gamma + th * qgamma(0.5, shape = k),
      sd = th * sqrt(k),
      skew = 2 / sqrt(k))
  }
}

## ========================================================================
## 4. Simulation plumbing
## ========================================================================

## Monte Carlo standard error of an estimated proportion.
mc_se <- function(p, B) sqrt(p * (1 - p) / B)

## Build `n` mutually independent L'Ecuyer-CMRG streams from one seed.
## Assigning stream i to grid cell i makes every cell reproducible on its
## own, independent of worker count and of task scheduling order.
make_streams <- function(n, seed) {
  old_kind <- RNGkind("L'Ecuyer-CMRG")
  on.exit(RNGkind(old_kind[1]), add = TRUE)
  set.seed(seed)
  s <- .Random.seed
  out <- vector("list", n)
  for (i in seq_len(n)) { out[[i]] <- s; s <- parallel::nextRNGStream(s) }
  out
}

## Install a stream into the current session's RNG state.
use_stream <- function(stream) {
  RNGkind("L'Ecuyer-CMRG")
  assign(".Random.seed", stream, envir = globalenv())
  invisible(NULL)
}

## Consistent seed base for the whole project.
SEED <- 20260920L
