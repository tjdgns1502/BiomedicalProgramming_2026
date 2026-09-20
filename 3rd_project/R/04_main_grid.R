## 04_main_grid.R ---------------------------------------------------------
## The 448-scenario Type I error simulation.
##
##   n in {10,25,50,100,250,500,1000} per group      (7)
##   SD ratio in {1.05,...,1.50}                     (8)
##   skewness in {1,2,3,4}                           (4)
##   family in {gamma, lognormal}                    (2)   = 448 cells
##
## Within a replicate the SAME sample pair goes to Welch, Student and WMW
## (common random numbers), which is what makes P(p_WMW < p_Welch) -- the
## paper's Table 5 -- a paired comparison rather than a comparison of two
## independent runs.
##
## Seeding. One L'Ecuyer-CMRG stream PER CELL, all derived from a single
## seed via nextRNGStream. Cells are therefore independent of each other
## and each cell reproduces identically regardless of how many workers run
## it or in what order -- unlike clusterSetRNGStream + load balancing,
## which depends on both.
##
## Usage:
##   Rscript R/04_main_grid.R                 # full run, B = 10000
##   Rscript R/04_main_grid.R 500 pilot       # pilot
##   Rscript R/04_main_grid.R 10000 sensB     # sensitivity-B construction
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

args <- commandArgs(trailingOnly = TRUE)
B    <- if (length(args) >= 1) as.integer(args[1]) else 10000L
TAG  <- if (length(args) >= 2) args[2] else "full"
CONSTRUCTION <- if (identical(TAG, "sensB")) "sensB" else "main"

NS     <- c(10, 25, 50, 100, 250, 500, 1000)
RATIOS <- c(1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.40, 1.50)
SKEWS  <- c(1, 2, 3, 4)
FAMS   <- c("gamma", "lognormal")
ALPHA  <- 0.05

## ------------------------------------------------------------------
## distribution pairs (fit once in the master, then exported)
## ------------------------------------------------------------------
make_pair <- function(fam, sk, rr, construction) {
  X <- if (fam == "lognormal") base_lnorm(sk) else base_gamma(sk)
  if (construction == "sensB") {
    Y <- fit_scale_about_mean(X, rr)
  } else if (fam == "lognormal") {
    Y <- fit_shifted_lnorm(X$mean, X$median, rr * X$sd)
  } else {
    Y <- fit_shifted_gamma(X$mean, X$median, rr * X$sd,
                           k_base = X$shape, branch = "continuity")
  }
  list(X = X, Y = Y)
}

spec_key <- function(fam, sk, rr) sprintf("%s|%g|%g", fam, sk, rr)
SPECS <- list()
for (fam in FAMS) for (sk in SKEWS) for (rr in RATIOS)
  SPECS[[spec_key(fam, sk, rr)]] <- make_pair(fam, sk, rr, CONSTRUCTION)

grid <- expand.grid(n = NS, sd_ratio = RATIOS, skew = SKEWS, family = FAMS,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
grid$cell <- seq_len(nrow(grid))
stopifnot(nrow(grid) == 448)

cat("\n== Main grid ==\n")
cat("construction : ", CONSTRUCTION, "\n", sep = "")
cat("cells        : ", nrow(grid), "\n", sep = "")
cat("B            : ", B, "\n", sep = "")
cat("total tests  : ", format(nrow(grid) * B * 3, big.mark = ","), "\n", sep = "")

## ------------------------------------------------------------------
## one cell
## ------------------------------------------------------------------
run_cell <- function(i) {
  g <- grid[i, ]
  sp <- SPECS[[spec_key(g$family, g$skew, g$sd_ratio)]]
  use_stream(STREAMS[[i]])
  n <- g$n
  P <- vapply(seq_len(B), function(b) {
    x <- rspec(sp$X, n)          # narrower group (assignment labelling)
    y <- rspec(sp$Y, n)          # wider group
    three_p(x, y)                # common random numbers
  }, numeric(3))
  data.frame(
    cell = i, family = g$family, skew = g$skew, sd_ratio = g$sd_ratio, n = n,
    welch   = mean(P["welch", ]   < ALPHA),
    student = mean(P["student", ] < ALPHA),
    wmw     = mean(P["wmw", ]     < ALPHA),
    ## paper's Table 5, a PAIRED comparison thanks to common random numbers
    p_wmw_lt_welch = mean(P["wmw", ] < P["welch", ]),
    median_p_welch = median(P["welch", ]),
    median_p_wmw   = median(P["wmw", ]),
    row.names = NULL
  )
}

STREAMS <- make_streams(nrow(grid), SEED + 400L)

## ------------------------------------------------------------------
## run (parallel)
## ------------------------------------------------------------------
NC <- max(1L, min(parallel::detectCores(), 8L))
cat("workers      : ", NC, "\n\n", sep = "")

t0 <- Sys.time()
if (NC > 1L) {
  cl <- parallel::makeCluster(NC)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
  parallel::clusterExport(cl, c("grid", "SPECS", "STREAMS", "B", "ALPHA",
                                "spec_key", "run_cell", "three_p", "rspec",
                                "use_stream"),
                          envir = environment())
  ## bigger cells first so the tail of the run is not one slow worker
  ord <- order(-grid$n)
  out <- parallel::parLapplyLB(cl, ord, run_cell)
  parallel::stopCluster(cl); on.exit()
  res <- do.call(rbind, out)
  res <- res[order(res$cell), ]
} else {
  res <- do.call(rbind, lapply(seq_len(nrow(grid)), run_cell))
}
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
rownames(res) <- NULL

res$se_welch <- mc_se(res$welch, B)
res$se_wmw   <- mc_se(res$wmw,   B)

cat("elapsed: ", round(elapsed, 1), " s (", round(elapsed / 60, 2),
    " min)\n", sep = "")
if (identical(TAG, "pilot")) {
  cat("\n-- PILOT EXTRAPOLATION --\n")
  cat("B = ", B, " took ", round(elapsed, 1), " s\n", sep = "")
  cat("estimated B = 10000 : ", round(elapsed * 10000 / B / 60, 1),
      " min on ", NC, " workers\n", sep = "")
}

## ------------------------------------------------------------------
## paper-shaped tables
## ------------------------------------------------------------------
## Table 3: rejection rates at n = 1000, gamma, WMW and t side by side
tab3 <- function(fam, test) {
  d <- res[res$family == fam & res$n == 1000, ]
  m <- matrix(NA_real_, 8, 4,
              dimnames = list(sprintf("%.2f", RATIOS), paste0("skew", SKEWS)))
  for (i in seq_len(nrow(d)))
    m[sprintf("%.2f", d$sd_ratio[i]), paste0("skew", d$skew[i])] <- 100 * d[[test]][i]
  round(m, 1)
}
## Table 4: mean rejection rate by n, averaged over the 32 skew x ratio cells
tab4 <- function(fam, test) {
  d <- res[res$family == fam, ]
  v <- tapply(d[[test]], d$n, mean) * 100
  round(v[as.character(NS)], 2)
}
## Table 5: mean P(p_WMW < p_Welch) by n
tab5 <- function(fam) {
  d <- res[res$family == fam, ]
  round(tapply(d$p_wmw_lt_welch, d$n, mean)[as.character(NS)] * 100, 1)
}

if (!identical(TAG, "pilot")) {
  cat("\n== Table 3 shape: n = 1000 ==\n")
  for (fam in FAMS) {
    cat("\n-- ", fam, ", WMW (%) --\n", sep = ""); print(tab3(fam, "wmw"))
    cat("-- ", fam, ", Welch (%) --\n", sep = "");  print(tab3(fam, "welch"))
  }
  cat("\n== Table 4 shape: mean rejection rate (%) by n ==\n")
  for (fam in FAMS) {
    cat("\n-- ", fam, " --\n", sep = "")
    print(rbind(welch = tab4(fam, "welch"), student = tab4(fam, "student"),
                wmw = tab4(fam, "wmw")))
  }
  cat("\n== Table 5 shape: P(p_WMW < p_Welch) (%) by n ==\n")
  for (fam in FAMS) { cat("-- ", fam, " --\n", sep = ""); print(tab5(fam)) }
  cat("\nMonte Carlo SE at p=0.05, B=", B, " : ",
      round(100 * mc_se(0.05, B), 3), " pp\n", sep = "")
}

outfile <- if (identical(TAG, "full")) {
  "04_main_grid.rds"
} else {
  sprintf("04_main_grid_%s.rds", TAG)
}
saveRDS(list(results = res, grid = grid, B = B, alpha = ALPHA,
             construction = CONSTRUCTION, tag = TAG,
             elapsed = elapsed, workers = NC,
             ns = NS, ratios = RATIOS, skews = SKEWS, families = FAMS,
             seed = SEED + 400L, rng = "L'Ecuyer-CMRG, one stream per cell"),
        file.path(RES_DIR, outfile))
cat("saved -> results/", outfile, "\n", sep = "")
