## 02_tests_from_paper.R --------------------------------------------------
## Unweighted tests and effect measures on the tables rebuilt in R/01 from
## the paper's Cases/total counts. No NHANES; no survey weights. These are
## the crude baseline that the weighted, adjusted reproduction is read
## against (plan step A).
##
## Unit = one exposure x HTN table: all participants, or one stratum
## (nonsmoking/smoking from Table 2, age<45/age>=45 from Table 3).
##
## Omnibus, per unit (exposure levels x HTN):
##   pearson       chisq.test(correct = FALSE)
##   fisher        fisher.test; for the 4 x 2 oral tables (n up to 21,800)
##                 the network algorithm is tried with a large workspace and
##                 falls back to a Monte Carlo p (B = 1e5, seeded) - the
##                 method column says which
##   cochran_armitage  prop.trend.test, scores 1-4 (oral only): crude P-trend
##
## Each level vs the reference level (2 x 2; rows exposed, reference;
## columns HTN yes, no):
##   pearson, yates   chisq.test(correct = FALSE / TRUE)
##   fisher           p and conditional-MLE OR with its exact CI
##   or_woolf         ad/bc, CI exp(log OR +/- 1.96 sqrt(1/a+1/b+1/c+1/d))
##   rr               p1/p0, CI on the log scale
##   rd               p1 - p0, Wald CI
##
## Across strata (smoking or age), each level vs reference (2 x 2 x 2):
##   cmh              mantelhaen.test(correct = FALSE): MH common OR and p
##   breslow_day      DescTools::BreslowDayTest: homogeneity of the stratum
##                    ORs (an unadjusted, unweighted analogue of the paper's
##                    P-interaction, plan A9)
##   and for the 4-level oral exposure the generalized CMH (4 x 2 x 2).
##
## Output: output/tables/02_crude_tests.csv
##   exposure, strat_by, stratum, contrast, method, estimate, lo, hi,
##   statistic, df, p
##
## Rscript R/02_tests_from_paper.R
## ------------------------------------------------------------------------

set.seed(20261007L)   # only used by the Monte Carlo fallback of fisher.test

suppressPackageStartupMessages(library(DescTools))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
tabs <- readRDS(file.path(PROJ, "data", "processed", "paper_xtabs.rds"))
## Integer counts overflow inside mantelhaen.test: the Robins-Breslow-
## Greenland variance multiplies three cells (e.g. 4664 * 5354 * 909 > 2^31),
## which returns NA for the CI with only a warning. Use doubles.
tabs <- lapply(tabs, function(t) { storage.mode(t) <- "double"; t })
Z975 <- qnorm(0.975)

row_out <- function(exposure, strat_by, stratum, contrast, method,
                    estimate = NA, lo = NA, hi = NA, statistic = NA,
                    df = NA, p = NA)
  data.frame(exposure, strat_by, stratum, contrast, method, estimate, lo, hi,
             statistic, df, p)

fisher_omnibus <- function(tb) {
  if (all(dim(tb) == 2)) return(list(p = fisher.test(tb)$p.value, method = "fisher"))
  r <- tryCatch(fisher.test(tb, workspace = 2e8)$p.value, error = function(e) NULL)
  if (!is.null(r)) return(list(p = r, method = "fisher"))
  list(p = fisher.test(tb, simulate.p.value = TRUE, B = 1e5)$p.value,
       method = "fisher_mc_B1e5")
}

## 2 x 2 for one level vs the reference: rows (level, ref), cols (Yes, No)
two_by_two <- function(tb, lv) {
  ref <- rownames(tb)[1]
  tb[c(lv, ref), c("Yes", "No"), drop = FALSE]
}

contrast_rows <- function(t2, e, sb, st, ctr) {
  a <- t2[1, 1]; b <- t2[1, 2]; c <- t2[2, 1]; d <- t2[2, 2]
  p1 <- a / (a + b); p0 <- c / (c + d)
  pe <- chisq.test(t2, correct = FALSE)
  ya <- chisq.test(t2, correct = TRUE)
  fi <- fisher.test(t2)
  lor <- log(a * d / (b * c)); se_or <- sqrt(1 / a + 1 / b + 1 / c + 1 / d)
  lrr <- log(p1 / p0); se_rr <- sqrt(1 / a - 1 / (a + b) + 1 / c - 1 / (c + d))
  rd <- p1 - p0; se_rd <- sqrt(p1 * (1 - p1) / (a + b) + p0 * (1 - p0) / (c + d))
  rbind(
    row_out(e, sb, st, ctr, "pearson", statistic = pe$statistic, df = pe$parameter, p = pe$p.value),
    row_out(e, sb, st, ctr, "yates", statistic = ya$statistic, df = ya$parameter, p = ya$p.value),
    row_out(e, sb, st, ctr, "fisher", estimate = fi$estimate, lo = fi$conf.int[1],
            hi = fi$conf.int[2], p = fi$p.value),
    row_out(e, sb, st, ctr, "or_woolf", estimate = exp(lor),
            lo = exp(lor - Z975 * se_or), hi = exp(lor + Z975 * se_or)),
    row_out(e, sb, st, ctr, "rr", estimate = exp(lrr),
            lo = exp(lrr - Z975 * se_rr), hi = exp(lrr + Z975 * se_rr)),
    row_out(e, sb, st, ctr, "rd", estimate = rd,
            lo = rd - Z975 * se_rd, hi = rd + Z975 * se_rd))
}

unit_rows <- function(tb, e, sb, st) {
  out <- list()
  pe <- chisq.test(tb, correct = FALSE)
  out[[1]] <- row_out(e, sb, st, "omnibus", "pearson", statistic = pe$statistic,
                      df = pe$parameter, p = pe$p.value)
  fo <- fisher_omnibus(tb)
  out[[2]] <- row_out(e, sb, st, "omnibus", fo$method, p = fo$p)
  if (nrow(tb) > 2) {
    ca <- prop.trend.test(tb[, "Yes"], rowSums(tb), score = seq_len(nrow(tb)))
    out[[3]] <- row_out(e, sb, st, "trend 1-4", "cochran_armitage",
                        statistic = ca$statistic, df = ca$parameter, p = ca$p.value)
  }
  for (lv in rownames(tb)[-1])
    out[[length(out) + 1]] <- contrast_rows(two_by_two(tb, lv), e, sb, st,
                                            paste(lv, "vs", rownames(tb)[1]))
  do.call(rbind, out)
}

res <- list()
for (e in c("oral", "perio")) {
  res[[length(res) + 1]] <- unit_rows(tabs[[paste0(e, "_all")]], e, "none", "all")
  for (sb in c("smoking", "age")) {
    tb3 <- tabs[[paste0(e, "_by_", sb)]]
    for (st in dimnames(tb3)$stratum)
      res[[length(res) + 1]] <- unit_rows(tb3[, , st], e, sb, st)

    ## across strata
    if (nrow(tb3) > 2) {
      g <- mantelhaen.test(tb3[, c("Yes", "No"), ])
      res[[length(res) + 1]] <- row_out(e, sb, "pooled", "omnibus", "cmh_generalized",
                                        statistic = g$statistic, df = g$parameter,
                                        p = g$p.value)
    }
    ref <- rownames(tb3)[1]
    for (lv in rownames(tb3)[-1]) {
      t3 <- tb3[c(lv, ref), c("Yes", "No"), ]
      ctr <- paste(lv, "vs", ref)
      mh <- mantelhaen.test(t3, correct = FALSE)
      bd <- BreslowDayTest(t3)
      res[[length(res) + 1]] <- rbind(
        row_out(e, sb, "pooled", ctr, "cmh", estimate = mh$estimate,
                lo = mh$conf.int[1], hi = mh$conf.int[2],
                statistic = mh$statistic, df = mh$parameter, p = mh$p.value),
        row_out(e, sb, "pooled", ctr, "breslow_day", statistic = bd$statistic,
                df = bd$parameter, p = bd$p.value))
    }
  }
}
res <- do.call(rbind, res)
rownames(res) <- NULL
write.csv(res, file.path(TAB_DIR, "02_crude_tests.csv"), row.names = FALSE)

cat(sprintf("%d rows written to output/tables/02_crude_tests.csv\n", nrow(res)))
show <- res[res$method %in% c("or_woolf", "rr", "cmh", "breslow_day",
                              "cochran_armitage", "fisher", "fisher_mc_B1e5"), ]
print(within(show, { estimate <- round(estimate, 3); lo <- round(lo, 3)
                     hi <- round(hi, 3); statistic <- round(statistic, 2)
                     p <- signif(p, 3) })[, c("exposure", "strat_by", "stratum",
       "contrast", "method", "estimate", "lo", "hi", "p")], row.names = FALSE)
