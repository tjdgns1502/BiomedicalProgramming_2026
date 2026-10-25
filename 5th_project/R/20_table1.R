## 20_table1.R ------------------------------------------------------------
## Table 1 reproduction: characteristics by hypertension status, weighted.
## Domain design from R/12 (n = 21,399; weights WTMEC2YR / 5).
##
## Categorical rows: unweighted n (as the paper: "All N are analytic sample
## N") and weighted column % (svytable, margin = HTN group, Missing level
## included in the denominator as in the paper).
## Four tests per categorical variable, to see which one the paper used
## (plan A10; SAS PROC SURVEYFREQ / CHISQ defaults to the first-order
## Rao-Scott chi-square):
##   naive_weighted   chisq.test() on svytable() weighted counts: N becomes
##                    the population (175 million) -> p collapses to 0.
##                    Wrong on purpose, for comparison.
##   rao_scott_1      svychisq(statistic = "Chisq"): Pearson X2 divided by
##                    the mean generalized design effect, vs chi-square(df)
##   rao_scott_2      svychisq(statistic = "F"): second-order
##                    (Satterthwaite) correction, F reference distribution
##   unweighted       chisq.test(correct = FALSE) on the unweighted n
## Continuous rows: svymean by group (SE), svyttest p.
## Triglyceride: the main row is LBXSTR (non-fasting, biochemistry profile,
## all MEC participants), which matches the paper's 146.27 / 172.62. Two
## extra rows keep the fasting LBXTR (first guess, R/11) with the MEC weight
## and with the fasting-subsample weight WTSAF2YR / 5 (plan A5), as evidence.
##
## Outputs:
##   output/tables/20_table1_categorical.csv  variable, level, ours and paper
##                                            n and weighted % per group
##   output/tables/20_table1_tests.csv        variable, method, statistic,
##                                            df, p, paper_p
##   output/tables/20_table1_continuous.csv   variable, weight, ours and
##                                            paper mean (SE), p
##
## Rscript R/20_table1.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(survey))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
source(file.path(PROJ, "R", "paper_tables.R"))

dd  <- readRDS(file.path(PROJ, "data", "processed", "oral_htn_design.rds"))
dom <- dd$dom

## paper variable -> our variable, and our level -> paper level (in order)
VARS <- list(
  Sex                 = list("sex",     c(Male = "Male", Female = "Female")),
  Race                = list("race",    c("Mexican American" = "Mexican American",
                                          "Other Hispanic" = "Other Hispanic",
                                          "Non-Hispanic White" = "Non-Hispanic White",
                                          "Non-Hispanic Black" = "Non-Hispanic Black",
                                          "Other/multi-racial" = "Other/Multi-racial")),
  Smoking             = list("smoke",   c(Yes = "Yes", No = "No")),
  Periodontal         = list("perio",   c(Yes = "Yes", No = "No")),
  Oral                = list("oral4",   c("Excellent/Very good" = "Excellent/Very good",
                                          Good = "Good", Fair = "Fair", Poor = "Poor")),
  Education           = list("edu_m",   c("<HS" = "<High school", HS = "High school",
                                          ">HS" = ">High school", Missing = "Missing")),
  BMI                 = list("bmi_m",   c("<18.5" = "<18.5", "18.5-24.9" = "18.5-24.9",
                                          "25-29.9" = "25-29.9", ">=30" = ">=30",
                                          Missing = "Missing")),
  Sleep               = list("sleep_m", c("<7 h" = "<7", "7-9 h" = "7-9", ">9 h" = ">9",
                                          Missing = "Missing")),
  Alcohol             = list("alcohol_m", c("No drinks" = "No drinks",
                                            "<=1 drink/week" = "<=1 drink/week",
                                            ">1 drink/week" = ">1 drink/week",
                                            Missing = "Missing")),
  "Physical activity" = list("pa_m",    c(Inactive = "Inactive", Active = "Active",
                                          Missing = "Missing")),
  "History of CVD"    = list("cvd_m",   c(Yes = "Yes", No = "No", Missing = "Missing")),
  Diabetes            = list("diabetes_m", c(Yes = "Yes", No = "No", Missing = "Missing")))

cat_rows <- list(); test_rows <- list()
for (pv in names(VARS)) {
  v <- VARS[[pv]][[1]]; map <- VARS[[pv]][[2]]
  f <- as.formula(paste0("~", v, " + htn_f"))

  n_tab <- table(dom$variables[[v]], dom$variables$htn_f)
  w_tab <- svytable(f, dom)
  pct   <- 100 * prop.table(w_tab, margin = 2)

  for (lv in names(map)) {
    has <- lv %in% rownames(n_tab)
    pp <- t1cat[t1cat$variable == pv & t1cat$level == map[[lv]], ]
    cat_rows[[length(cat_rows) + 1]] <- data.frame(
      variable = pv, level = map[[lv]],
      n_non = if (has) n_tab[lv, 1] else 0L, n_htn = if (has) n_tab[lv, 2] else 0L,
      pct_non = if (has) pct[lv, 1] else 0, pct_htn = if (has) pct[lv, 2] else 0,
      paper_n_non = if (nrow(pp)) pp$n_non else NA,
      paper_n_htn = if (nrow(pp)) pp$n_htn else NA,
      paper_pct_non = if (nrow(pp)) pp$pct_non else NA,
      paper_pct_htn = if (nrow(pp)) pp$pct_htn else NA)
  }

  paper_p <- t1p$p_text[t1p$variable == pv]
  nv <- suppressWarnings(chisq.test(w_tab, correct = FALSE))
  r1 <- svychisq(f, dom, statistic = "Chisq")
  r2 <- svychisq(f, dom, statistic = "F")
  uw <- suppressWarnings(chisq.test(n_tab, correct = FALSE))
  test_rows[[length(test_rows) + 1]] <- data.frame(
    variable = pv,
    method = c("naive_weighted", "rao_scott_1", "rao_scott_2", "unweighted"),
    statistic = c(nv$statistic, r1$statistic, r2$statistic, uw$statistic),
    df = c(nv$parameter, r1$parameter,
           paste(round(r2$parameter, 2), collapse = ", "), uw$parameter),
    p = c(nv$p.value, r1$p.value, r2$p.value, uw$p.value),
    paper_p = paper_p)
}
cats  <- do.call(rbind, cat_rows)
tests <- do.call(rbind, test_rows)

## --- continuous ------------------------------------------------------------
CONT <- c(Age = "age", "Total cholesterol" = "LBXTC", Triglyceride = "LBXSTR",
          Creatinine = "LBXSCR", HDL = "LBDHDD", HbA1c = "LBXGH",
          Sodium = "DR1TSODI", Fat = "DR1TTFAT")

cont_row <- function(pv, v, design, wlab) {
  m  <- svyby(as.formula(paste0("~", v)), ~htn_f, design, svymean, na.rm = TRUE)
  tt <- svyttest(as.formula(paste0(v, " ~ htn_f")), design)
  pp <- t1cont[t1cont$variable == pv, ]
  data.frame(variable = pv, weight = wlab,
             n_used = sum(!is.na(design$variables[[v]])),
             mean_non = m[1, 2], se_non = m[1, 3], mean_htn = m[2, 2], se_htn = m[2, 3],
             p = tt$p.value,
             paper_mean_non = pp$mean_non, paper_se_non = pp$se_non,
             paper_mean_htn = pp$mean_htn, paper_se_htn = pp$se_htn,
             paper_p = pp$p_text)
}
cont <- do.call(rbind, Map(cont_row, names(CONT), CONT,
                           MoreArgs = list(design = dom, wlab = "WTMEC2YR/5")))

## Triglyceride with the fasting-subsample weight (design on the full file)
full <- dd$des$variables
full$wt_saf10 <- ifelse(is.na(full$WTSAF2YR), 0, full$WTSAF2YR / 5)
des_saf <- svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt_saf10,
                     nest = TRUE, data = full)
dom_saf <- subset(des_saf, domain & wt_saf10 > 0 & !is.na(LBXTR))
cont <- rbind(cont,
              cont_row("Triglyceride", "LBXTR", dom, "WTMEC2YR/5 (fasting LBXTR)"),
              cont_row("Triglyceride", "LBXTR", dom_saf, "WTSAF2YR/5 (fasting LBXTR)"))
rownames(cont) <- NULL

write.csv(cats,  file.path(TAB_DIR, "20_table1_categorical.csv"), row.names = FALSE)
write.csv(tests, file.path(TAB_DIR, "20_table1_tests.csv"), row.names = FALSE)
write.csv(cont,  file.path(TAB_DIR, "20_table1_continuous.csv"), row.names = FALSE)

## --- console -----------------------------------------------------------------
options(width = 200)
cat("Group n:", table(dom$variables$htn_f), " (paper 10,783 / 11,017)\n\n")
print(within(cats, { pct_non <- round(pct_non, 2); pct_htn <- round(pct_htn, 2) }),
      row.names = FALSE)
cat("\n")
print(within(tests, { statistic <- signif(statistic, 4); p <- signif(p, 3) }),
      row.names = FALSE)
cat("\n")
print(within(cont, { mean_non <- round(mean_non, 2); se_non <- round(se_non, 2)
                     mean_htn <- round(mean_htn, 2); se_htn <- round(se_htn, 2)
                     p <- signif(p, 3) }), row.names = FALSE)
