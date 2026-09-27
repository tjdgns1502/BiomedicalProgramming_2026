## 09_ai_error_healthcare.R ----------------------------------------------
## Before / after numbers for one AI error that changed results this week:
## the frailty-index "healthcare use" item.
##
## The error (nhanes-data-builder, first version of R/20): "10+ visits in
## the past year" was coded as code >= 6 for every cycle. That is the right
## cut-off for HUQ051 (2013-2016, codes 0-8) but HUQ050 (1999-2012) only has
## codes 0-5 (4 = 10-12 visits, 5 = 13+), so the deficit could never be
## scored for anyone in 1999-2012. Caught by ai-error-auditor (checking the
## code against the NHANES codebooks), verified against data/raw/HUQ*.rds.
##
## Method: evaluate R/20's own FI section on the saved pooled file twice,
## once as committed ("after") and once with only the HUQ050 cut-off reverted
## to >= 6 ("before"). Every other fix stays in both, so the difference is
## this error alone. The analytic sample is the same in both runs (the item's
## availability does not change, only its value).
##
## Output: output/tables/09_ai_error_healthcare.csv
##
## Rscript R/09_ai_error_healthcare.R
## ------------------------------------------------------------------------

set.seed(20261009L)   # no random numbers are drawn; seeded by convention

suppressPackageStartupMessages(library(survey))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

full <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_pooled.rds"))
src  <- readLines(file.path(PROJ, "R", "20_build_analytic_sample.R"), encoding = "UTF-8")
yn01 <- eval(parse(text = grep("^yn01 <- function", src, value = TRUE)))
fi_code <- src[grep("^fi <- data.frame\\(SEQN = full\\$SEQN\\)", src):grep("^full\\$frail_num", src)]

## The two HUQ050 lines of the fix; reverting them restores the error.
fixed_hi <- 'full$healthcare_use >= 4'
fixed_lo <- 'full$healthcare_use < 4'
stopifnot(sum(grepl(fixed_hi, fi_code, fixed = TRUE)) == 1,
          sum(grepl(fixed_lo, fi_code, fixed = TRUE)) == 1)
buggy_code <- sub(fixed_lo, 'full$healthcare_use < 6', sub(fixed_hi, 'full$healthcare_use >= 6', fi_code, fixed = TRUE), fixed = TRUE)

run_fi <- function(code) {
  e <- new.env(); e$full <- full; e$yn01 <- yn01
  eval(parse(text = code), envir = e)
  list(full = e$full, fi = e$fi)
}
after  <- run_fi(fi_code)
before <- run_fi(buggy_code)
stopifnot(identical(after$full$fi_score, full$fi_score))   # "after" = committed data

des <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_svydesign.rds"))
idx <- match(des$variables$SEQN, full$SEQN)
an  <- full$analytic_sample
old50 <- full$cycle %in% c("1999-2000", "2001-2002", "2003-2004", "2005-2006",
                           "2007-2008", "2009-2010", "2011-2012")

summarise <- function(label, r) {
  frail <- r$full$fi_score > 0.3
  ## computed outside update(): update() evaluates in the design's data,
  ## where a column named `frail` would shadow this local vector
  fx <- as.numeric(frail[idx])
  d2 <- update(des, frail_x = fx)
  w <- svymean(~frail_x, d2)
  data.frame(version = label,
             analytic_n = sum(an),
             healthcare_deficit_pct_1999_2012 = 100 * mean(r$fi$healthcare_use[an & old50] == 1, na.rm = TRUE),
             healthcare_deficit_pct_2013_2016 = 100 * mean(r$fi$healthcare_use[an & !old50] == 1, na.rm = TRUE),
             mean_fi = mean(r$full$fi_score[an]),
             frail_n = sum(frail[an]),
             frail_pct_unweighted = 100 * mean(frail[an]),
             frail_pct_weighted = 100 * coef(w)[[1]],
             frail_pct_weighted_se = 100 * SE(w)[[1]])
}
res <- rbind(summarise("before fix (HUQ050 >= 6)", before),
             summarise("after fix (HUQ050 >= 4)", after))
write.csv(res, file.path(PROJ, "output", "tables", "09_ai_error_healthcare.csv"), row.names = FALSE)
print(res, row.names = FALSE, digits = 4)
