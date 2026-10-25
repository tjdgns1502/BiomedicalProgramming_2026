## 34_stratum_or_decomposition.R ------------------------------------------
## Plan A12: in the paper's Table 2, the smoking stratum's oral-health OR
## goes 1.22 (unweighted crude, from its own counts) -> 2.33 (Model 1) ->
## 1.29 (Model 2), the opposite of the nonsmoking stratum. Here the step from
## crude to Model 1 is taken one covariate at a time in each smoking stratum:
##   unweighted crude   glm(binomial) on the stratum rows, no weights
##   weighted crude     svyglm, no covariates
##   + age, + sex, + race, + education   (the last step = Model 1)
## R/30 already showed the paper's Model 1 columns for oral health match our
## OPPOSITE stratum (ours nonsmoking Poor 2.36 vs paper smoking 2.33; ours
## smoking 1.45 vs paper nonsmoking 1.49). The decomposition shows what our
## data do at each step, and the swap test puts both orderings side by side.
##
## Outputs:
##   output/tables/34_or_decomposition.csv  stratum, step, level, or, lo, hi
##   output/tables/34_swap_test.csv         level, ours by stratum, paper by
##     stratum, |diff| same-stratum vs swapped
##
## Rscript R/34_stratum_or_decomposition.R
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
STEPS <- list("weighted crude" = character(0), "+ age" = "age",
              "+ sex" = c("age", "sex"), "+ race" = c("age", "sex", "race"),
              "+ education (= Model 1)" = c("age", "sex", "race", "edu_m"))
STRATA <- c(nonsmoking = "No", smoking = "Yes")

rows <- list()
for (st in names(STRATA)) {
  sd <- subset(dom, smoke == STRATA[[st]])
  ## unweighted crude: ordinary logistic regression on the stratum's rows
  v <- sd$variables[sd$prob < Inf & weights(sd) > 0, ]
  g <- glm(htn ~ oral4, family = binomial(), data = v)
  ci <- suppressMessages(confint.default(g))[-1, ]
  rows[[length(rows) + 1]] <- data.frame(stratum = st, step = "unweighted crude",
    level = levels(v$oral4)[-1], or = exp(coef(g)[-1]), lo = exp(ci[, 1]),
    hi = exp(ci[, 2]), n = nrow(v))
  for (s in names(STEPS)) {
    r <- if (length(STEPS[[s]])) fit_exposure(sd, "oral4", STEPS[[s]]) else {
      m <- svyglm(htn ~ oral4, design = sd, family = quasibinomial())
      ci <- confint(m)[-1, ]
      data.frame(level = levels(sd$variables$oral4)[-1], est = exp(coef(m)[-1]),
                 lo = exp(ci[, 1]), hi = exp(ci[, 2]), n_used = length(m$y))
    }
    rows[[length(rows) + 1]] <- data.frame(stratum = st, step = s, level = r$level,
      or = r$est, lo = r$lo, hi = r$hi, n = r$n_used)
  }
}
dec <- do.call(rbind, rows); rownames(dec) <- NULL
write.csv(dec, file.path(TAB_DIR, "34_or_decomposition.csv"), row.names = FALSE)

## swap test: Model 1 (ours) vs paper, same stratum and swapped stratum
m1 <- dec[dec$step == "+ education (= Model 1)", ]
p1 <- t23[t23$table == "Table 2" & t23$exposure == "oral" &
          t23$stratum %in% names(STRATA) & !is.na(t23$lo1), ]
sw <- do.call(rbind, lapply(levels(dom$variables$oral4)[-1], function(lv) {
  o <- setNames(m1$or[m1$level == lv], m1$stratum[m1$level == lv])
  p <- setNames(p1$or1[p1$level == lv], p1$stratum[p1$level == lv])
  data.frame(level = lv, ours_nonsmoking = o[["nonsmoking"]], ours_smoking = o[["smoking"]],
             paper_nonsmoking = p[["nonsmoking"]], paper_smoking = p[["smoking"]],
             absdiff_same = abs(o[["nonsmoking"]] - p[["nonsmoking"]]) +
                            abs(o[["smoking"]] - p[["smoking"]]),
             absdiff_swapped = abs(o[["nonsmoking"]] - p[["smoking"]]) +
                               abs(o[["smoking"]] - p[["nonsmoking"]]))
}))
write.csv(sw, file.path(TAB_DIR, "34_swap_test.csv"), row.names = FALSE)

options(width = 200)
print(within(dec, { or <- round(or, 2); lo <- round(lo, 2); hi <- round(hi, 2) }),
      row.names = FALSE)
cat("\nSwap test (Model 1, oral health; sum of |ours - paper| over the 2 strata):\n")
print(within(sw, { ours_nonsmoking <- round(ours_nonsmoking, 2)
                   ours_smoking <- round(ours_smoking, 2)
                   absdiff_same <- round(absdiff_same, 2)
                   absdiff_swapped <- round(absdiff_swapped, 2) }), row.names = FALSE)
