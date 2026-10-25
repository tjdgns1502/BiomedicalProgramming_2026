## 08_fill_ledger.R ------------------------------------------------------
## Fill "our" values into output/tables/ledger.csv for every target still
## pending (Methods cut-offs, Results text medians, Table 1 CBC indicators,
## Table 2, Table 3), following the paper-reproduction-ledger procedure:
## abs_diff, status, cause and evidence. Target values are never edited.
## Rows filled earlier (Fig. 1, Table 1 N / N %) are left untouched.
##
## Our value used for each target (the version closest to the paper's
## method, chosen in R/07 before filling the ledger):
##   cut-offs, text medians   unweighted sample quartiles  (R/04)
##   Table 1                  survey-weighted quantiles (svyquantile) and
##                            svyranktest (the paper's footnote c: "Wilcoxon
##                            rank-sum test for complex survey samples")
##   Table 2                  weighted svyglm, OR per 1-unit log10(marker)
##                            (per-ln ORs, 1.26-1.88, match no cell of the
##                            paper's Table 2; see 07_table2_logistic.csv)
##   Table 3                  weighted svyglm, our sample quartiles; Event / N
##                            unweighted counts (R/07)
##
## Causes are assigned only with evidence; everything else is "open".
##   sample exclusion   descriptive statistics of the markers alone (cut-offs,
##                      text medians, Table 1 Total column, quartile N): our
##                      analytic sample differs (N 14054 vs 13507,
##                      exclusion_flow.csv), and the marker formulas match the
##                      paper's Methods.
##   paper typo         internal evidence in the paper (flags written when the
##                      targets were extracted).
##   open               anything that depends on the frailty split (ORs,
##                      events, FI-stratified medians): the frail-prevalence
##                      gap (18.7% vs 24%, ledger Table 1 N % rows) is not
##                      explained, so no cause is proven.
##
## Rscript R/08_fill_ledger.R
## ------------------------------------------------------------------------

set.seed(20261008L)   # no random numbers are drawn; seeded by convention

suppressPackageStartupMessages(library(survey))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB <- function(x) file.path(PROJ, "output", "tables", x)

L <- read.csv(TAB("ledger.csv"), colClasses = "character")
MARKERS <- c("NLR", "MLR", "SIRI", "SII")

## ========================================================================
## 1. Our values, as a lookup keyed by table | row | col
## ========================================================================

key <- function(t, r, c) paste(t, r, c, sep = " | ")
vals <- list()
put  <- function(k, v) vals[[k]] <<- v

## Methods cut-offs and Results text medians: our sample quartiles
cuts <- read.csv(TAB("04_quartile_cutoffs.csv"))
cuts <- cuts[cuts$version == "ours", ]
invisible(Map(function(m, c1, c2, c3) {
  put(key("Methods p.3", m, "Q1 upper"), c1); put(key("Methods p.3", m, "Q2 lower"), c1)
  put(key("Methods p.3", m, "Q2 upper"), c2); put(key("Methods p.3", m, "Q3 lower"), c2)
  put(key("Methods p.3", m, "Q3 upper"), c3); put(key("Methods p.3", m, "Q4 lower"), c3)
  put(key("Results text p.3", m, "median"), c2)
  put(key("Results text p.3", m, "IQR lower"), c1); put(key("Results text p.3", m, "IQR upper"), c3)
}, cuts$marker, cuts$c1, cuts$c2, cuts$c3))

## Table 1: weighted quartiles by frailty group, survey rank test
des <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_svydesign.rds"))
des <- update(des, frail_f = factor(frail_num))
groups <- list(Total = des, `FI<=0.3` = subset(des, frail_num == 0), `FI>0.3` = subset(des, frail_num == 1))
t1_grid <- expand.grid(marker = MARKERS, group = names(groups), stringsAsFactors = FALSE)
invisible(Map(function(m, g) {
  q <- coef(svyquantile(as.formula(paste0("~", m)), groups[[g]], quantiles = c(0.25, 0.5, 0.75)))
  put(key("Table 1 p.5", m, paste(g, "p25")), q[[1]])
  put(key("Table 1 p.5", m, paste(g, "median")), q[[2]])
  put(key("Table 1 p.5", m, paste(g, "p75")), q[[3]])
}, t1_grid$marker, t1_grid$group))
t1_p <- Map(function(m) svyranktest(as.formula(paste(m, "~ frail_f")), des)$p.value, MARKERS)
invisible(Map(function(m) put(key("Table 1 p.5", m, "P"), t1_p[[m]]), MARKERS))

## Table 2: weighted, per log10 unit
t2 <- read.csv(TAB("07_table2_logistic.csv"))
t2 <- t2[t2$weighting == "weighted", ]
invisible(Map(function(m, mod, or, l, u, p) {
  lab <- if (mod == "model1") "Model 1" else "Model 2"
  r <- paste0("log", m)
  put(key("Table 2 p.6", r, paste(lab, "OR")), or)
  put(key("Table 2 p.6", r, paste(lab, "CI lower")), l)
  put(key("Table 2 p.6", r, paste(lab, "CI upper")), u)
  put(key("Table 2 p.6", r, paste(lab, "P")), p)
}, t2$marker, t2$model, t2$or_per_log10, t2$lcl_log10, t2$ucl_log10, t2$p))

## Table 3: weighted, our sample quartiles
t3 <- read.csv(TAB("07_table3_quartiles.csv"))
t3 <- t3[t3$weighting == "weighted" & t3$quartile_version == "ours", ]
invisible(Map(function(m, mod, q, or, l, u, ev, n, pt) {
  lab <- if (mod == "model1") "Model 1" else "Model 2"
  r <- paste(m, q)
  put(key("Table 3 p.6", r, "Event"), ev); put(key("Table 3 p.6", r, "N"), n)
  put(key("Table 3 p.6", r, "Event/N"), sprintf("%d/%d", ev, n))
  if (q != "Q1") {
    put(key("Table 3 p.6", r, paste(lab, "OR")), or)
    put(key("Table 3 p.6", r, paste(lab, "CI lower")), l)
    put(key("Table 3 p.6", r, paste(lab, "CI upper")), u)
  }
  put(key("Table 3 p.6", m, paste(lab, "p trend")), pt)
}, t3$marker, t3$model, t3$quartile, t3$or, t3$lcl, t3$ucl, t3$events, t3$n, t3$p_trend))
a <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_analytic.rds"))
invisible(Map(function(m) {
  put(key("Table 3 p.6", m, "Event (overall)"), sum(a$frail_num))
  put(key("Table 3 p.6", m, "N (overall)"), nrow(a))
}, MARKERS))

## ========================================================================
## 2. Cause and evidence rules
## ========================================================================

EV_SAMPLE <- "our analytic N 14054 vs paper 13507 (output/tables/exclusion_flow.csv; Fig. 1 rows open); marker formulas as in Methods p.2"
EV_FRAIL  <- "depends on the frailty split; frail prevalence 18.7% weighted vs paper 24% is unexplained (ledger Table 1 N % rows, both FI builds agree: 22_fi_comparison_summary.csv)"
src_ev <- function(t) switch(t,
  "Methods p.3"      = "ours: unweighted sample quartiles, output/tables/04_quartile_cutoffs.csv (R/04)",
  "Results text p.3" = "ours: unweighted sample quartiles, output/tables/04_quartile_cutoffs.csv (R/04)",
  "Table 1 p.5"      = "ours: svyquantile / svyranktest on data/processed/frailty_cbc_svydesign.rds (R/08)",
  "Table 2 p.6"      = "ours: weighted svyglm, OR per log10 unit, output/tables/07_table2_logistic.csv (R/07); per-ln ORs 1.26-1.88 match no paper cell, so the paper's log is base 10",
  "Table 3 p.6"      = "ours: weighted svyglm, our sample quartiles, output/tables/07_table3_quartiles.csv (R/07)")

cause_for <- function(t, r, c, target) {
  if (t == "Methods p.3" && r == "SIRI" && c == "Q3 lower")
    return(c("paper typo", "Q3 lower bound printed as 0.76 overlaps Q2 (> 0.76, <= 1.13); Results p.3 gives SIRI IQR [0.76, 1.68], so the contiguous bound is 1.13"))
  if (t == "Table 3 p.6" && c == "Event/N" && r == "SIRI Q4")
    return(c("paper typo", "printed '12,313,377' (slash lost); read as 1231/3377 the SIRI Q1-Q4 events sum to 3747, not the printed 3729; the total implies 1213/3377"))
  if (t == "Table 3 p.6" && c == "Event/N" && r == "SII Q4")
    return(c("paper typo", "printed '11,813,377' (slash lost); 1181/3377 makes SII Q1-Q4 events sum to the printed 3729"))
  if (t %in% c("Methods p.3", "Results text p.3")) return(c("sample exclusion", EV_SAMPLE))
  if (t == "Table 1 p.5" && grepl("^Total", c)) return(c("sample exclusion", EV_SAMPLE))
  if (t == "Table 3 p.6" && c %in% c("N", "N (overall)")) return(c("sample exclusion", EV_SAMPLE))
  c("", EV_FRAIL)
}

## ========================================================================
## 3. Fill the pending rows
## ========================================================================

pending <- which(L$status == "")
filled <- Map(function(i) {
  r <- L[i, ]
  k <- key(r$table, r$row, r$col)
  v <- vals[[k]]
  if (is.null(v)) {
    r$status <- "not reproduced"
    r$evidence <- paste(c(r$evidence[nzchar(r$evidence)], "no value computed for this cell"), collapse = " | ")
    return(r)
  }
  ce <- cause_for(r$table, r$row, r$col, r$target)
  r$ours <- if (is.character(v)) v else format(v, digits = 15)
  if (r$tolerance == "bound") {
    thr <- as.numeric(sub("^<", "", r$target))
    ok  <- v < thr
    r$status <- if (ok) "match" else if (nzchar(ce[1])) "mismatch" else "open"
  } else if (!nzchar(r$tolerance)) {                  # non-numeric target (typo rows)
    r$status <- if (nzchar(ce[1])) "mismatch" else "open"
  } else {
    d <- abs(v - as.numeric(r$target))
    r$abs_diff <- format(d, digits = 6)
    r$status <- if (d <= as.numeric(r$tolerance)) "match" else if (nzchar(ce[1])) "mismatch" else "open"
  }
  if (r$status == "match") {
    r$cause <- ""
    new_ev <- src_ev(r$table)
  } else {
    r$cause <- ce[1]
    new_ev <- paste(src_ev(r$table), ce[2], sep = "; ")
  }
  r$evidence <- paste(c(r$evidence[nzchar(r$evidence)], new_ev), collapse = " | ")
  r
}, pending)
L[pending, ] <- do.call(rbind, filled)

write.csv(L, TAB("ledger.csv"), row.names = FALSE, na = "")

## ========================================================================
## 4. Console: status counts (skill rule) and a per-table breakdown
## ========================================================================

L$status <- factor(L$status, levels = c("match", "mismatch", "not reproduced", "open"))
cat("Ledger status counts (all", nrow(L), "rows):\n"); print(table(L$status))
cat("\nBy table:\n"); print(table(L$table, L$status))
cat("\nMismatch causes:\n"); print(table(L$cause[L$status == "mismatch"]))
