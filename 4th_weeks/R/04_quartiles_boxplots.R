## 04_quartiles_boxplots.R -----------------------------------------------
## Quartile groups of NLR, MLR, SIRI and SII in the analytic sample
## (data/processed/frailty_cbc_analytic.rds, N = 14054), two versions:
##
##   paper  the paper's printed cut-offs (Methods p.3 / Supplemental S2-S5),
##          applied as right-closed intervals (-Inf, c1], (c1, c2], (c2, c3],
##          (c3, Inf). The printed text mixes "<" and "<=" for Q1 and gives
##          SIRI Q3 a lower bound of 0.76 (typo for 1.13); the intervals below
##          are the consistent reading, flagged in the ledger.
##   ours   unweighted sample quartiles of our data (quantile type 7), same
##          right-closed intervals, so tied marker values always share a
##          quartile. Group sizes are therefore NOT exactly equal (MLR:
##          3580 / 3475 / 3582 / 3417). The paper's Table 3 sizes
##          (3376 / 3377 / 3377 / 3377, identical for all four markers) can
##          only come from rank-based splitting (ntile-style), which breaks
##          ties arbitrarily by row order. We keep the value-based cut;
##          rank-based splitting moves 1-7 people per quartile for NLR,
##          SIRI and SII and about 70 for MLR (audit, probe3.R).
##
## R/05-R/07 use the "ours" version as the primary grouping.
##
## Outputs
##   data/processed/analytic_quartiles.rds    analytic data + q_<marker>_paper,
##                                            q_<marker>_ours (factors Q1-Q4)
##   output/tables/04_quartile_cutoffs.csv    cut-offs of both versions
##   output/tables/04_quartile_counts.csv     N per quartile, both versions,
##                                            and cross-classification agreement
##   output/figures/04_fi_boxplot_<marker>.png  FI by quartile, both versions
##
## Rscript R/04_quartiles_boxplots.R
## ------------------------------------------------------------------------

set.seed(20261004L)   # no random numbers are drawn; seeded by convention

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")

d <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_analytic.rds"))
MARKERS <- c("NLR", "MLR", "SIRI", "SII")
Q_LAB   <- c("Q1", "Q2", "Q3", "Q4")

## ========================================================================
## 1. Cut-offs
## ========================================================================

paper_cuts <- list(NLR  = c(1.53, 2.08, 2.83),
                   MLR  = c(0.22, 0.29, 0.38),
                   SIRI = c(0.76, 1.13, 1.68),
                   SII  = c(339.58, 481.85, 689.61))
our_cuts <- Map(function(m) unname(quantile(d[[m]], c(0.25, 0.50, 0.75), type = 7)), MARKERS)

cut_q <- function(x, cuts) cut(x, c(-Inf, cuts, Inf), labels = Q_LAB, right = TRUE)

cut_grid <- expand.grid(marker = MARKERS, version = c("paper", "ours"), stringsAsFactors = FALSE)
new_cols <- Map(function(m, v) {
  cuts <- if (v == "paper") paper_cuts[[m]] else our_cuts[[m]]
  cut_q(d[[m]], cuts)
}, cut_grid$marker, cut_grid$version)
names(new_cols) <- paste0("q_", cut_grid$marker, "_", cut_grid$version)
d[names(new_cols)] <- new_cols

cutoff_tab <- do.call(rbind, Map(function(m, v) {
  cuts <- if (v == "paper") paper_cuts[[m]] else our_cuts[[m]]
  data.frame(marker = m, version = v, c1 = cuts[1], c2 = cuts[2], c3 = cuts[3])
}, cut_grid$marker, cut_grid$version))

## ========================================================================
## 2. Counts per quartile and agreement between the two versions
## ========================================================================

count_tab <- do.call(rbind, Map(function(m) {
  qp <- d[[paste0("q_", m, "_paper")]]; qo <- d[[paste0("q_", m, "_ours")]]
  data.frame(marker = m, quartile = Q_LAB,
             n_paper_cuts = as.vector(table(qp)), n_our_quartiles = as.vector(table(qo)),
             frail_n_paper_cuts = as.vector(tapply(d$frail, qp, sum)),
             frail_n_our_quartiles = as.vector(tapply(d$frail, qo, sum)),
             pct_same_quartile = round(100 * mean(qp == qo), 1))
}, MARKERS))

write.csv(cutoff_tab, file.path(TAB_DIR, "04_quartile_cutoffs.csv"), row.names = FALSE)
write.csv(count_tab,  file.path(TAB_DIR, "04_quartile_counts.csv"),  row.names = FALSE)
saveRDS(d, file.path(PROJ, "data", "processed", "analytic_quartiles.rds"))

## ========================================================================
## 3. FI boxplots by quartile, one figure per marker (Map over markers)
## ========================================================================

plot_marker <- function(m) {
  long <- rbind(
    data.frame(version = "Paper's cut-offs", quartile = d[[paste0("q_", m, "_paper")]], fi = d$fi_score),
    data.frame(version = "Our sample quartiles", quartile = d[[paste0("q_", m, "_ours")]], fi = d$fi_score))
  long$version <- factor(long$version, levels = c("Paper's cut-offs", "Our sample quartiles"))
  p <- ggplot(long, aes(quartile, fi)) +
    geom_boxplot(fill = "grey85", outlier.size = 0.4, outlier.alpha = 0.3) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 2.2, fill = "#C0392B") +
    geom_hline(yintercept = 0.3, linetype = "dashed", colour = "grey40") +
    facet_wrap(~ version) +
    labs(x = paste(m, "quartile"), y = "Frailty index",
         title = sprintf("Frailty index by %s quartile (N = %d)", m, nrow(d)),
         subtitle = "Box: median and IQR; red diamond: mean; dashed line: frail cut-off FI = 0.3") +
    theme_bw(base_size = 11)
  out <- file.path(FIG_DIR, sprintf("04_fi_boxplot_%s.png", m))
  ggsave(out, p, width = 8, height = 4.5, dpi = 150)
  out
}
figs <- Map(plot_marker, MARKERS)

## ========================================================================
## 4. Console
## ========================================================================

cat("Cut-offs:\n"); print(cutoff_tab, row.names = FALSE, digits = 4)
cat("\nN (frail n) per quartile:\n"); print(count_tab, row.names = FALSE)
cat("\nWritten:", unlist(figs), sep = "\n")
