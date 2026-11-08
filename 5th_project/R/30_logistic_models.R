## 30_logistic_models.R ---------------------------------------------------
## Tables 2 and 3: weighted multivariable ORs of hypertension.
## svyglm(quasibinomial) on the domain design (R/12, n = 21,399), Models
## 1-3 as each table's footnote (model_utils.R COVS), strata by subset() of
## the design (never by filtering rows).
##
##   Table 2  strata all / nonsmoking / smoking; exposures oral (4 levels,
##            ref Excellent/Very good) and perio (ref No)
##   Table 3  strata age<45 / age>=45; same exposures
##   P-trend  oral as a 1-4 score (paper: coding not stated); perio = its
##            Wald p (plan A7, confirmed in R/00)
##   P-interaction  exposure x stratifier product terms added to the model
##            fitted on the whole domain (smoking for Table 2, age group for
##            Table 3), joint Wald test of all product terms with
##            regTermTest (F, design df). For Table 3 the age-group main
##            effect is in the model. Done for all three models; the paper
##            prints one P-interaction per block without saying which model.
##
## Outputs:
##   output/tables/30_models.csv         table, exposure, stratum, model,
##     level, cases, total (unweighted, ours), or, lo, hi, p, n_used,
##     dropped covariates, and paper cases/total, or, lo, hi
##   output/tables/30_ptrend.csv         table, exposure, stratum, model,
##                                       p_trend, paper_p
##   output/tables/30_pinteraction.csv   table, exposure, stratifier, model,
##                                       F, df, p, paper_p
##
## Rscript R/30_logistic_models.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
source(file.path(PROJ, "R", "paper_tables.R"))
source(file.path(PROJ, "R", "model_utils.R"))

dom <- load_domain(PROJ)
STRATA <- list(
  "Table 2" = list(all = quote(TRUE), nonsmoking = quote(smoke == "No"),
                   smoking = quote(smoke == "Yes")),
  "Table 3" = list("age<45" = quote(age_grp == "age<45"),
                   "age>=45" = quote(age_grp == "age>=45")))
EXPO <- c(oral = "oral4", perio = "perio")

or_rows <- list(); tr_rows <- list()
for (tb in names(STRATA)) for (st in names(STRATA[[tb]])) {
  sub_des <- eval(bquote(subset(dom, .(STRATA[[tb]][[st]]))))
  v <- sub_des$variables
  for (e in names(EXPO)) {
    ex <- EXPO[[e]]
    ct <- table(v[[ex]], v$htn)                     # unweighted cases / total
    for (m in names(COVS[[tb]])) {
      r <- fit_exposure(sub_des, ex, COVS[[tb]][[m]])
      lv_all <- levels(v[[ex]])
      pr <- t23[t23$table == tb & t23$exposure == e & t23$stratum == st, ]
      for (lv in lv_all) {
        hit <- r[r$level == lv, ]
        pp <- pr[pr$level == lv, ]
        or_rows[[length(or_rows) + 1]] <- data.frame(
          table = tb, exposure = e, stratum = st, model = m, level = lv,
          cases = ct[lv, "1"], total = sum(ct[lv, ]),
          or = if (nrow(hit)) hit$est else 1, lo = if (nrow(hit)) hit$lo else NA,
          hi = if (nrow(hit)) hit$hi else NA, p = if (nrow(hit)) hit$p else NA,
          n_used = r$n_used[1], dropped = r$dropped[1],
          paper_cases = pp$cases, paper_total = pp$total,
          paper_or = pp[[paste0("or", m)]], paper_lo = pp[[paste0("lo", m)]],
          paper_hi = pp[[paste0("hi", m)]])
      }
      tr_rows[[length(tr_rows) + 1]] <- data.frame(
        table = tb, exposure = e, stratum = st, model = m,
        p_trend = p_trend(sub_des, ex, COVS[[tb]][[m]]),
        paper_p = ptrend$p_text[ptrend$table == tb & ptrend$exposure == e &
                                ptrend$stratum == st & ptrend$model == as.integer(m)])
    }
  }
}
ors <- do.call(rbind, or_rows); trs <- do.call(rbind, tr_rows)

## --- P-interaction ---------------------------------------------------------
int_rows <- list()
STRATIFIER <- c("Table 2" = "smoke", "Table 3" = "age_grp")
for (tb in names(STRATIFIER)) for (e in names(EXPO)) for (m in names(COVS[[tb]])) {
  s <- STRATIFIER[[tb]]; ex <- EXPO[[e]]
  covs <- usable_covs(dom, setdiff(COVS[[tb]][[m]], s))
  d2 <- drop_empty_levels(dom, covs)
  f <- reformulate(c(paste0(ex, " * ", s), covs), response = "htn")
  fit <- svyglm(f, design = d2, family = quasibinomial())
  rt <- regTermTest(fit, as.formula(paste0("~", ex, ":", s)), method = "Wald")
  int_rows[[length(int_rows) + 1]] <- data.frame(
    table = tb, exposure = e, stratifier = s, model = m,
    F = as.numeric(rt$Ftest), df = paste(rt$df, rt$ddf, sep = ", "),
    p = as.numeric(rt$p), paper_p = "<0.001")
}
ints <- do.call(rbind, int_rows)

write.csv(ors, file.path(TAB_DIR, "30_models.csv"), row.names = FALSE)
write.csv(trs, file.path(TAB_DIR, "30_ptrend.csv"), row.names = FALSE)
write.csv(ints, file.path(TAB_DIR, "30_pinteraction.csv"), row.names = FALSE)

## --- console ---------------------------------------------------------------
options(width = 220)
fmt <- function(o, l, h) ifelse(is.na(l), sprintf("%.2f", o),
                                sprintf("%.2f (%.2f-%.2f)", o, l, h))
show <- ors[!is.na(ors$lo), ]
show$ours  <- fmt(show$or, show$lo, show$hi)
show$paper <- fmt(show$paper_or, show$paper_lo, show$paper_hi)
show$diff  <- round(show$or - show$paper_or, 2)
print(show[, c("table", "exposure", "stratum", "model", "level", "ours", "paper",
               "diff")], row.names = FALSE)
cat("\n"); print(within(trs, p_trend <- signif(p_trend, 3)), row.names = FALSE)
cat("\n"); print(within(ints, { F <- round(F, 2); p <- signif(p, 3) }), row.names = FALSE)
cat(sprintf("\n|OR - paper OR|: median %.3f, max %.3f over %d ORs; within 0.03: %d\n",
            median(abs(show$diff)), max(abs(show$diff)), nrow(show),
            sum(abs(show$or - show$paper_or) <= 0.03 + 1e-9)))
dr <- unique(ors$dropped[ors$dropped != ""])
if (length(dr)) cat("dropped (constant/duplicate in subset):", paste(dr, collapse = " | "), "\n")
