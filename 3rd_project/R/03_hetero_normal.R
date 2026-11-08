## 03_hetero_normal.R -----------------------------------------------------
## Baseline with normality PERFECT and only homoscedasticity broken, so the
## Student-vs-Welch difference shows up on its own, uncontaminated by
## skewness.
##
## Equal means (null true for both t-tests). Grid: group-size split x
## SD ratio. B = 10,000 replicates, common random numbers across the three
## tests within each replicate.
##
## Standalone:  Rscript R/03_hetero_normal.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

B <- 10000L
ALPHA <- 0.05

## total N held at 50 so that only the SPLIT varies along that axis
SPLITS <- list(c(10, 40), c(20, 30), c(25, 25), c(30, 20), c(40, 10))
SD_RATIOS <- c(0.25, 0.5, 1, 2, 4)      # sd1 / sd2

grid <- expand.grid(split = seq_along(SPLITS), sd_ratio = SD_RATIOS)
grid$n1 <- sapply(SPLITS[grid$split], `[`, 1)
grid$n2 <- sapply(SPLITS[grid$split], `[`, 2)
grid$sd1 <- grid$sd_ratio
grid$sd2 <- 1

cat("\n== Heteroscedastic normal baseline ==\n")
cat("cells: ", nrow(grid), " | B = ", B, " | alpha = ", ALPHA, "\n", sep = "")
cat("means equal in every cell, so every rejection is a Type I error\n")
cat("for both t-tests.\n\n")

streams <- make_streams(nrow(grid), SEED + 300L)

t0 <- Sys.time()
res <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  use_stream(streams[[i]])
  n1 <- g$n1; n2 <- g$n2; s1 <- g$sd1; s2 <- g$sd2
  P <- vapply(seq_len(B), function(b) {
    ## ONE sample pair feeds all three tests (common random numbers)
    three_p(rnorm(n1, 0, s1), rnorm(n2, 0, s2))
  }, numeric(3))
  rj <- rowMeans(P < ALPHA)
  data.frame(n1 = n1, n2 = n2, sd1 = s1, sd2 = s2, sd_ratio = g$sd_ratio,
             split = sprintf("%d:%d", n1, n2),
             student = rj[["student"]], welch = rj[["welch"]], wmw = rj[["wmw"]],
             se = mc_se(0.05, B), row.names = NULL)
}))
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

fmt <- function(col) {
  m <- matrix(NA_real_, length(SPLITS), length(SD_RATIOS),
              dimnames = list(sapply(SPLITS, function(s) sprintf("%d:%d", s[1], s[2])),
                              sprintf("sd1/sd2=%g", SD_RATIOS)))
  for (i in seq_len(nrow(res)))
    m[res$split[i], sprintf("sd1/sd2=%g", res$sd_ratio[i])] <- 100 * res[[col]][i]
  round(m, 1)
}
cat("-- Student (pooled) rejection rate, % --\n"); print(fmt("student"))
cat("\n-- Welch rejection rate, % --\n");          print(fmt("welch"))
cat("\n-- WMW rejection rate, % --\n");            print(fmt("wmw"))
cat("\nMonte Carlo SE at p=0.05, B=", B, " : ", round(100 * mc_se(0.05, B), 3),
    " percentage points\n", sep = "")

## ---- the four claims, checked numerically -------------------------
small_big <- res[res$n1 < res$n2 & res$sd_ratio > 1, ]   # small group, big variance
big_big   <- res[res$n1 > res$n2 & res$sd_ratio > 1, ]   # large group, big variance
equal_n   <- res[res$n1 == res$n2, ]
claims <- data.frame(
  claim = c("small group has the larger SD -> Student INFLATES",
            "large group has the larger SD -> Student CONSERVATIVE",
            "Welch stays near 5% everywhere",
            "equal n -> Student roughly OK"),
  value = c(sprintf("Student %.1f%% - %.1f%% (vs 5.0%%)",
                    100 * min(small_big$student), 100 * max(small_big$student)),
            sprintf("Student %.1f%% - %.1f%% (vs 5.0%%)",
                    100 * min(big_big$student), 100 * max(big_big$student)),
            sprintf("Welch %.1f%% - %.1f%% over all %d cells",
                    100 * min(res$welch), 100 * max(res$welch), nrow(res)),
            sprintf("Student %.1f%% - %.1f%% when n1 = n2",
                    100 * min(equal_n$student), 100 * max(equal_n$student))),
  holds = c(min(small_big$student) > 0.05 + 2 * mc_se(0.05, B),
            max(big_big$student)   < 0.05 - 2 * mc_se(0.05, B),
            max(abs(res$welch - 0.05)) < 0.01,
            max(abs(equal_n$student - 0.05)) < 0.01)
)
cat("\n== Claims ==\n")
for (i in seq_len(nrow(claims)))
  cat(sprintf("  [%s] %s\n        %s\n",
              ifelse(claims$holds[i], "OK", "NO"), claims$claim[i], claims$value[i]))

cat("\nelapsed: ", round(elapsed, 1), " s\n", sep = "")

saveRDS(list(results = res, grid = grid, B = B, alpha = ALPHA,
             claims = claims, elapsed = elapsed,
             splits = SPLITS, sd_ratios = SD_RATIOS),
        file.path(RES_DIR, "03_hetero_normal.rds"))
cat("saved -> results/03_hetero_normal.rds\n")
