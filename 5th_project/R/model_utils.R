## model_utils.R ----------------------------------------------------------
## Shared model pieces for R/30 (Tables 2/3), R/33 (smoking-adjusted
## sensitivity), R/34 (stratum OR decomposition) and R/41 (OR vs RR).
##
##   load_domain()   the domain design from R/12, with continuous covariates
##                   prepared for the paper's missing-data rule (plan A8):
##                   NA -> domain mean (unweighted) + a 0/1 indicator. Diet
##                   (sodium, fat) share one recall, so one indicator; the
##                   labs get one indicator each.
##   COVS            covariate sets of Models 1-3 for Table 2 and Table 3,
##                   exactly as the table footnotes (plan A6). Triglyceride is
##                   the non-fasting LBXSTR (R/20).
##   fit_exposure()  svyglm on a (sub)design for one exposure and one
##                   covariate set; returns one row per non-reference level:
##                   estimate on the link scale exponentiated (OR for logit,
##                   RR for log link), Wald CI (normal, as confint.svyglm),
##                   p from the coefficient table (t on design df).
##                   Indicators that are constant or duplicate another
##                   column inside the subset are dropped (they would be
##                   aliased); dropped terms are returned in `dropped`.
##   p_trend()       oral health as a 1-4 score in place of the factor, Wald
##                   p of the score; for the binary exposure, the Wald p of
##                   perio (= the level p, plan A7).
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(survey))

CONT_COVS <- c(sodium = "DR1TSODI", fat = "DR1TTFAT", tc = "LBXTC",
               creat = "LBXSCR", tg = "LBXSTR", hba1c = "LBXGH", hdl = "LBDHDD")

load_domain <- function(proj) {
  dd <- readRDS(file.path(proj, "data", "processed", "oral_htn_design.rds"))
  des <- dd$des
  v <- des$variables
  dm <- v$domain
  for (k in names(CONT_COVS)) {
    x <- v[[CONT_COVS[k]]]
    v[[paste0(k, "_i")]] <- ifelse(is.na(x), mean(x[dm], na.rm = TRUE), x)
  }
  v$diet_miss  <- as.integer(is.na(v$DR1TSODI) | is.na(v$DR1TTFAT))
  for (k in c("tc", "creat", "tg", "hba1c", "hdl"))
    v[[paste0(k, "_miss")]] <- as.integer(is.na(v[[CONT_COVS[k]]]))
  v$oral_score <- as.integer(v$oral4)           # 1 = Excellent/VG ... 4 = Poor
  v$age_grp <- factor(ifelse(v$age < 45, "age<45", "age>=45"),
                      levels = c("age<45", "age>=45"))
  des$variables <- v
  subset(des, domain)
}

M2_T2_EXTRA <- c("bmi_m", "sleep_m", "alcohol_m", "pa_m", "cvd_m", "diabetes_m",
                 "sodium_i", "fat_i", "diet_miss")
LABS <- c("tc_i", "creat_i", "tg_i", "hba1c_i", "hdl_i",
          "tc_miss", "creat_miss", "tg_miss", "hba1c_miss", "hdl_miss")
COVS <- list(
  "Table 2" = list(
    "1" = c("age", "sex", "race", "edu_m"),
    "2" = c("age", "sex", "race", "edu_m", M2_T2_EXTRA),
    "3" = c("age", "sex", "race", "edu_m", M2_T2_EXTRA, LABS)),
  "Table 3" = list(
    "1" = c("sex", "race", "edu_m"),
    "2" = c("sex", "race", "edu_m", "bmi_m", "sleep_m", "alcohol_m", "pa_m", "smoke"),
    "3" = c("sex", "race", "edu_m", "bmi_m", "sleep_m", "alcohol_m", "pa_m", "smoke",
            LABS)))

## drop covariates that are constant in the subset, and 0/1 indicators that
## duplicate an earlier indicator
usable_covs <- function(design, covs) {
  v <- design$variables
  keep <- character(0)
  for (cv in covs) {
    x <- v[[cv]]
    if (is.factor(x)) x <- droplevels(x)
    if (length(unique(x)) < 2) next
    if (grepl("_miss$", cv) &&
        any(vapply(keep[grepl("_miss$", keep)], function(k) all(v[[k]] == v[[cv]]), TRUE)))
      next
    keep <- c(keep, cv)
  }
  keep
}

## factor covariates may have levels that are empty in the subset
drop_empty_levels <- function(design, covs) {
  for (cv in covs) if (is.factor(design$variables[[cv]]))
    design$variables[[cv]] <- droplevels(design$variables[[cv]])
  design
}

fit_exposure <- function(design, exposure, covs, outcome = "htn",
                         family = quasibinomial(), ...) {
  covs_u <- usable_covs(design, covs)
  design <- drop_empty_levels(design, c(exposure, covs_u))
  f <- reformulate(c(exposure, covs_u), response = outcome)
  m <- svyglm(f, design = design, family = family, ...)   # ... e.g. start, maxit
  cf <- summary(m)$coefficients
  rows <- grep(paste0("^", exposure), rownames(cf))
  ci <- confint(m, parm = rownames(cf)[rows])
  data.frame(term = rownames(cf)[rows],
             level = sub(paste0("^", exposure), "", rownames(cf)[rows]),
             est = exp(cf[rows, 1]), lo = exp(ci[, 1]), hi = exp(ci[, 2]),
             p = cf[rows, 4], n_used = length(m$y),
             dropped = paste(setdiff(covs, covs_u), collapse = ";"),
             row.names = NULL)
}

p_trend <- function(design, exposure, covs, outcome = "htn",
                    family = quasibinomial()) {
  if (exposure == "perio")
    return(fit_exposure(design, "perio", covs, outcome, family)$p)
  covs_u <- usable_covs(design, covs)
  design <- drop_empty_levels(design, covs_u)
  m <- svyglm(reformulate(c("oral_score", covs_u), response = outcome),
              design = design, family = family)
  summary(m)$coefficients["oral_score", 4]
}
