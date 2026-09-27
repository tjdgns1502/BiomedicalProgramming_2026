## 01_multiplicity_inflation.R -------------------------------------------
## Family-wise error rate (FWER) of k independent tests under the global
## null, uncorrected and after Bonferroni / Benjamini-Hochberg, checked
## against the analytical values:
##
##   uncorrected  1 - (1 - alpha)^k
##   Bonferroni   1 - (1 - alpha/k)^k      (always <= alpha)
##   BH           alpha                    (under the global null BH rejects
##                                          anything iff the Simes test does,
##                                          and Simes has exact size alpha for
##                                          independent continuous p-values)
##
## Pass rule, fixed before running: the analytical value lies inside the
## 99% Monte Carlo interval  estimate +/- 2.576 * sqrt(p(1-p)/B).
## With 48 conditions x 3 methods = 144 checks, about 1.4 false fails are
## expected even if everything is correct.
##
## Runs standalone from a clean R session:  Rscript R/01_multiplicity_inflation.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

B     <- 1000L        # quick run; use 10000L for the final run
ALPHA <- 0.05
SEED0 <- 20260928L    # condition i uses seed SEED0 + i
Z99   <- qnorm(0.995)

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)

## ========================================================================
## 1. One null p-value per call
## ========================================================================

## All groups are N(0, 1) with n per group, so every test's null is true.
## anova_4group is the classic F test (oneway.test with var.equal = TRUE
## gives the same F and df as anova(lm())).
null_p <- function(test, n) {
  switch(test,
    student_t    = t.test(rnorm(n), rnorm(n), var.equal = TRUE)$p.value,
    welch_t      = t.test(rnorm(n), rnorm(n), var.equal = FALSE)$p.value,
    anova_4group = oneway.test(y ~ g, var.equal = TRUE,
                               data = data.frame(y = rnorm(4 * n), g = gl(4, n)))$p.value,
    stop("unknown test: ", test))
}

## ========================================================================
## 2. One condition: B families of k independent tests
## ========================================================================

run_condition <- function(condition, k, test, n, seed) {
  set.seed(seed)
  P <- matrix(replicate(B * k, null_p(test, n)), nrow = B, ncol = k)

  any_reject <- function(adjust) {
    mean(apply(P, 1, function(p) any(p.adjust(p, adjust) <= ALPHA)))
  }
  est <- c(uncorrected = mean(apply(P, 1, function(p) any(p <= ALPHA))),
           bonferroni  = any_reject("bonferroni"),
           bh          = any_reject("BH"))
  target <- c(uncorrected = 1 - (1 - ALPHA)^k,
              bonferroni  = 1 - (1 - ALPHA / k)^k,
              bh          = ALPHA)

  se <- sqrt(est * (1 - est) / B)
  data.frame(condition = condition, k = k, test = test, n = n,
             method = names(est), target = unname(target),
             estimate = unname(est), se = unname(se),
             lower = unname(est - Z99 * se), upper = unname(est + Z99 * se),
             seed = seed)
}

## ========================================================================
## 3. Condition grid
## ========================================================================

grid <- expand.grid(k    = c(1, 2, 3, 5, 6, 10, 15, 20),
                    test = c("student_t", "welch_t", "anova_4group"),
                    n    = c(20, 100),
                    stringsAsFactors = FALSE)
grid$condition <- seq_len(nrow(grid))
grid$seed      <- SEED0 + grid$condition

t0  <- Sys.time()
res <- do.call(rbind, Map(run_condition,
                          grid$condition, grid$k, grid$test, grid$n, grid$seed))
res$pass <- res$target >= res$lower & res$target <= res$upper
elapsed  <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))

out_csv <- file.path(TAB_DIR, "01_multiplicity_inflation.csv")
write.csv(res, out_csv, row.names = FALSE)

## ========================================================================
## 4. Console summary
## ========================================================================

cat(sprintf("B = %d, %d conditions x 3 methods = %d checks, %d s\n",
            B, nrow(grid), nrow(res), elapsed))
cat(sprintf("pass: %d / %d  (expected false fails at 99%%: %.2f)\n",
            sum(res$pass), nrow(res), 0.01 * nrow(res)))
if (any(!res$pass)) {
  cat("\nFailed checks:\n")
  print(res[!res$pass, c("k", "test", "n", "method", "target",
                         "estimate", "lower", "upper")],
        row.names = FALSE, digits = 3)
}
cat("\nWritten:", out_csv, "\n")

## ========================================================================
## 5. Multiplicity inflation curve
## ========================================================================

k_line <- seq(1, 20, by = 0.25)
curves <- rbind(
  data.frame(k = k_line, target = 1 - (1 - ALPHA)^k_line,          method = "uncorrected"),
  data.frame(k = k_line, target = 1 - (1 - ALPHA / k_line)^k_line, method = "bonferroni"),
  data.frame(k = k_line, target = ALPHA,                           method = "bh"))

method_lab <- c(uncorrected = "Uncorrected: 1 - 0.95^k",
                bonferroni  = "Bonferroni: 1 - (1 - 0.05/k)^k",
                bh          = "BH: 0.05")
res$method    <- factor(res$method,    levels = names(method_lab))
curves$method <- factor(curves$method, levels = names(method_lab))

## One panel per test x n, so every point sits at its exact k (no dodging).
## Bonferroni and BH overlap by design: their targets differ by < 0.002.
p <- ggplot(res, aes(k, estimate, colour = method)) +
  geom_line(data = curves, aes(k, target, colour = method), linewidth = 0.7) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0, alpha = 0.7) +
  geom_point(size = 1.6) +
  facet_grid(n ~ test, labeller = labeller(n = function(x) paste("n per group =", x))) +
  scale_colour_manual(values = c(uncorrected = "#C0392B", bonferroni = "#2E86C1",
                                 bh = "#27AE60"), labels = method_lab) +
  scale_x_continuous(breaks = c(1, 2, 3, 5, 6, 10, 15, 20)) +
  labs(x = "Number of independent tests (k)", y = "Family-wise error rate",
       colour = "Method (line = analytical)",
       title = "Multiplicity inflation under the global null",
       subtitle = sprintf("Points: simulated FWER, bars: 99%% Monte Carlo interval, B = %d", B)) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

out_png <- file.path(FIG_DIR, "01_multiplicity_inflation.png")
ggsave(out_png, p, width = 12, height = 7, dpi = 150)
cat("Written:", out_png, "\n")
