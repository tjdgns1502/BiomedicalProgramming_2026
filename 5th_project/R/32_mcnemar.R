## 32_mcnemar.R -----------------------------------------------------------
## McNemar test: two hypertension definitions applied to the SAME people,
## so the 2 x 2 table is paired (not two independent samples):
##                    diagnosed yes   diagnosed no
##   measured yes          a               b    <- b: high BP, never told
##   measured no           c               d    <- c: told/treated, BP now
##                                                  below 140/90 (controlled)
## H0: P(measured) = P(diagnosed) (marginal homogeneity). Only the
## discordant cells b and c carry information.
##   mcnemar         (b - c)^2 / (b + c), chi-square 1 df
##   mcnemar_yates   (|b - c| - 1)^2 / (b + c)
##   exact           binom.test(b, b + c, 0.5): exact conditional test
##   survey_paired   design-based analogue: d = measured - diagnosed per
##                   person (-1, 0, 1); svymean(d) = weighted P(measured) -
##                   P(diagnosed), Wald test with design df. (Unweighted
##                   mean(d) = (b - c) / n, so this is McNemar with weights.)
## Overall and within oral-health groups (domain n = 21,399; rows with either
## component NA are dropped).
## Not done: self-reported vs clinical periodontitis (OHXPER, 2009-2014),
## listed as optional in the plan.
##
## Output: output/tables/32_mcnemar.csv
##   group, a, b, c, d, method, statistic, estimate, lo, hi, p
##
## Rscript R/32_mcnemar.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
source(file.path(PROJ, "R", "model_utils.R"))

dom <- load_domain(PROJ)
dom <- update(dom, d_pair = as.numeric(htn_measured) - as.numeric(htn_diagnosed))
dom <- subset(dom, !is.na(htn_measured) & !is.na(htn_diagnosed))

one_group <- function(sd, label) {
  v <- sd$variables
  tb <- table(measured = factor(v$htn_measured, c(TRUE, FALSE)),
              diagnosed = factor(v$htn_diagnosed, c(TRUE, FALSE)))
  a <- tb[1, 1]; b <- tb[1, 2]; c <- tb[2, 1]; d <- tb[2, 2]
  m0 <- mcnemar.test(tb, correct = FALSE); m1 <- mcnemar.test(tb, correct = TRUE)
  ex <- binom.test(b, b + c, 0.5)
  sm <- svymean(~d_pair, sd); ci <- confint(sm, df = degf(sd))
  tt <- coef(sm) / SE(sm)
  base <- data.frame(group = label, a = a, b = b, c = c, d = d)
  rbind(
    cbind(base, method = "mcnemar", statistic = m0$statistic,
          estimate = (b - c) / sum(tb), lo = NA, hi = NA, p = m0$p.value),
    cbind(base, method = "mcnemar_yates", statistic = m1$statistic,
          estimate = (b - c) / sum(tb), lo = NA, hi = NA, p = m1$p.value),
    cbind(base, method = "exact_binomial", statistic = b,
          estimate = ex$estimate, lo = ex$conf.int[1], hi = ex$conf.int[2],
          p = ex$p.value),
    cbind(base, method = "survey_paired", statistic = tt[[1]], estimate = coef(sm)[[1]],
          lo = ci[1], hi = ci[2], p = 2 * pt(-abs(tt[[1]]), degf(sd))))
}

res <- one_group(dom, "all")
for (lv in levels(dom$variables$oral4))
  res <- rbind(res, one_group(eval(bquote(subset(dom, oral4 == .(lv)))),
                              paste("oral:", lv)))
rownames(res) <- NULL
write.csv(res, file.path(PROJ, "output", "tables", "32_mcnemar.csv"), row.names = FALSE)

options(width = 200)
print(within(res, { statistic <- round(statistic, 2); estimate <- round(estimate, 4)
                    lo <- round(lo, 4); hi <- round(hi, 4); p <- signif(p, 3) }),
      row.names = FALSE)
