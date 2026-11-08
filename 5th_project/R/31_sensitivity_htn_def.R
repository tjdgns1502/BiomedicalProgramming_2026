## 31_sensitivity_htn_def.R -----------------------------------------------
## The paper's sensitivity analysis (Supplemental tables I/II, not available):
## hypertension defined by measured blood pressure only, and by physician
## diagnosis or treatment only. The paper's wording is ambiguous; choice
## made here (recorded in the ledger as paper_says = ambiguous):
##   measured   outcome = mean SBP >= 140 or DBP >= 90, regardless of history
##   diagnosed  outcome = BPQ020 == 1 or BPQ050A == 1, regardless of BP
## Each replaces htn in the Table 2 structure (strata all / nonsmoking /
## smoking, Models 1-3, oral and perio), same domain (n = 21,399; rows with
## the component NA drop out of that model).
## The paper's claim to check, qualitatively: oral health is associated with
## both definitions; periodontal disease only with the diagnosed one.
##
## Output: output/tables/31_sensitivity_htn_def.csv
##   definition, stratum, exposure, model, level, or, lo, hi, p, n_used
##
## Rscript R/31_sensitivity_htn_def.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "model_utils.R"))

dom <- load_domain(PROJ)
dom <- update(dom, y_measured = as.numeric(htn_measured),
                   y_diagnosed = as.numeric(htn_diagnosed))
STRATA <- list(all = quote(TRUE), nonsmoking = quote(smoke == "No"),
               smoking = quote(smoke == "Yes"))
EXPO <- c(oral = "oral4", perio = "perio")
DEFS <- c(measured = "y_measured", diagnosed = "y_diagnosed")

rows <- list()
for (df in names(DEFS)) for (st in names(STRATA)) {
  sd <- eval(bquote(subset(dom, .(STRATA[[st]]))))
  for (e in names(EXPO)) for (m in names(COVS[["Table 2"]])) {
    r <- fit_exposure(sd, EXPO[[e]], COVS[["Table 2"]][[m]], outcome = DEFS[[df]])
    rows[[length(rows) + 1]] <- data.frame(definition = df, stratum = st, exposure = e,
      model = m, level = r$level, or = r$est, lo = r$lo, hi = r$hi, p = r$p,
      n_used = r$n_used)
  }
}
res <- do.call(rbind, rows)
write.csv(res, file.path(PROJ, "output", "tables", "31_sensitivity_htn_def.csv"),
          row.names = FALSE)

options(width = 200)
show <- res[res$model == "3", ]
show$ci <- sprintf("%.2f (%.2f-%.2f)", show$or, show$lo, show$hi)
print(reshape(show[, c("definition", "stratum", "exposure", "level", "ci")],
              idvar = c("stratum", "exposure", "level"), timevar = "definition",
              direction = "wide"), row.names = FALSE)
