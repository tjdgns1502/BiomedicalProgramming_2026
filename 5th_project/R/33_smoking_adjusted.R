## 33_smoking_adjusted.R --------------------------------------------------
## Sensitivity analysis for plan A13: the methods list smoking among the
## adjustment covariates, but the Table 2 footnote omits it. Refit the
## all-participants rows of Table 2 (Models 1-3, oral and perio) with smoking
## (SMQ020 ever/never) added, next to the footnote version from R/30.
## Within the smoking strata smoking is constant, so only the "all" rows.
##
## Output: output/tables/33_smoking_adjusted.csv
##   exposure, model, level, or_footnote, lo_footnote, hi_footnote,
##   or_plus_smoking, lo_plus_smoking, hi_plus_smoking, change
##
## Rscript R/33_smoking_adjusted.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "model_utils.R"))

dom <- load_domain(PROJ)
EXPO <- c(oral = "oral4", perio = "perio")

rows <- list()
for (e in names(EXPO)) for (m in names(COVS[["Table 2"]])) {
  covs <- COVS[["Table 2"]][[m]]
  a <- fit_exposure(dom, EXPO[[e]], covs)
  b <- fit_exposure(dom, EXPO[[e]], c(covs, "smoke"))
  rows[[length(rows) + 1]] <- data.frame(
    exposure = e, model = m, level = a$level,
    or_footnote = a$est, lo_footnote = a$lo, hi_footnote = a$hi,
    or_plus_smoking = b$est, lo_plus_smoking = b$lo, hi_plus_smoking = b$hi,
    change = b$est - a$est)
}
res <- do.call(rbind, rows)
write.csv(res, file.path(PROJ, "output", "tables", "33_smoking_adjusted.csv"),
          row.names = FALSE)
print(within(res, { or_footnote <- round(or_footnote, 3)
                    or_plus_smoking <- round(or_plus_smoking, 3)
                    change <- round(change, 3) })[, c("exposure", "model", "level",
      "or_footnote", "or_plus_smoking", "change")], row.names = FALSE)
