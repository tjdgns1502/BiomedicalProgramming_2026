## 00_paper_consistency.R -------------------------------------------------
## Paper-only consistency checks (no NHANES data), run before reproduction
## so errors in the paper are separated from errors in our code. The checks
## are the table-consistency / derived-statistic items of the
## scienceclaw-verification checklist, written out in R.
##
##   ci_center   OR vs geometric mean of its CI, sqrt(lo * hi). A Wald CI on
##               the log scale is symmetric about log(OR). Tolerance is the
##               worst case of 2-dp rounding of OR, lo and hi.
##   p_from_ci   Wald p back-computed from the CI: se = (ln hi - ln lo) / 3.92,
##               z = ln OR / se. Evaluated at every corner of the rounding box
##               (OR, lo, hi each +/- 0.005) to get [p_min, p_max]. For the
##               binary periodontal exposure the paper's P-trend must equal
##               this Wald p (plan A7), so it must fall inside [p_min, p_max].
##   trend_vs_level  Oral health (4 levels): the smallest single-level p is
##               reported next to P-trend. When ORs rise monotonically, a trend
##               p much larger than the best level p is implausible. Heuristic
##               only: pass = NA, it is a flag for reading, not a verdict.
##   sum_*       Table 1 column sums vs the header N, weighted % sums vs 100,
##               Table 1 vs Table 2 counts, strata of Tables 2/3 vs the
##               all-participants rows.
##
## Output: output/tables/00_paper_consistency.csv
##   check, table, exposure, stratum, level, model, reported, computed,
##   computed_lo, computed_hi, pass, note
##
## Rscript R/00_paper_consistency.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
source(file.path(PROJ, "R", "paper_tables.R"))

Z975 <- qnorm(0.975)
RND  <- 0.005   # half a unit in the 2nd decimal

row_out <- function(check, table = NA, exposure = NA, stratum = NA, level = NA,
                    model = NA, reported = NA, computed = NA, computed_lo = NA,
                    computed_hi = NA, pass = NA, note = "")
  data.frame(check, table, exposure, stratum, level, model,
             reported = as.character(reported), computed, computed_lo,
             computed_hi, pass, note)

wald_p <- function(or, lo, hi) {
  se <- (log(hi) - log(lo)) / (2 * Z975)
  2 * pnorm(-abs(log(or) / se))
}

## p over the rounding box of (or, lo, hi)
wald_p_range <- function(or, lo, hi) {
  g <- expand.grid(o = or + c(-RND, RND), l = lo + c(-RND, RND),
                   h = hi + c(-RND, RND))
  p <- wald_p(g$o, g$l, g$h)
  ## the box may contain or = 1 exactly (z = 0, p = 1) only if it straddles 1
  if (or - RND <= 1 && or + RND >= 1) p <- c(p, 1)
  range(p)
}

## "<0.001" -> interval (0, 0.001); "0.032" -> [0.0315, 0.0325) at its digits
p_text_interval <- function(s) {
  if (startsWith(s, "<")) return(c(0, as.numeric(sub("<", "", s))))
  v <- as.numeric(s)
  d <- nchar(sub("^[^.]*\\.", "", s))
  c(v - 0.5 * 10^-d, v + 0.5 * 10^-d)
}

out <- list()

## --- 1 + 2: CI centre and p from CI, every non-reference OR ---------------
nonref <- t23[!is.na(t23$lo1), ]
for (i in seq_len(nrow(nonref))) {
  r <- nonref[i, ]
  for (m in 1:3) {
    or <- r[[paste0("or", m)]]; lo <- r[[paste0("lo", m)]]; hi <- r[[paste0("hi", m)]]
    implied <- sqrt(lo * hi)
    tol <- RND + 0.5 * implied * (RND / lo + RND / hi)
    out[[length(out) + 1]] <- row_out(
      "ci_center", r$table, r$exposure, r$stratum, r$level, m,
      reported = or, computed = implied, computed_lo = implied - tol,
      computed_hi = implied + tol, pass = abs(or - implied) <= tol,
      note = sprintf("log asymmetry (hi side - lo side) = %.4f",
                     (log(hi) - log(or)) - (log(or) - log(lo))))
    pr <- wald_p_range(or, lo, hi)
    out[[length(out) + 1]] <- row_out(
      "p_from_ci", r$table, r$exposure, r$stratum, r$level, m,
      reported = NA, computed = wald_p(or, lo, hi),
      computed_lo = pr[1], computed_hi = pr[2], pass = NA,
      note = "Wald p implied by the printed CI")
  }
}
pci <- do.call(rbind, out[sapply(out, function(x) x$check == "p_from_ci")])

## --- 2b: periodontal P-trend must equal the Wald p of the single contrast --
pt_perio <- ptrend[ptrend$exposure == "perio", ]
for (i in seq_len(nrow(pt_perio))) {
  r <- pt_perio[i, ]
  w <- pci[pci$table == r$table & pci$exposure == "perio" &
           pci$stratum == r$stratum & pci$model == r$model, ]
  rep_iv <- p_text_interval(r$p_text)
  ok <- rep_iv[1] <= w$computed_hi && rep_iv[2] >= w$computed_lo
  out[[length(out) + 1]] <- row_out(
    "ptrend_binary", r$table, "perio", r$stratum, "Yes vs No", r$model,
    reported = r$p_text, computed = w$computed, computed_lo = w$computed_lo,
    computed_hi = w$computed_hi, pass = ok,
    note = "binary exposure: P-trend should be the Wald p of Yes vs No")
}

## --- 3: oral health P-trend vs best single-level p (heuristic) ------------
pt_oral <- ptrend[ptrend$exposure == "oral", ]
for (i in seq_len(nrow(pt_oral))) {
  r <- pt_oral[i, ]
  w <- pci[pci$table == r$table & pci$exposure == "oral" &
           pci$stratum == r$stratum & pci$model == r$model, ]
  ors <- t23[t23$table == r$table & t23$exposure == "oral" &
             t23$stratum == r$stratum, paste0("or", r$model)]
  mono <- all(diff(ors) > 0)
  rep_iv <- p_text_interval(r$p_text)
  best <- min(w$computed)
  flag <- mono && rep_iv[1] > 10 * best
  out[[length(out) + 1]] <- row_out(
    "trend_vs_level", r$table, "oral", r$stratum, "trend", r$model,
    reported = r$p_text, computed = best, pass = NA,
    note = paste0(if (mono) "ORs monotone increasing; " else "ORs not monotone; ",
                  if (flag) "FLAG: P-trend > 10x the smallest level p"
                  else "no flag"))
}

## --- 4: sums ---------------------------------------------------------------
for (v in unique(t1cat$variable)) {
  s <- t1cat[t1cat$variable == v, ]
  for (g in c("non", "htn")) {
    n_sum <- sum(s[[paste0("n_", g)]])
    target <- if (g == "non") N_NON else N_HTN
    out[[length(out) + 1]] <- row_out(
      "sum_table1_n", "Table 1", v, g, "all levels", NA,
      reported = target, computed = n_sum, pass = n_sum == target,
      note = "column sum vs header N")
    p_sum <- sum(s[[paste0("pct_", g)]])
    out[[length(out) + 1]] <- row_out(
      "sum_table1_pct", "Table 1", v, g, "all levels", NA,
      reported = 100, computed = p_sum,
      pass = abs(p_sum - 100) <= 0.005 * nrow(s) + 1e-9,
      note = "weighted % sum vs 100 (tolerance: 0.005 per printed cell)")
  }
}

## Table 1 vs Table 2 all-participants rows: HTN n = cases, non-HTN n = total - cases
map12 <- list(
  oral  = list(var = "Oral", levels = c("Excellent/Very good", "Good", "Fair", "Poor")),
  perio = list(var = "Periodontal", levels = c("No", "Yes")))
for (e in names(map12)) {
  for (lv in map12[[e]]$levels) {
    a <- t23[t23$table == "Table 2" & t23$exposure == e & t23$stratum == "all" &
             t23$level == lv, ]
    b <- t1cat[t1cat$variable == map12[[e]]$var & t1cat$level == lv, ]
    out[[length(out) + 1]] <- row_out(
      "sum_t1_vs_t2", "Table 1 vs 2", e, "all", lv, NA,
      reported = sprintf("T1 %d / %d", b$n_htn, b$n_non),
      computed = NA, pass = a$cases == b$n_htn && (a$total - a$cases) == b$n_non,
      note = sprintf("T2 cases %d, non-cases %d", a$cases, a$total - a$cases))
  }
}

## Smoking split of Table 2 vs Table 1 smoking row
for (st in c("nonsmoking", "smoking")) {
  b <- t1cat[t1cat$variable == "Smoking" & t1cat$level == if (st == "smoking") "Yes" else "No", ]
  for (e in c("oral", "perio")) {
    a <- t23[t23$table == "Table 2" & t23$exposure == e & t23$stratum == st, ]
    out[[length(out) + 1]] <- row_out(
      "sum_t1_vs_t2", "Table 1 vs 2", e, st, "all levels", NA,
      reported = sprintf("T1 %d / %d", b$n_htn, b$n_htn + b$n_non),
      computed = NA,
      pass = sum(a$cases) == b$n_htn && sum(a$total) == b$n_htn + b$n_non,
      note = sprintf("T2 cases %d, total %d", sum(a$cases), sum(a$total)))
  }
}

## Strata add up to the all-participants rows (Table 2 smoking, Table 3 age)
strata <- list("Table 2" = c("nonsmoking", "smoking"), "Table 3" = c("age<45", "age>=45"))
all_rows <- t23[t23$table == "Table 2" & t23$stratum == "all", ]
for (tb in names(strata)) {
  for (i in seq_len(nrow(all_rows))) {
    r <- all_rows[i, ]
    s <- t23[t23$table == tb & t23$exposure == r$exposure &
             t23$level == r$level & t23$stratum %in% strata[[tb]], ]
    out[[length(out) + 1]] <- row_out(
      "sum_strata", tb, r$exposure, paste(strata[[tb]], collapse = "+"),
      r$level, NA, reported = sprintf("all %d / %d", r$cases, r$total),
      computed = NA, pass = sum(s$cases) == r$cases && sum(s$total) == r$total,
      note = sprintf("strata sum %d / %d", sum(s$cases), sum(s$total)))
  }
}

res <- do.call(rbind, out)
write.csv(res, file.path(TAB_DIR, "00_paper_consistency.csv"), row.names = FALSE)

cat(sprintf("%d checks written; pass TRUE %d, FALSE %d, NA (informational) %d\n",
            nrow(res), sum(res$pass %in% TRUE), sum(res$pass %in% FALSE),
            sum(is.na(res$pass))))
fails <- res[res$pass %in% FALSE | grepl("FLAG", res$note), ]
if (nrow(fails)) {
  cat("\nFailed checks and flags:\n")
  print(fails[, c("check", "table", "exposure", "stratum", "level", "model",
                  "reported", "computed", "computed_lo", "computed_hi", "note")],
        row.names = FALSE, digits = 4)
}
