## 99_verify_cache.R -----------------------------------------------------
## Reproducibility audit.
##
## The per-cell L'Ecuyer stream design means any single cell of the 448-cell
## grid can be re-run on its own and must return bit-identical numbers. This
## script re-runs a sample of cells with the CURRENT code and compares them
## to what is cached in results/04_main_grid.rds, which is the real test of
## whether the cache is still valid after later edits to R/00_utils.R.
##
## Standalone:  Rscript R/99_verify_cache.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

d04 <- readRDS(file.path(RES_DIR, "04_main_grid.rds"))
B <- d04$B; ALPHA <- d04$alpha
grid <- d04$grid
STREAMS <- make_streams(nrow(grid), d04$seed)

make_pair <- function(fam, sk, rr) {
  X <- if (fam == "lognormal") base_lnorm(sk) else base_gamma(sk)
  Y <- if (fam == "lognormal")
    fit_shifted_lnorm(X$mean, X$median, rr * X$sd)
  else
    fit_shifted_gamma(X$mean, X$median, rr * X$sd, k_base = X$shape,
                      branch = "continuity")
  list(X = X, Y = Y)
}

## a spread of cells: small/large n, both families, the reversing skew-4
## gamma column, and the headline cell
pick <- c(
  which(grid$family == "gamma"     & grid$skew == 3 & grid$sd_ratio == 1.10 & grid$n == 1000),
  which(grid$family == "lognormal" & grid$skew == 3 & grid$sd_ratio == 1.10 & grid$n == 1000),
  which(grid$family == "gamma"     & grid$skew == 4 & grid$sd_ratio == 1.05 & grid$n == 250),
  which(grid$family == "lognormal" & grid$skew == 1 & grid$sd_ratio == 1.50 & grid$n == 10),
  which(grid$family == "gamma"     & grid$skew == 2 & grid$sd_ratio == 1.25 & grid$n == 50)
)

cat("\n== reproducibility audit: re-running ", length(pick),
    " cells of the 448-cell grid ==\n\n", sep = "")

out <- do.call(rbind, lapply(pick, function(i) {
  g <- grid[i, ]
  sp <- make_pair(g$family, g$skew, g$sd_ratio)
  use_stream(STREAMS[[i]])
  P <- vapply(seq_len(B), function(b) three_p(rspec(sp$X, g$n), rspec(sp$Y, g$n)),
              numeric(3))
  cached <- d04$results[d04$results$cell == i, ]
  data.frame(
    cell = i, family = g$family, skew = g$skew, sd_ratio = g$sd_ratio, n = g$n,
    welch_now = mean(P["welch", ] < ALPHA), welch_cached = cached$welch,
    wmw_now   = mean(P["wmw", ]   < ALPHA), wmw_cached   = cached$wmw,
    t5_now    = mean(P["wmw", ] < P["welch", ]), t5_cached = cached$p_wmw_lt_welch,
    row.names = NULL)
}))
out$max_diff <- pmax(abs(out$welch_now - out$welch_cached),
                     abs(out$wmw_now   - out$wmw_cached),
                     abs(out$t5_now    - out$t5_cached))
print(out, row.names = FALSE, digits = 5)

ok <- max(out$max_diff) == 0
cat("\nlargest discrepancy vs cache : ", max(out$max_diff), "\n", sep = "")
cat("CACHE IS BIT-IDENTICAL UNDER CURRENT CODE : ", ok, "\n", sep = "")
if (!ok) stop("99_verify_cache.R: cached grid does not reproduce.")

## also re-check the fast functions against base R once more, on the exact
## distributions used by the grid rather than on normal data
set.seed(4242)
sp <- make_pair("gamma", 4, 1.30)
x <- rspec(sp$X, 137); y <- rspec(sp$Y, 91)
chk <- c(
  welch   = abs(welch_p(x, y)   - t.test(x, y)$p.value),
  student = abs(student_p(x, y) - t.test(x, y, var.equal = TRUE)$p.value),
  wmw     = abs(wmw_p(x, y) - suppressWarnings(
    wilcox.test(x, y, exact = FALSE, correct = FALSE)$p.value)),
  three_w = abs(three_p(x, y)[["welch"]] - t.test(x, y)$p.value),
  three_m = abs(three_p(x, y)[["wmw"]] - suppressWarnings(
    wilcox.test(x, y, exact = FALSE, correct = FALSE)$p.value))
)
cat("\nfast functions vs base R on the grid's own distributions:\n")
print(signif(chk, 3))
stopifnot(max(chk) < 1e-12)
cat("\nAUDIT PASSED\n")
