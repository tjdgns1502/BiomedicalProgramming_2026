## 04b_smalln_wmw_variant.R ----------------------------------------------
## Closing the last reproduction gap.
##
## With the sensitivity-B construction, our Tables 4 and 5 match Fagerland's
## to Monte Carlo noise for every n >= 25, but n = 10 is systematically HIGH
## (WMW 10.9 vs 9.47 gamma; 6.26 vs 5.21 lognormal). The obvious suspect is
## the one thing the assignment forces us to fix: exact = FALSE,
## correct = FALSE. At n = 10 per group with continuous data, wilcox.test()
## would DEFAULT to the exact test, whose discreteness makes the attained
## level sit below the nominal 5%.
##
## This script re-runs the n = 10 row only, under four WMW variants, to see
## which one the paper's number corresponds to.
##
## Standalone:  Rscript R/04b_smalln_wmw_variant.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

B <- 10000L
N <- 10L
ALPHA <- 0.05
RATIOS <- c(1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.40, 1.50)
SKEWS  <- c(1, 2, 3, 4)
FAMS   <- c("gamma", "lognormal")

## sensitivity-B construction (the one that reproduces the paper)
make_pair <- function(fam, sk, rr) {
  X <- if (fam == "lognormal") base_lnorm(sk) else base_gamma(sk)
  list(X = X, Y = fit_scale_about_mean(X, rr))
}

grid <- expand.grid(sd_ratio = RATIOS, skew = SKEWS, family = FAMS,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
cat("\n== n = 10 row, four WMW variants ==\n")
cat("cells: ", nrow(grid), " | B = ", B, " | n = ", N, " per group\n\n",
    sep = "")

STREAMS <- make_streams(nrow(grid), SEED + 400L)  # same seed base as 04

run_cell <- function(i) {
  g <- grid[i, ]
  sp <- make_pair(g$family, g$skew, g$sd_ratio)
  use_stream(STREAMS[[i]])
  acc <- matrix(0, B, 5)
  for (b in seq_len(B)) {
    x <- rspec(sp$X, N); y <- rspec(sp$Y, N)
    pw <- welch_p(x, y)
    acc[b, ] <- c(
      pw,
      wmw_p(x, y),                                                   # ours
      suppressWarnings(wilcox.test(x, y, correct = TRUE,  exact = FALSE)$p.value),
      suppressWarnings(wilcox.test(x, y)$p.value),                   # R default
      suppressWarnings(wilcox.test(x, y, exact = TRUE)$p.value)
    )
  }
  data.frame(
    family = g$family, skew = g$skew, sd_ratio = g$sd_ratio,
    welch        = mean(acc[, 1] < ALPHA),
    wmw_approx   = mean(acc[, 2] < ALPHA),
    wmw_cc       = mean(acc[, 3] < ALPHA),
    wmw_default  = mean(acc[, 4] < ALPHA),
    wmw_exact    = mean(acc[, 5] < ALPHA),
    t5_approx    = mean(acc[, 2] < acc[, 1]),
    t5_default   = mean(acc[, 4] < acc[, 1]),
    row.names = NULL
  )
}

NC <- max(1L, min(parallel::detectCores(), 8L))
t0 <- Sys.time()
cl <- parallel::makeCluster(NC)
parallel::clusterExport(cl, c("grid", "STREAMS", "B", "N", "ALPHA",
                              "make_pair", "run_cell", "welch_p", "wmw_p",
                              "rspec", "use_stream", "base_lnorm", "base_gamma",
                              "fit_scale_about_mean", "sdlog_for_skew",
                              "shape_for_skew", "spec_moments"),
                        envir = environment())
out <- parallel::parLapplyLB(cl, seq_len(nrow(grid)), run_cell)
parallel::stopCluster(cl)
res <- do.call(rbind, out)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

paper_n10 <- data.frame(family = FAMS, paper_t = c(4.01, 4.20),
                        paper_wmw = c(9.47, 5.21), paper_t5 = c(54.1, 45.6))

summ <- do.call(rbind, lapply(FAMS, function(fam) {
  d <- res[res$family == fam, ]
  data.frame(family = fam,
             welch = 100 * mean(d$welch),
             wmw_approx_ours = 100 * mean(d$wmw_approx),
             wmw_cc = 100 * mean(d$wmw_cc),
             wmw_default = 100 * mean(d$wmw_default),
             wmw_exact = 100 * mean(d$wmw_exact),
             t5_approx_ours = 100 * mean(d$t5_approx),
             t5_default = 100 * mean(d$t5_default),
             row.names = NULL)
}))
summ <- merge(summ, paper_n10, by = "family")

cat("-- mean rejection rate (%) over the 32 skew x ratio cells, n = 10 --\n")
print(summ[, c("family", "welch", "paper_t", "wmw_approx_ours", "wmw_cc",
               "wmw_default", "wmw_exact", "paper_wmw")],
      row.names = FALSE, digits = 4)
cat("\n-- P(p_WMW < p_Welch) (%), n = 10 --\n")
print(summ[, c("family", "t5_approx_ours", "t5_default", "paper_t5")],
      row.names = FALSE, digits = 4)

cat("\n-- distance from the paper's n=10 WMW value --\n")
for (i in seq_len(nrow(summ))) {
  cat(sprintf("  %-10s ours(exact=FALSE,correct=FALSE) %+.2f pp | R default %+.2f pp | exact %+.2f pp\n",
              summ$family[i],
              summ$wmw_approx_ours[i] - summ$paper_wmw[i],
              summ$wmw_default[i]     - summ$paper_wmw[i],
              summ$wmw_exact[i]       - summ$paper_wmw[i]))
}
cat("\nelapsed: ", round(elapsed, 1), " s\n", sep = "")

saveRDS(list(results = res, summary = summ, B = B, n = N, elapsed = elapsed,
             paper = paper_n10),
        file.path(RES_DIR, "04b_smalln_wmw_variant.rds"))
cat("saved -> results/04b_smalln_wmw_variant.rds\n")
