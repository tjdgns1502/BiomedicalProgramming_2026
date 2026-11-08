## 00_sim_utils.R --------------------------------------------------------
## Shared pieces for the v2 simulation scripts (11, 12) and their
## verification scripts (10, 13):
##
##   cli_arg()       --name=value command-line arguments
##   sim_seeds()     one seed per condition, in either RNG mode
##   run_grid()      Map over the condition grid with future.apply
##   jt_p()          vectorized Jonckheere-Terpstra p-value, a drop-in for
##                   PMCMRplus::jonckheereTest(x, g)$p.value (continuous
##                   data, two-sided, no continuity correction)
##
## RNG modes
##   streams  RNGkind("L'Ecuyer-CMRG"); condition i gets the i-th stream
##            from parallel::nextRNGStream(), handed to future.apply via
##            future.seed. Streams are non-overlapping by construction and
##            results do not depend on the number of workers.
##   legacy   Mersenne-Twister, set.seed(SEED0 + i) inside condition i:
##            the v1 scripts' seeding. Only used to prove that the parallel
##            v2 code reproduces the committed v1 CSVs exactly.
## ------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(future)
  library(future.apply)
})

cli_arg <- function(name, default) {
  a <- commandArgs(trailingOnly = TRUE)
  hit <- a[startsWith(a, paste0("--", name, "="))]
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[length(hit)]) else default
}

## Returns list(legacy = integer seeds or NA, streams = list of .Random.seed
## vectors or NULL, label = seed per condition for the CSV). The legacy label
## stays an integer, as in v1: a character label would be quoted by
## write.csv and the CSV would no longer match v1 line for line.
sim_seeds <- function(n_cond, seed0, rng) {
  switch(rng,
    legacy = list(legacy  = seed0 + seq_len(n_cond),
                  streams = NULL,
                  label   = seed0 + seq_len(n_cond)),
    streams = {
      old_kind <- RNGkind()[1]
      RNGkind("L'Ecuyer-CMRG")
      set.seed(seed0)
      s <- .Random.seed
      streams <- vector("list", n_cond)
      for (i in seq_len(n_cond)) {
        s <- parallel::nextRNGStream(s)
        streams[[i]] <- s
      }
      RNGkind(old_kind)
      list(legacy  = rep(NA_integer_, n_cond),
           streams = streams,
           label   = vapply(streams, paste, character(1), collapse = ","))
    },
    stop("--rng must be 'streams' or 'legacy', got: ", rng))
}

## Map FUN over the grid columns in parallel, one future per condition so
## cheap and expensive conditions balance across workers. In legacy mode
## FUN calls set.seed() itself, which future's RNG-misuse check would flag,
## so that check is switched off for legacy runs only.
run_grid <- function(FUN, ..., seeds, workers) {
  if (workers > 1) plan(multisession, workers = workers) else plan(sequential)
  on.exit(plan(sequential), add = TRUE)
  if (is.null(seeds$streams)) {
    op <- options(future.rng.onMisuse = "ignore")
    on.exit(options(op), add = TRUE)
    future_Map(FUN, ..., legacy_seed = seeds$legacy,
               future.seed = FALSE, future.scheduling = Inf)
  } else {
    future_Map(FUN, ..., legacy_seed = seeds$legacy,
               future.seed = seeds$streams, future.scheduling = Inf)
  }
}

## Jonckheere-Terpstra, two-sided, normal approximation, no ties.
## PMCMRplus builds J = sum_{i<j} sum_{s in i, t in j} (sign(x_t - x_s) + 1) / 2
## with an R double loop. Without ties that is the number of pairs where the
## later group's value is larger, which equals, summed over groups j >= 2,
## the rank sum of group j within groups 1..j minus n_j (n_j + 1) / 2.
## J is an integer either way, so it is exact. mu, the variance and the
## p-value use PMCMRplus's expressions in the same order, so p-values are
## identical, not just close. Ties stop with an error rather than silently
## using the wrong variance.
jt_p <- function(x, g) {
  g <- factor(g)
  if (anyDuplicated(x)) stop("jt_p: ties present; use PMCMRplus::jonckheereTest")
  k   <- nlevels(g)
  n   <- length(x)
  nij <- tapply(x, g, length)
  J <- 0
  for (j in 2:k) {
    keep <- as.integer(g) <= j
    r    <- rank(x[keep])
    J    <- J + sum(r[as.integer(g[keep]) == j]) - nij[[j]] * (nij[[j]] + 1) / 2
  }
  mu <- (n^2 - sum(nij^2)) / 4
  st <- 0
  for (i in 1:k) st <- st + nij[i]^2 * (2 * nij[i] + 3)
  s  <- sqrt((n^2 * (2 * n + 3) - st) / 72)
  z  <- (J - mu) / s
  unname(2 * min(pnorm(abs(z), lower.tail = FALSE), 0.5))
}
