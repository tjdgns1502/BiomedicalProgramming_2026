## 10_verify_jt_fast.R ---------------------------------------------------
## Proof that jt_p() (R/00_sim_utils.R) returns p-values identical to
## PMCMRplus::jonckheereTest(x, g)$p.value, before jt_p() replaces it in the
## simulation loop of R/12_pvalue_uniformity_v2.R.
##
## Criterion, fixed before running: identical() on every data set (bitwise
## equality, not all.equal). One mismatch anywhere means keep PMCMRplus.
##
## 6 designs x 250 data sets = 1500 comparisons:
##   the four designs the simulation uses (4 equal groups of 10 / 50 / 200,
##   and the contrast design n = 10/20/30/40 with SD 3/2/1.5/1), plus
##   random k in 2..6 with random unequal n under the null, and the same with
##   a linear trend in the means so that very small p-values are covered.
##
## Runs standalone:  Rscript R/10_verify_jt_fast.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(PMCMRplus))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "00_sim_utils.R"))

TAB_DIR <- file.path(PROJ, "output", "tables")
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

N_PER_DESIGN <- 250L
set.seed(20261001L)

gen <- list(
  equal_10   = function() list(n = rep(10, 4),  mu = rep(0, 4), sd = rep(1, 4)),
  equal_50   = function() list(n = rep(50, 4),  mu = rep(0, 4), sd = rep(1, 4)),
  equal_200  = function() list(n = rep(200, 4), mu = rep(0, 4), sd = rep(1, 4)),
  contrast   = function() list(n = c(10, 20, 30, 40), mu = rep(0, 4), sd = c(3, 2, 1.5, 1)),
  random_null = function() {
    k <- sample(2:6, 1)
    list(n = sample(3:60, k, replace = TRUE), mu = rep(0, k), sd = runif(k, 0.5, 3))
  },
  random_trend = function() {
    k <- sample(2:6, 1)
    list(n = sample(3:60, k, replace = TRUE), mu = seq(0, 1.5, length.out = k), sd = rep(1, k))
  })

check_design <- function(name, make) {
  res <- replicate(N_PER_DESIGN, {
    d <- make()
    g <- factor(rep(seq_along(d$n), d$n))
    x <- rnorm(sum(d$n), mean = rep(d$mu, d$n), sd = rep(d$sd, d$n))
    c(pmcmr = jonckheereTest(x, g)$p.value, fast = jt_p(x, g))
  })
  t_pm <- system.time(for (i in 1:20) { d <- make(); g <- factor(rep(seq_along(d$n), d$n))
                                        jonckheereTest(rnorm(sum(d$n)), g) })[["elapsed"]] / 20
  ## 500 calls: one fast call is below the timer's resolution
  t_fa <- system.time(for (i in 1:500) { d <- make(); g <- factor(rep(seq_along(d$n), d$n))
                                         jt_p(rnorm(sum(d$n)), g) })[["elapsed"]] / 500
  data.frame(design = name, datasets = N_PER_DESIGN,
             identical = sum(mapply(identical, res["pmcmr", ], res["fast", ])),
             max_abs_diff = max(abs(res["pmcmr", ] - res["fast", ])),
             min_p = min(res["pmcmr", ]),
             sec_per_call_pmcmr = t_pm, sec_per_call_fast = t_fa)
}

out <- do.call(rbind, Map(check_design, names(gen), gen))
all_identical <- sum(out$identical) == sum(out$datasets)

out_csv <- file.path(TAB_DIR, "10_jt_fast_equivalence.csv")
write.csv(out, out_csv, row.names = FALSE)

print(out, row.names = FALSE, digits = 3)
cat(sprintf("\n%d / %d data sets identical() -> %s\n", sum(out$identical), sum(out$datasets),
            if (all_identical) "jt_p() may replace PMCMRplus in the simulation"
            else "MISMATCH: keep PMCMRplus::jonckheereTest"))
cat("Written:", out_csv, "\n")
