## 01_tables_from_paper.R -------------------------------------------------
## Contingency tables rebuilt from the paper's Tables 2/3 "Cases/total"
## (unweighted counts; R/00 confirmed they add up to Table 1). No NHANES.
##
## R table objects built with xtabs():
##   exposure x HTN                     (oral 4 x 2, perio 2 x 2), all
##   exposure x HTN x smoking           (Table 2 strata)
##   exposure x HTN x age group         (Table 3 strata)
## and their conditional distributions, enumerated with prop.table():
##   P(HTN | exposure)   margin = exposure  (row profile; what an RR compares)
##   P(exposure | HTN)   margin = HTN       (column profile; case-control view)
## For the 3-way tables, both are conditional on the stratum as well.
##
## Output:
##   output/tables/01_contingency_from_paper.csv  one row per cell:
##     exposure, strat_by, stratum, level, htn, n, p_htn_given_exp,
##     p_exp_given_htn
##   data/processed/paper_xtabs.rds   named list of the xtabs objects
##                                    (used by R/02 and the figures)
##
## Rscript R/01_tables_from_paper.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
source(file.path(PROJ, "R", "paper_tables.R"))

LEVELS <- list(oral  = c("Excellent/Very good", "Good", "Fair", "Poor"),
               perio = c("No", "Yes"))

## Cases/total -> long counts with an HTN column
long <- do.call(rbind, lapply(seq_len(nrow(t23)), function(i) {
  r <- t23[i, ]
  data.frame(table = r$table, exposure = r$exposure, stratum = r$stratum,
             level = r$level, htn = c("Yes", "No"),
             n = c(r$cases, r$total - r$cases))
}))
long$htn <- factor(long$htn, levels = c("Yes", "No"))

tabs <- list()
for (e in names(LEVELS)) {
  d <- long[long$exposure == e, ]
  d$level <- factor(d$level, levels = LEVELS[[e]])

  ## 2-way, all participants (Table 2 "all" rows)
  tabs[[paste0(e, "_all")]] <-
    xtabs(n ~ level + htn, data = d[d$table == "Table 2" & d$stratum == "all", ])

  ## 3-way: smoking (Table 2) and age (Table 3); stratum is the 3rd dimension
  s <- d[d$table == "Table 2" & d$stratum != "all", ]
  s$stratum <- factor(s$stratum, levels = c("nonsmoking", "smoking"))
  tabs[[paste0(e, "_by_smoking")]] <- xtabs(n ~ level + htn + stratum, data = s)

  a <- d[d$table == "Table 3", ]
  a$stratum <- factor(a$stratum, levels = c("age<45", "age>=45"))
  tabs[[paste0(e, "_by_age")]] <- xtabs(n ~ level + htn + stratum, data = a)
}

## Collapsing either 3-way table over its stratum must give the 2-way table
for (e in names(LEVELS)) for (s in c("smoking", "age")) {
  collapsed <- margin.table(tabs[[paste0(e, "_by_", s)]], c(1, 2))
  stopifnot(all(collapsed == tabs[[paste0(e, "_all")]]))
}

## Conditional distributions, one row per cell
cells <- function(tb, exposure, strat_by) {
  if (length(dim(tb)) == 2) {
    rp <- prop.table(tb, margin = 1)   # P(HTN | exposure)
    cp <- prop.table(tb, margin = 2)   # P(exposure | HTN)
    d <- as.data.frame(tb, responseName = "n")
    d$stratum <- "all"
  } else {
    rp <- prop.table(tb, margin = c(1, 3))
    cp <- prop.table(tb, margin = c(2, 3))
    d <- as.data.frame(tb, responseName = "n")
  }
  d$p_htn_given_exp <- as.vector(rp)
  d$p_exp_given_htn <- as.vector(cp)
  data.frame(exposure = exposure, strat_by = strat_by, stratum = d$stratum,
             level = d$level, htn = d$htn, n = d$n,
             p_htn_given_exp = d$p_htn_given_exp,
             p_exp_given_htn = d$p_exp_given_htn)
}

res <- do.call(rbind, c(
  lapply(names(LEVELS), function(e) cells(tabs[[paste0(e, "_all")]], e, "none")),
  lapply(names(LEVELS), function(e) cells(tabs[[paste0(e, "_by_smoking")]], e, "smoking")),
  lapply(names(LEVELS), function(e) cells(tabs[[paste0(e, "_by_age")]], e, "age"))))

write.csv(res, file.path(TAB_DIR, "01_contingency_from_paper.csv"), row.names = FALSE)
dir.create(file.path(PROJ, "data", "processed"), showWarnings = FALSE, recursive = TRUE)
saveRDS(tabs, file.path(PROJ, "data", "processed", "paper_xtabs.rds"))

## Console view: the tables with margins, and P(HTN | exposure)
for (nm in names(tabs)) {
  cat("\n==", nm, "==\n")
  tb <- tabs[[nm]]
  if (length(dim(tb)) == 2) {
    print(addmargins(tb))
    print(round(prop.table(tb, 1), 3))
  } else {
    print(ftable(addmargins(tb, c(1, 2)), row.vars = c(3, 1)))
    print(ftable(round(prop.table(tb, c(1, 3)), 3), row.vars = c(3, 1)))
  }
}
cat(sprintf("\n%d cells written to output/tables/01_contingency_from_paper.csv\n",
            nrow(res)))
