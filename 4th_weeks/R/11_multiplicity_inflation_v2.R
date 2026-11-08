## 11_multiplicity_inflation_v2.R ----------------------------------------
## v2 of R/01_multiplicity_inflation.R: same simulation, targets, pass rule
## and figure; the condition grid now runs in parallel (future.apply) with
## one independent L'Ecuyer-CMRG stream per condition. See CHANGES_v2.md.
##
##   uncorrected  1 - (1 - alpha)^k
##   Bonferroni   1 - (1 - alpha/k)^k
##   BH           alpha
## Pass rule: the analytical value lies inside estimate +/- 2.576 * SE.
##
## Arguments (all optional):
##   --B=10000          replicates per condition (default 10000)
##   --rng=streams      'streams' (L'Ecuyer-CMRG) or 'legacy' (v1 seeding)
##   --workers=7        parallel workers; 1 = sequential
##   --outdir=<path>    where tables/ and figures/ go (default output/)
##
## Rscript R/11_multiplicity_inflation_v2.R --B=10000
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "00_sim_utils.R"))

B       <- as.integer(cli_arg("B", 10000))
RNG     <- cli_arg("rng", "streams")
WORKERS <- as.integer(cli_arg("workers", availableCores(omit = 1)))
OUT     <- cli_arg("outdir", file.path(PROJ, "output"))
ALPHA   <- 0.05
SEED0   <- 20260928L
Z99     <- qnorm(0.995)

TAB_DIR <- file.path(OUT, "tables")
FIG_DIR <- file.path(OUT, "figures")
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
TAG <- sprintf("11_multiplicity_inflation_v2_B%d", B)

## ========================================================================
## 1. One null p-value per call (unchanged from v1)
## ========================================================================

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

## In streams mode future.apply has already set this condition's stream;
## in legacy mode the v1 seed is set here.
run_condition <- function(condition, k, test, n, legacy_seed) {
  if (!is.na(legacy_seed))
    set.seed(legacy_seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
             sample.kind = "Rejection")
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
             lower = unname(est - Z99 * se), upper = unname(est + Z99 * se))
}

## ========================================================================
## 3. Condition grid, run in parallel
## ========================================================================

grid <- expand.grid(k    = c(1, 2, 3, 5, 6, 10, 15, 20),
                    test = c("student_t", "welch_t", "anova_4group"),
                    n    = c(20, 100),
                    stringsAsFactors = FALSE)
grid$condition <- seq_len(nrow(grid))
seeds <- sim_seeds(nrow(grid), SEED0, RNG)

t0  <- Sys.time()
res <- do.call(rbind, run_grid(run_condition, grid$condition, grid$k, grid$test, grid$n,
                               seeds = seeds, workers = WORKERS))
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
res$seed <- seeds$label[res$condition]
res$pass <- res$target >= res$lower & res$target <= res$upper

out_csv <- file.path(TAB_DIR, paste0(TAG, ".csv"))
write.csv(res, out_csv, row.names = FALSE)

## ========================================================================
## 4. Console summary
## ========================================================================

cat(sprintf("B = %d, rng = %s, workers = %d, %d conditions x 3 methods = %d checks, %d s\n",
            B, RNG, WORKERS, nrow(grid), nrow(res), elapsed))
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
## 5. Multiplicity inflation curve (unchanged from v1)
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

out_png <- file.path(FIG_DIR, paste0(TAG, ".png"))
ggsave(out_png, p, width = 12, height = 7, dpi = 150)
cat("Written:", out_png, "\n")
