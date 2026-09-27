## 06_group_comparisons.R ------------------------------------------------
## Frailty index (FI) across quartiles of NLR, MLR, SIRI and SII (our
## sample quartiles, from R/04), N = 14054, unweighted.
##
## Grid marker x omnibus test, each omnibus test with its matched post-hoc:
##   one-way ANOVA   aov              -> TukeyHSD
##   Welch ANOVA     oneway.test      -> PMCMRplus::gamesHowellTest
##   Kruskal-Wallis  kruskal.test     -> PMCMRplus::kwAllPairsDunnTest
##                                       (p.adjust.method = "holm", stated
##                                        explicitly; it is the default)
## Tukey and Games-Howell p-values are already family-wise adjusted over
## the 6 pairs within a marker (studentized range); Dunn's are Holm-adjusted.
## ptukey cannot resolve p-values below about 1e-9 (Tukey floors at 3.79e-09,
## Games-Howell returns noise near 1e-12), so for these two methods any
## p < 1e-8 is stored as the bound 1e-8 with p_is_upper_bound = TRUE.
##
## Pairwise t-tests (pairwise.t.test, pool.sd = FALSE, i.e. Welch t for each
## pair, because R/05 found unequal variances), raw p-values, then adjusted
## with Bonferroni and Benjamini-Hochberg two ways:
##   within marker   family of 6 comparisons
##   across markers  family of all 4 x 6 = 24 comparisons
##
## Output: output/tables/06_group_comparisons.csv, one tidy table with
##   marker, family (omnibus / posthoc / pairwise_t), method, contrast,
##   estimate (mean FI difference, later minus earlier quartile; NA where the
##   method has none), statistic, df, p_raw, p_method_adjusted (the post-hoc's
##   own adjustment), p_bonf_within, p_bh_within, p_bonf_all24, p_bh_all24.
##
## Rscript R/06_group_comparisons.R
## ------------------------------------------------------------------------

set.seed(20261006L)   # no random numbers are drawn; seeded by convention

suppressPackageStartupMessages(library(PMCMRplus))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")

d <- readRDS(file.path(PROJ, "data", "processed", "analytic_quartiles.rds"))
MARKERS <- c("NLR", "MLR", "SIRI", "SII")
TESTS   <- c("anova", "welch", "kruskal")

## All 6 pairs as "Qj-Qi" (j > i), the same order for every method
PAIRS <- with(expand.grid(i = 1:4, j = 1:4), paste0("Q", j, "-Q", i)[j > i])

empty_row <- function(m, family, method, contrast)
  data.frame(marker = m, family = family, method = method, contrast = contrast,
             estimate = NA_real_, statistic = NA_real_, df = NA_character_,
             p_raw = NA_real_, p_method_adjusted = NA_real_)

## PMCMR lower-triangle matrix (rows Q2..Q4, cols Q1..Q3) -> vector in PAIRS order
tri_to_pairs <- function(mat) {
  unlist(Map(function(pr) {
    q <- strsplit(pr, "-")[[1]]
    mat[q[1], q[2]]
  }, PAIRS))
}

mean_diffs <- function(y, g) {
  mu <- tapply(y, g, mean)
  unlist(Map(function(pr) { q <- strsplit(pr, "-")[[1]]; mu[[q[1]]] - mu[[q[2]]] }, PAIRS))
}

## ========================================================================
## 1. Omnibus test + matched post-hoc, grid marker x test
## ========================================================================

run_test <- function(m, test) {
  y <- d$fi_score
  g <- d[[paste0("q_", m, "_ours")]]
  md <- mean_diffs(y, g)
  switch(test,
    anova = {
      fit <- aov(y ~ g)
      s   <- summary(fit)[[1]]
      tk  <- TukeyHSD(fit)$g
      post <- data.frame(marker = m, family = "posthoc", method = "TukeyHSD",
                         contrast = PAIRS, estimate = tk[PAIRS, "diff"],
                         statistic = NA_real_, df = NA_character_,
                         p_raw = NA_real_, p_method_adjusted = tk[PAIRS, "p adj"])
      omni <- data.frame(marker = m, family = "omnibus", method = "one-way ANOVA",
                         contrast = "Q1=Q2=Q3=Q4", estimate = NA_real_,
                         statistic = s[["F value"]][1],
                         df = sprintf("%d, %d", s[["Df"]][1], s[["Df"]][2]),
                         p_raw = s[["Pr(>F)"]][1], p_method_adjusted = NA_real_)
      rbind(omni, post)
    },
    welch = {
      w  <- oneway.test(y ~ g, var.equal = FALSE)
      gh <- gamesHowellTest(y, g)
      omni <- data.frame(marker = m, family = "omnibus", method = "Welch ANOVA",
                         contrast = "Q1=Q2=Q3=Q4", estimate = NA_real_,
                         statistic = unname(w$statistic),
                         df = sprintf("%g, %.1f", w$parameter[1], w$parameter[2]),
                         p_raw = w$p.value, p_method_adjusted = NA_real_)
      post <- data.frame(marker = m, family = "posthoc", method = "Games-Howell",
                         contrast = PAIRS, estimate = md,
                         statistic = tri_to_pairs(gh$statistic), df = NA_character_,
                         p_raw = NA_real_, p_method_adjusted = tri_to_pairs(gh$p.value))
      rbind(omni, post)
    },
    kruskal = {
      k  <- kruskal.test(y, g)
      dn <- kwAllPairsDunnTest(y, g, p.adjust.method = "holm")
      omni <- data.frame(marker = m, family = "omnibus", method = "Kruskal-Wallis",
                         contrast = "Q1=Q2=Q3=Q4", estimate = NA_real_,
                         statistic = unname(k$statistic), df = as.character(k$parameter),
                         p_raw = k$p.value, p_method_adjusted = NA_real_)
      post <- data.frame(marker = m, family = "posthoc", method = "Dunn (Holm)",
                         contrast = PAIRS, estimate = NA_real_,
                         statistic = tri_to_pairs(dn$statistic), df = NA_character_,
                         p_raw = NA_real_, p_method_adjusted = tri_to_pairs(dn$p.value))
      rbind(omni, post)
    })
}

grid <- expand.grid(marker = MARKERS, test = TESTS, stringsAsFactors = FALSE)
omni_post <- do.call(rbind, Map(run_test, grid$marker, grid$test))

## ========================================================================
## 2. Pairwise Welch t-tests, raw p, adjusted within marker and across 24
## ========================================================================

pw <- do.call(rbind, Map(function(m) {
  y <- d$fi_score; g <- d[[paste0("q_", m, "_ours")]]
  pt <- pairwise.t.test(y, g, p.adjust.method = "none", pool.sd = FALSE)
  data.frame(marker = m, family = "pairwise_t", method = "Welch t (pairwise.t.test, pool.sd = FALSE)",
             contrast = PAIRS, estimate = mean_diffs(y, g), statistic = NA_real_,
             df = NA_character_, p_raw = tri_to_pairs(pt$p.value), p_method_adjusted = NA_real_)
}, MARKERS))

pw$p_bonf_within <- ave(pw$p_raw, pw$marker, FUN = function(p) p.adjust(p, "bonferroni"))
pw$p_bh_within   <- ave(pw$p_raw, pw$marker, FUN = function(p) p.adjust(p, "BH"))
pw$p_bonf_all24  <- p.adjust(pw$p_raw, "bonferroni")
pw$p_bh_all24    <- p.adjust(pw$p_raw, "BH")
stopifnot(nrow(pw) == 24)

P_FLOOR <- 1e-8
omni_post$p_is_upper_bound <- omni_post$method %in% c("TukeyHSD", "Games-Howell") &
                              omni_post$p_method_adjusted < P_FLOOR
omni_post$p_method_adjusted[omni_post$p_is_upper_bound] <- P_FLOOR
pw$p_is_upper_bound <- FALSE

omni_post[c("p_bonf_within", "p_bh_within", "p_bonf_all24", "p_bh_all24")] <- NA_real_
res <- rbind(omni_post, pw)
res$marker <- factor(res$marker, levels = MARKERS)
res <- res[order(res$marker, match(res$family, c("omnibus", "posthoc", "pairwise_t")), res$method), ]
rownames(res) <- NULL

write.csv(res, file.path(TAB_DIR, "06_group_comparisons.csv"), row.names = FALSE)

## ========================================================================
## 3. Console
## ========================================================================

fmt <- function(x) ifelse(is.na(x), "", formatC(x, format = "g", digits = 3))
cat("Omnibus tests:\n")
o <- res[res$family == "omnibus", ]
print(data.frame(marker = o$marker, method = o$method, statistic = round(o$statistic, 2),
                 df = o$df, p = fmt(o$p_raw)), row.names = FALSE)

cat("\nPost-hoc p (method's own adjustment), by contrast:\n")
ph <- res[res$family == "posthoc", ]
ph$p_show <- ifelse(ph$p_is_upper_bound, "<1e-08", fmt(ph$p_method_adjusted))
wide <- reshape(ph[c("marker", "contrast", "method", "p_show")],
                idvar = c("marker", "contrast"), timevar = "method", direction = "wide")
names(wide) <- sub("p_show.", "", names(wide), fixed = TRUE)
print(wide, row.names = FALSE)

cat("\nPairwise Welch t:\n")
p2 <- res[res$family == "pairwise_t", ]
print(data.frame(marker = p2$marker, contrast = p2$contrast, diff = round(p2$estimate, 4),
                 p_raw = fmt(p2$p_raw), bonf_within = fmt(p2$p_bonf_within),
                 bh_within = fmt(p2$p_bh_within), bonf_24 = fmt(p2$p_bonf_all24),
                 bh_24 = fmt(p2$p_bh_all24)), row.names = FALSE)
cat(sprintf("\nSignificant at 0.05 among the 24 pairwise t-tests: raw %d, Bonferroni-within %d, BH-within %d, Bonferroni-24 %d, BH-24 %d\n",
            sum(p2$p_raw < 0.05), sum(p2$p_bonf_within < 0.05), sum(p2$p_bh_within < 0.05),
            sum(p2$p_bonf_all24 < 0.05), sum(p2$p_bh_all24 < 0.05)))
