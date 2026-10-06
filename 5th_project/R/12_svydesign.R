## 12_svydesign.R ---------------------------------------------------------
## Survey design for all weighted analyses (Table 1, Tables 2/3, OR vs RR).
##
## Built on the FULL 2009-2018 file (all 49,693 DEMO participants, R/11_v2),
## then subset() to the analytic domain; filtering rows before svydesign()
## would give wrong standard errors (nhanes-survey-data skill).
##   weights  wt_mec10 = WTMEC2YR / 5 (5 pooled cycles; MEC weight because
##            BP is an exam measure). Participants with WTMEC2YR = 0
##            (interview only) stay in the design with weight 0.
##   domain   in_sample & !is.na(htn): the 21,476 analytic participants minus
##            the 18 whose HTN status is unknown (R/13 soft warning) = 21,458
##            (v1 data: 21,417 / 21,399; input switched to v2, CHANGES_v2.md)
##
## Missing-category factors (paper: "missing values for these covariates were
## treated as additional missing categories", plan A8), suffix _m, level
## "Missing" added only where NAs exist in the domain:
##   edu_m, bmi_m, alcohol_m, pa_m, sleep_m, cvd_m, diabetes_m
## Continuous covariates are left as they are here; their missing indicator
## is made in the model script.
## Adds LBXSTR (non-fasting triglyceride, BIOPRO) - see the note below.
##
## Output: data/processed/oral_htn_design.rds
##   list(des = full design, dom = domain design, wt = "wt_mec10")
##
## Rscript R/12_svydesign.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(survey))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

full <- readRDS(file.path(PROJ, "data", "processed", "oral_htn_full_v2.rds"))
full$domain <- full$in_sample & !is.na(full$htn)

## Non-fasting serum triglyceride from the biochemistry profile (BIOPRO
## LBXSTR, measured on all MEC participants). R/20 showed the paper's Table 1
## triglyceride is this one: LBXSTR gives 146.73 / 172.48 vs the paper's
## 146.27 / 172.62, while fasting LBXTR (R/11) gives 115.4 / 139.1.
## Read from the cached raw BIOPRO files that R/11 downloaded.
bio <- do.call(rbind, lapply(paste0("BIOPRO_", c("F", "G", "H", "I", "J")), function(s)
  readRDS(file.path(PROJ, "data", "raw", paste0(s, ".rds")))[, c("SEQN", "LBXSTR")]))
full$LBXSTR <- bio$LBXSTR[match(full$SEQN, bio$SEQN)]

## "Missing" level only for NAs inside the domain; NAs outside the domain
## stay NA, otherwise an empty Missing level breaks svychisq (NaN).
add_missing <- function(x) {
  x <- factor(x)
  miss <- is.na(x) & full$domain
  if (any(miss)) {
    levels(x) <- c(levels(x), "Missing")
    x[miss] <- "Missing"
  }
  x
}
for (v in c("edu", "bmi_cat", "alcohol", "pa", "sleep_cat", "cvd", "diabetes"))
  full[[paste0(sub("_cat$", "", v), "_m")]] <- add_missing(full[[v]])
full$htn_f  <- factor(full$htn, levels = c(0, 1),
                      labels = c("Non-hypertension", "Hypertension"))

des <- svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt_mec10,
                 nest = TRUE, data = full)
dom <- subset(des, domain)

saveRDS(list(des = des, dom = dom, wt = "wt_mec10"),
        file.path(PROJ, "data", "processed", "oral_htn_design.rds"))

cat(sprintf("design: %d rows, %d strata; domain n = %d (in_sample %d, HTN NA %d)\n",
            nrow(full), length(unique(full$SDMVSTRA)), sum(full$domain),
            sum(full$in_sample), sum(full$in_sample & is.na(full$htn))))
cat(sprintf("weighted population in domain: %.1f million\n",
            sum(weights(dom)) / 1e6))
print(sapply(full[full$domain, paste0(c("edu", "bmi", "alcohol", "pa", "sleep",
                                        "cvd", "diabetes"), "_m")],
             function(x) sum(x == "Missing")))
