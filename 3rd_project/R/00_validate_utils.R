## 00_validate_utils.R ----------------------------------------------------
## Task 1 proof: every fast function must agree with the base R function it
## replaces, on 500 random designs with unequal n and unequal SD.
## Also verifies Cliff's delta = 2U/(n1 n2) - 1 numerically.
##
## Standalone:  Rscript R/00_validate_utils.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

NDES <- 500L
set.seed(11)

rows <- vector("list", NDES)
for (i in seq_len(NDES)) {
  n1 <- sample(5:120, 1); n2 <- sample(5:120, 1)
  s1 <- runif(1, 0.2, 6);  s2 <- runif(1, 0.2, 6)
  ## a mix of clean-continuous and heavily tied designs, so the tie
  ## correction in wmw_p is actually exercised
  tied <- (i %% 3L == 0L)
  x <- rnorm(n1, 0, s1); y <- rnorm(n2, 0.3, s2)
  if (tied) { x <- round(x, 1); y <- round(y, 1) }

  tw <- t.test(x, y, var.equal = FALSE)
  ts <- t.test(x, y, var.equal = TRUE)
  suppressWarnings(
    tm <- wilcox.test(x, y, exact = FALSE, correct = FALSE)
  )

  ## Cliff's delta two ways: from ranks, and by brute-force pair counting
  U_rank  <- mw_u(x, y)
  U_brute <- sum(outer(x, y, ">")) + 0.5 * sum(outer(x, y, "=="))
  d_rank  <- cliff_delta(x, y)
  d_brute <- mean(outer(x, y, ">")) - mean(outer(x, y, "<"))
  cles_br <- mean(outer(x, y, "<")) + 0.5 * mean(outer(x, y, "=="))

  rows[[i]] <- c(
    welch_p   = abs(welch_p(x, y)   - tw$p.value),
    welch_df  = abs(welch_df(x, y)  - unname(tw$parameter)),
    student_p = abs(student_p(x, y) - ts$p.value),
    wmw_p     = abs(wmw_p(x, y)     - tm$p.value),
    wmw_U     = abs(U_rank          - unname(tm$statistic)),
    three_w   = abs(three_p(x, y)[["welch"]]   - tw$p.value),
    three_s   = abs(three_p(x, y)[["student"]] - ts$p.value),
    three_m   = abs(three_p(x, y)[["wmw"]]     - tm$p.value),
    cliff_U   = abs(U_rank - U_brute),
    cliff_def = abs(d_rank - d_brute),
    cles_def  = abs(cles(x, y) - cles_br),
    cles_link = abs(cles(x, y) - (1 - d_rank) / 2),
    tied      = as.numeric(tied)
  )
}
chk <- do.call(rbind, rows)

maxdiff <- apply(chk[, setdiff(colnames(chk), "tied"), drop = FALSE], 2, max)

## Hedges' g is a deterministic rescaling of Cohen's d; verify the factor.
set.seed(12)
x <- rnorm(31, 0, 2); y <- rnorm(44, 1, 5)
N <- length(x) + length(y)
g_chk <- abs(hedges_g(x, y) - cohen_d(x, y) * (1 - 3 / (4 * N - 9)))

## Glass's Delta against its definition
glass_chk <- abs(glass_delta(x, y) - (mean(x) - mean(y)) / sd(y))

cat("\n== Task 1: fast implementations vs base R, ", NDES,
    " random designs ==\n", sep = "")
cat("   (", sum(chk[, "tied"] == 1), " of them heavily tied)\n\n", sep = "")
print(signif(maxdiff, 3))
cat("\nHedges' g factor check : ", signif(g_chk, 3), "\n", sep = "")
cat("Glass's Delta check    : ", signif(glass_chk, 3), "\n", sep = "")

tol <- 1e-10
ok <- all(maxdiff <= tol) && g_chk <= tol && glass_chk <= tol
cat("\nAll max abs differences <= 1e-10 : ", ok, "\n", sep = "")
if (!ok) {
  cat("FAILED components:\n")
  print(maxdiff[maxdiff > tol])
  stop("00_validate_utils.R: fast implementations do not match base R.")
}

saveRDS(list(n_designs = NDES, max_abs_diff = maxdiff,
             hedges_check = g_chk, glass_check = glass_chk,
             tolerance = tol, all_ok = ok,
             n_tied_designs = sum(chk[, "tied"] == 1)),
        file.path(RES_DIR, "00_utils_validation.rds"))

cat("\nsaved -> results/00_utils_validation.rds\n")
