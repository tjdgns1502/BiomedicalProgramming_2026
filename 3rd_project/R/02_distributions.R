## 02_distributions.R -----------------------------------------------------
## Build and validate the 64 distribution pairs used by the main grid.
##
## Construction (see report, "4 constraints vs 3 parameters"):
##   X = 2-parameter base (lognormal or gamma), median fixed at 1,
##       skewness set to the target.
##   Y = 3-parameter SHIFTED version of the same family, solved so that
##       mean(Y) = mean(X), median(Y) = median(X), sd(Y) = ratio * sd(X).
##   skew(Y) is NOT free -- it is whatever the three equations leave.
##
## Convention note. This script uses the ASSIGNMENT's labelling, in which
## Y is the WIDER distribution (sd_Y = ratio * sd_X). Fagerland's Table 2
## uses the opposite labelling: his X is the wider one ("the standard
## deviation of X is 10% greater than that of Y"). Both are reported;
## for continuous distributions P_paper = 1 - P_ours.
##
## Standalone:  Rscript R/02_distributions.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

SKEWS  <- c(1, 2, 3, 4)
RATIOS <- c(1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.40, 1.50)
FAMS   <- c("gamma", "lognormal")
N_VALID <- 2e6                      # draws for the empirical validation

## ------------------------------------------------------------------
## exact P(X < Y) by quadrature:  P = E_Y[F_X(Y)] = int_0^1 F_X(Q_Y(u)) du
## (no Monte Carlo error; the 2e6-draw estimate below is a cross-check)
## ------------------------------------------------------------------
cdf_of <- function(spec) {
  if (spec$family == "lognormal")
    function(q) plnorm(q - spec$gamma, spec$meanlog, spec$sdlog)
  else
    function(q) pgamma(q - spec$gamma, shape = spec$shape, scale = spec$scale)
}
qf_of <- function(spec) {
  if (spec$family == "lognormal")
    function(p) spec$gamma + qlnorm(p, spec$meanlog, spec$sdlog)
  else
    function(p) spec$gamma + qgamma(p, shape = spec$shape, scale = spec$scale)
}
p_less_exact <- function(sx, sy) {
  Fx <- cdf_of(sx); Qy <- qf_of(sy)
  integrate(function(u) Fx(Qy(u)), 0, 1,
            rel.tol = 1e-12, subdivisions = 2000L)
}

## ------------------------------------------------------------------
## attainable-SD boundary of each family
## ------------------------------------------------------------------
gb <- GAMMA_BOUNDARY_SKEW(); lb <- LNORM_BOUNDARY_SKEW()
cat("\n== Attainable-SD turnover of the 3-parameter shifted families ==\n")
cat("  With mean and median pinned to the base's, the attainable SD of the\n")
cat("  shifted family is MINIMISED at a finite shape. Base skewness above\n")
cat("  that turnover sits on the reversing branch.\n")
cat(sprintf("    gamma     : turnover at shape %.5f  => skewness %.4f\n",
            gamma_kmin(), gb))
cat(sprintf("    lognormal : turnover at k = phi = %.5f => skewness %.4f\n",
            PHI, lb))
cat("  Base skewness levels used here: ", paste(SKEWS, collapse = ", "), "\n",
    sep = "")
cat(sprintf("    gamma skew 4 (%.1f) is PAST the gamma turnover (%.3f).\n", 4, gb))
cat("    All four lognormal levels are below the lognormal turnover.\n")

## ------------------------------------------------------------------
## build all 64 pairs
## ------------------------------------------------------------------
cat("\n== Building 64 distribution pairs ==\n")
pairs <- list(); k <- 0L
for (fam in FAMS) for (sk in SKEWS) for (rr in RATIOS) {
  k <- k + 1L
  X <- if (fam == "lognormal") base_lnorm(sk) else base_gamma(sk)
  target_sd <- rr * X$sd
  Y <- if (fam == "lognormal")
    fit_shifted_lnorm(m = X$mean, med = X$median, s = target_sd)
  else
    fit_shifted_gamma(m = X$mean, med = X$median, s = target_sd,
                      k_base = X$shape, branch = "continuity")

  ## second exact solution on the far side of the turnover (gamma only;
  ## for the lognormal the other branch exists too but the base is always
  ## on the k < phi side, so the alternate is reported for gamma).
  Yalt <- if (fam == "gamma")
    tryCatch(fit_shifted_gamma(X$mean, X$median, target_sd,
                               k_base = X$shape, branch = "other"),
             error = function(e) NULL) else NULL

  mx <- spec_moments(X); my <- spec_moments(Y)
  pl <- p_less_exact(X, Y)

  pairs[[k]] <- list(
    id = k, family = fam, skew_target = sk, sd_ratio = rr,
    X = X, Y = Y, Y_alt = Yalt,
    branch = Y$branch %||% "lnorm",
    p_less_alt = if (!is.null(Yalt)) p_less_exact(X, Yalt)$value else NA_real_,
    skew_Y_alt = if (!is.null(Yalt)) Yalt$skew else NA_real_,
    ## exact population moments recomputed from the fitted parameters
    mom_X = mx, mom_Y = my,
    ## how well the three constraints are met, in exact arithmetic
    err_mean   = abs(my["mean"]   - mx["mean"]),
    err_median = abs(my["median"] - mx["median"]),
    err_sd     = abs(my["sd"]     - target_sd),
    err_sd_rel = abs(my["sd"] / mx["sd"] - rr),
    resid      = Y$resid,                       # root-finder residual
    target_sd  = target_sd,
    skew_Y     = unname(my["skew"]),
    p_less_ours  = pl$value,                    # P(X < Y), Y wider
    p_less_paper = 1 - pl$value,                # paper's labelling
    quad_abserr  = pl$abs.error
  )
}
cat("built ", length(pairs), " pairs\n", sep = "")

## ------------------------------------------------------------------
## FAIL LOUDLY on any bad fit
## ------------------------------------------------------------------
fit_tab <- do.call(rbind, lapply(pairs, function(p) data.frame(
  id = p$id, family = p$family, skew_X = p$skew_target, sd_ratio = p$sd_ratio,
  resid = p$resid, err_mean = p$err_mean, err_median = p$err_median,
  err_sd = p$err_sd, err_sd_rel = p$err_sd_rel,
  quad_abserr = p$quad_abserr, row.names = NULL
)))

TOL <- 1e-9
bad <- fit_tab[fit_tab$resid > TOL | fit_tab$err_mean > TOL |
                 fit_tab$err_median > TOL | fit_tab$err_sd > TOL, ]
cat("\n-- convergence residuals over all 64 pairs --\n")
print(sapply(fit_tab[, c("resid", "err_mean", "err_median",
                         "err_sd", "err_sd_rel", "quad_abserr")], max))
if (nrow(bad)) {
  cat("\nBAD FITS:\n"); print(bad)
  stop("02_distributions.R: at least one fit failed the ", TOL, " tolerance.")
}
cat("all 64 fits within tolerance ", TOL, "\n", sep = "")

## ------------------------------------------------------------------
## empirical validation with N_VALID draws per distribution
## ------------------------------------------------------------------
samp_skew <- function(v) {
  m <- mean(v); s <- sqrt(mean((v - m)^2))
  mean((v - m)^3) / s^3
}

cat("\n== Empirical validation (", format(N_VALID, big.mark = ","),
    " draws per distribution) ==\n", sep = "")
streams <- make_streams(length(pairs), SEED + 200L)

valid <- do.call(rbind, lapply(seq_along(pairs), function(i) {
  p <- pairs[[i]]
  use_stream(streams[[i]])
  xs <- rspec(p$X, N_VALID); ys <- rspec(p$Y, N_VALID)
  data.frame(
    id = p$id, family = p$family, skew_X = p$skew_target,
    sd_ratio = p$sd_ratio,
    emp_mean_X = mean(xs), emp_mean_Y = mean(ys),
    emp_med_X = median(xs), emp_med_Y = median(ys),
    emp_sd_X = sd(xs), emp_sd_Y = sd(ys),
    emp_skew_X = samp_skew(xs), emp_skew_Y = samp_skew(ys),
    emp_sd_ratio = sd(ys) / sd(xs),
    emp_p_less = mean(xs < ys),
    row.names = NULL
  )
}))

valid$exact_mean   <- sapply(pairs, function(p) unname(p$mom_X["mean"]))
valid$exact_med    <- sapply(pairs, function(p) unname(p$mom_X["median"]))
valid$exact_sd_X   <- sapply(pairs, function(p) unname(p$mom_X["sd"]))
valid$exact_sd_Y   <- sapply(pairs, function(p) unname(p$mom_Y["sd"]))
valid$exact_skew_Y <- sapply(pairs, function(p) p$skew_Y)
valid$exact_p_less <- sapply(pairs, function(p) p$p_less_ours)

## how far the 2e6-draw estimates sit from the exact values
emp_dev <- c(
  mean_X   = max(abs(valid$emp_mean_X - valid$exact_mean)),
  mean_Y   = max(abs(valid$emp_mean_Y - valid$exact_mean)),
  median_X = max(abs(valid$emp_med_X  - valid$exact_med)),
  median_Y = max(abs(valid$emp_med_Y  - valid$exact_med)),
  sd_X     = max(abs(valid$emp_sd_X   - valid$exact_sd_X)),
  sd_Y     = max(abs(valid$emp_sd_Y   - valid$exact_sd_Y)),
  skew_X   = max(abs(valid$emp_skew_X - valid$skew_X)),
  skew_Y   = max(abs(valid$emp_skew_Y - valid$exact_skew_Y)),
  p_less   = max(abs(valid$emp_p_less - valid$exact_p_less))
)
cat("\nmax |empirical - exact| across the 64 pairs:\n")
print(signif(emp_dev, 3))
cat("\n(MC SE of P(X<Y) at n=2e6 is ", signif(sqrt(0.25 / N_VALID), 3),
    "; sample skewness is the slowest to settle, as expected for\n",
    " right-skewed data, so its deviation is the largest.)\n", sep = "")

## ------------------------------------------------------------------
## reproduce the guide's lognormal reference table (skew 3, ratios 1.05-1.20)
## ------------------------------------------------------------------
guide_ref <- data.frame(
  sd_ratio = c(NA, 1.05, 1.10, 1.15, 1.20),
  g_gamma  = c(0,       -0.2323, -0.4620, -0.6945, -0.9326),
  g_meanlog= c(0,        0.2098,  0.3796,  0.5274,  0.6590),
  g_sdlog  = c(0.71557,  0.6519,  0.6033,  0.5637,  0.5303),
  g_sd     = c(1.0563,   1.1091,  1.1620,  1.2148,  1.2676),
  g_skew   = c(3.00,     2.57,    2.28,    2.06,    1.89)
)
lx <- base_lnorm(3)
mine <- rbind(
  data.frame(sd_ratio = NA, gamma = lx$gamma, meanlog = lx$meanlog,
             sdlog = lx$sdlog, sd = lx$sd, skew = lx$skew),
  do.call(rbind, lapply(c(1.05, 1.10, 1.15, 1.20), function(rr) {
    y <- fit_shifted_lnorm(lx$mean, lx$median, rr * lx$sd)
    data.frame(sd_ratio = rr, gamma = y$gamma, meanlog = y$meanlog,
               sdlog = y$sdlog, sd = y$sd, skew = y$skew)
  }))
)
guide_cmp <- data.frame(
  row      = c("base X", sprintf("%.2f", c(1.05, 1.10, 1.15, 1.20))),
  gamma    = round(mine$gamma, 4),   guide_gamma   = guide_ref$g_gamma,
  meanlog  = round(mine$meanlog, 4), guide_meanlog = guide_ref$g_meanlog,
  sdlog    = round(mine$sdlog, 5),   guide_sdlog   = guide_ref$g_sdlog,
  sd       = round(mine$sd, 4),      guide_sd      = guide_ref$g_sd,
  skew     = round(mine$skew, 2),    guide_skew    = guide_ref$g_skew
)
guide_maxdiff <- c(
  gamma   = max(abs(round(mine$gamma, 4)   - guide_ref$g_gamma)),
  meanlog = max(abs(round(mine$meanlog, 4) - guide_ref$g_meanlog)),
  sdlog   = max(abs(round(mine$sdlog, 5)   - guide_ref$g_sdlog)),
  sd      = max(abs(round(mine$sd, 4)      - guide_ref$g_sd)),
  skew    = max(abs(round(mine$skew, 2)    - guide_ref$g_skew))
)
cat("\n== Guide's lognormal reference table (skew 3) ==\n")
print(guide_cmp, row.names = FALSE)
cat("\nmax |mine - guide| at the guide's printed precision:\n")
print(guide_maxdiff)

## The guide's meanlog column is internally inconsistent with its own gamma
## column: by construction meanlog = log(median - gamma) = log(1 - gamma).
## Recomputing meanlog from the guide's OWN gamma values reproduces ours.
guide_implied_meanlog <- log(1 - guide_ref$g_gamma)
meanlog_selfcheck <- data.frame(
  row = guide_cmp$row,
  guide_gamma = guide_ref$g_gamma,
  guide_meanlog_printed = guide_ref$g_meanlog,
  implied_by_guide_gamma = round(guide_implied_meanlog, 4),
  ours = round(mine$meanlog, 4)
)
cat("\n-- is the guide's meanlog column consistent with its own gamma? --\n")
print(meanlog_selfcheck, row.names = FALSE)
cat("max |ours - log(1 - guide_gamma)| : ",
    signif(max(abs(mine$meanlog - guide_implied_meanlog)), 3), "\n", sep = "")

cols_ok <- guide_maxdiff[c("gamma", "sdlog", "sd", "skew")] <= 5e-4
cat("\ngamma / sdlog / sd / skew columns match the guide : ",
    all(cols_ok), "\n", sep = "")
cat("meanlog column matches as printed                 : ",
    guide_maxdiff[["meanlog"]] <= 5e-4, "\n", sep = "")
cat("meanlog column matches the guide's own gamma      : ",
    max(abs(mine$meanlog - guide_implied_meanlog)) <= 5e-4, "\n", sep = "")
guide_match <- all(cols_ok) &&
  max(abs(mine$meanlog - guide_implied_meanlog)) <= 5e-4

## ------------------------------------------------------------------
## Table 2 comparison (paper's labelling: X is the wider distribution)
## ------------------------------------------------------------------
paper_t2 <- matrix(c(
  ## gamma, rows = sd ratio, cols = skew 1,2,3,4
  0.50, 0.51, 0.54, 0.58,
  0.51, 0.52, 0.56, 0.61,
  0.51, 0.53, 0.57, 0.62,
  0.52, 0.54, 0.58, 0.64,
  0.52, 0.54, 0.59, 0.64,
  0.52, 0.55, 0.60, 0.66,
  0.53, 0.56, 0.61, 0.67,
  0.53, 0.57, 0.62, 0.68,
  ## lognormal
  0.50, 0.51, 0.51, 0.51,
  0.51, 0.51, 0.52, 0.52,
  0.51, 0.52, 0.53, 0.53,
  0.52, 0.53, 0.53, 0.54,
  0.52, 0.53, 0.54, 0.56,
  0.52, 0.53, 0.55, 0.55,
  0.52, 0.54, 0.56, 0.57,
  0.53, 0.55, 0.56, 0.58
), ncol = 4, byrow = TRUE)
paper_long <- data.frame(
  family = rep(c("gamma", "lognormal"), each = 32),
  sd_ratio = rep(rep(RATIOS, each = 4), 2),
  skew_X = rep(SKEWS, 16),
  paper_p = as.vector(t(paper_t2))
)

t2 <- merge(
  data.frame(family = sapply(pairs, `[[`, "family"),
             skew_X = sapply(pairs, `[[`, "skew_target"),
             sd_ratio = sapply(pairs, `[[`, "sd_ratio"),
             ours_p_paperconv = sapply(pairs, `[[`, "p_less_paper"),
             ours_p_ourconv   = sapply(pairs, `[[`, "p_less_ours"),
             skew_Y = sapply(pairs, `[[`, "skew_Y")),
  paper_long, by = c("family", "sd_ratio", "skew_X"))
t2$diff <- t2$ours_p_paperconv - t2$paper_p

fmt_t2 <- function(fam, col) {
  d <- t2[t2$family == fam, ]
  m <- matrix(NA_real_, 8, 4, dimnames = list(sprintf("%.2f", RATIOS),
                                              paste0("skew", SKEWS)))
  for (i in seq_len(nrow(d)))
    m[sprintf("%.2f", d$sd_ratio[i]), paste0("skew", d$skew_X[i])] <- d[[col]][i]
  round(m, 3)
}
cat("\n== Table 2: our exact P(X<Y), PAPER labelling (X = wider) ==\n")
cat("\n-- gamma, ours --\n");     print(fmt_t2("gamma", "ours_p_paperconv"))
cat("\n-- gamma, paper --\n");    print(fmt_t2("gamma", "paper_p"))
cat("\n-- lognormal, ours --\n"); print(fmt_t2("lognormal", "ours_p_paperconv"))
cat("\n-- lognormal, paper --\n");print(fmt_t2("lognormal", "paper_p"))
cat("\n-- differences (ours - paper) --\n")
cat("gamma:\n");     print(fmt_t2("gamma", "diff"))
cat("lognormal:\n"); print(fmt_t2("lognormal", "diff"))
cat("\nmax |diff| gamma     : ",
    signif(max(abs(t2$diff[t2$family == "gamma"])), 3), "\n", sep = "")
cat("max |diff| lognormal : ",
    signif(max(abs(t2$diff[t2$family == "lognormal"])), 3), "\n", sep = "")

cat("\n== Skewness of Y (cannot be held equal to X) ==\n")
cat("-- gamma --\n");     print(fmt_t2("gamma", "skew_Y"))
cat("-- lognormal --\n"); print(fmt_t2("lognormal", "skew_Y"))

## ------------------------------------------------------------------
## SENSITIVITY A: the second exact solution for gamma (other branch)
## ------------------------------------------------------------------
t2$ours_alt_paperconv <- NA_real_
t2$skew_Y_alt <- NA_real_
key <- paste(sapply(pairs, `[[`, "family"), sapply(pairs, `[[`, "sd_ratio"),
             sapply(pairs, `[[`, "skew_target"))
t2key <- paste(t2$family, t2$sd_ratio, t2$skew_X)
mm <- match(t2key, key)
t2$ours_alt_paperconv <- 1 - sapply(pairs, `[[`, "p_less_alt")[mm]
t2$skew_Y_alt <- sapply(pairs, `[[`, "skew_Y_alt")[mm]

cat("\n== SENSITIVITY A: gamma, second exact solution (other branch) ==\n")
cat("Both branches satisfy mean/median/SD-ratio exactly; they differ in\n")
cat("which side of the attainable-SD turnover the shape lands on.\n")
cat("\n-- P(X<Y), paper labelling, alternate branch --\n")
print(fmt_t2("gamma", "ours_alt_paperconv"))
cat("\n-- skewness of Y, alternate branch --\n")
print(fmt_t2("gamma", "skew_Y_alt"))

## ------------------------------------------------------------------
## SENSITIVITY B: keep {mean, skewness, SD ratio}, drop equal median
## Y = mean_X + ratio * (X - mean_X). Skewness is preserved exactly,
## which is the paper's fourth claim; the median is what breaks.
## ------------------------------------------------------------------
sensB <- do.call(rbind, lapply(pairs, function(p) {
  Ys <- fit_scale_about_mean(p$X, p$sd_ratio)
  pl <- p_less_exact(p$X, Ys)$value
  ms <- spec_moments(Ys)
  data.frame(family = p$family, skew_X = p$skew_target, sd_ratio = p$sd_ratio,
             p_less_ourconv = pl, p_less_paperconv = 1 - pl,
             skew_Y = unname(ms["skew"]),
             median_X = unname(p$mom_X["median"]),
             median_Y = unname(ms["median"]),
             median_shift = unname(ms["median"] - p$mom_X["median"]),
             err_mean = abs(unname(ms["mean"]) - unname(p$mom_X["mean"])),
             err_sd_rel = abs(unname(ms["sd"]) / unname(p$mom_X["sd"]) - p$sd_ratio),
             row.names = NULL)
}))
sensB <- merge(sensB, paper_long, by = c("family", "sd_ratio", "skew_X"))
sensB$diff <- sensB$p_less_paperconv - sensB$paper_p

fmtB <- function(fam, col) {
  d <- sensB[sensB$family == fam, ]
  m <- matrix(NA_real_, 8, 4, dimnames = list(sprintf("%.2f", RATIOS),
                                              paste0("skew", SKEWS)))
  for (i in seq_len(nrow(d)))
    m[sprintf("%.2f", d$sd_ratio[i]), paste0("skew", d$skew_X[i])] <- d[[col]][i]
  round(m, 3)
}
cat("\n== SENSITIVITY B: {mean, skewness, SD ratio} exact; median differs ==\n")
cat("Y = mean_X + ratio*(X - mean_X): skewness held EXACTLY equal, as the\n")
cat("paper states, at the cost of the equal-median condition.\n")
cat("max |mean error| : ", signif(max(sensB$err_mean), 3),
    " ; max |SD-ratio error| : ", signif(max(sensB$err_sd_rel), 3), "\n", sep = "")
cat("\n-- P(X<Y), paper labelling --\ngamma:\n")
print(fmtB("gamma", "p_less_paperconv"))
cat("lognormal:\n"); print(fmtB("lognormal", "p_less_paperconv"))
cat("\n-- difference from the paper (ours - paper) --\ngamma:\n")
print(fmtB("gamma", "diff"))
cat("lognormal:\n"); print(fmtB("lognormal", "diff"))
cat("\n-- how far the median has to move --\ngamma:\n")
print(fmtB("gamma", "median_shift"))
cat("lognormal:\n"); print(fmtB("lognormal", "median_shift"))

cmp_fit <- rbind(
  data.frame(construction = "main {mean, median, SD} (equal-median)",
             family = c("gamma", "lognormal"),
             max_abs_diff_vs_paper = c(
               max(abs(t2$diff[t2$family == "gamma"])),
               max(abs(t2$diff[t2$family == "lognormal"]))),
             mean_abs_diff_vs_paper = c(
               mean(abs(t2$diff[t2$family == "gamma"])),
               mean(abs(t2$diff[t2$family == "lognormal"])))),
  data.frame(construction = "sens. B {mean, skew, SD} (equal-skewness)",
             family = c("gamma", "lognormal"),
             max_abs_diff_vs_paper = c(
               max(abs(sensB$diff[sensB$family == "gamma"])),
               max(abs(sensB$diff[sensB$family == "lognormal"]))),
             mean_abs_diff_vs_paper = c(
               mean(abs(sensB$diff[sensB$family == "gamma"])),
               mean(abs(sensB$diff[sensB$family == "lognormal"]))))
)
cat("\n== Which 3-constraint construction is closer to the paper's Table 2? ==\n")
print(cmp_fit, row.names = FALSE, digits = 3)
cat("\n(The main construction stays primary regardless of which is closer:\n")
cat(" it is the one that makes BOTH of the paper's stated null hypotheses\n")
cat(" -- equal means AND equal medians -- exactly true, which is what the\n")
cat(" Type I error argument requires.)\n")

saveRDS(list(pairs = pairs, fit_table = fit_tab, validation = valid,
             emp_deviation = emp_dev, guide_cmp = guide_cmp,
             guide_maxdiff = guide_maxdiff,
             guide_meanlog_selfcheck = meanlog_selfcheck,
             guide_match = guide_match,
             table2 = t2, sensitivity_B = sensB, construction_cmp = cmp_fit,
             gamma_kmin = gamma_kmin(),
             gamma_boundary_skew = gb, lnorm_boundary_skew = lb,
             n_valid = N_VALID,
             skews = SKEWS, ratios = RATIOS, families = FAMS),
        file.path(RES_DIR, "02_distributions.rds"))
cat("\nsaved -> results/02_distributions.rds\n")
