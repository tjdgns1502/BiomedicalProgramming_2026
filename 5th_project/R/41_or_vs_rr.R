## 41_or_vs_rr.R ----------------------------------------------------------
## Verification task 2: how much the OR overstates the RR when the outcome
## is common (hypertension prevalence ~50%), plus non-collapsibility.
##
## Part 1 - our data. For every contrast of Tables 2/3 (5 strata x
## oral Good/Fair/Poor + perio Yes x Models 1-3) with the same covariates:
##   OR   svyglm(quasibinomial)                        (as R/30)
##   RR   svyglm(quasipoisson(link = "log")): modified Poisson; the survey
##        sandwich variance is the robust variance the method needs
##   P0   weighted prevalence of HTN in the contrast's own reference group
##        within the stratum (plan revision item 10: one P0 per contrast)
##   RR_zy  Zhang-Yu conversion OR / (1 - P0 + P0 * OR); it treats an
##        adjusted (conditional) OR as if it were marginal, so it is biased
##        for adjusted models - compared with the directly estimated RR
##   ratios  OR / RR and (OR - 1) / (RR - 1): how much larger the OR
##        excess is than the RR excess
##   change  OR and RR change from Model 1 to Model 3
##
## Part 2 - non-collapsibility, exact (no sampling) and one large simulation.
##   X ~ Bern(0.5), Z ~ Bern(0.5) independent (Z is NOT a confounder).
##   Logistic DGM  logit P(Y) = a + b X + c Z, b = log 2: conditional OR = 2
##     in both Z strata; the marginal OR (Z ignored) is computed exactly by
##     averaging P(Y | X, Z) over Z. It moves toward 1 as |c| grows.
##   Log-linear DGM  log P(Y) = a + b X + c Z, b = log 1.5: conditional RR =
##     1.5 and the marginal RR is exactly 1.5 too (collapsible), while the
##     ORs differ.
##   Simulation (n = 200,000, seed below): glm crude vs Z-adjusted OR and
##     RR, to show the same with fitted models.
##
## Outputs:
##   output/tables/41_or_vs_rr.csv            part 1, one row per contrast x model
##   output/tables/41_noncollapsibility.csv   part 2, exact grid
##   output/tables/41_noncollapsibility_sim.csv  part 2, simulation
##   output/figures/41_or_rr_curve.png        OR/RR vs P0, theory + Model 3
##   output/figures/41_forest_or_rr.png       Model 3 OR and RR side by side
##   output/figures/41_noncollapsibility.png  marginal vs conditional effect
##
## Rscript R/41_or_vs_rr.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")
source(file.path(PROJ, "R", "model_utils.R"))

SEED <- 20261007L
## reference palette (dataviz skill references/palette.md), light mode
COL <- c(blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a", yellow = "#eda100")
INK <- c(primary = "#0b0b0b", secondary = "#52514e", muted = "#898781",
         grid = "#e1e0d9", axis = "#c3c2b7", surface = "#fcfcfb")
BLUE_RAMP <- c("#86b6ef", "#3987e5", "#1c5cab", "#0d366b")   # steps 250-700
theme_chart <- function() theme_minimal(base_size = 10) + theme(
  plot.background = element_rect(fill = INK[["surface"]], colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = INK[["grid"]], linewidth = 0.3),
  axis.line = element_line(colour = INK[["axis"]], linewidth = 0.3),
  axis.text = element_text(colour = INK[["muted"]]),
  axis.title = element_text(colour = INK[["secondary"]]),
  plot.title = element_text(colour = INK[["primary"]], face = "bold"),
  plot.subtitle = element_text(colour = INK[["secondary"]]),
  legend.text = element_text(colour = INK[["secondary"]]),
  strip.text = element_text(colour = INK[["primary"]]),
  legend.position = "top")

## --- Part 1: our data -----------------------------------------------------
dom <- load_domain(PROJ)
STRATA <- list(
  "Table 2" = list(all = quote(TRUE), nonsmoking = quote(smoke == "No"),
                   smoking = quote(smoke == "Yes")),
  "Table 3" = list("age<45" = quote(age_grp == "age<45"),
                   "age>=45" = quote(age_grp == "age>=45")))
EXPO <- c(oral = "oral4", perio = "perio")

rows <- list()
for (tb in names(STRATA)) for (st in names(STRATA[[tb]])) {
  sd <- eval(bquote(subset(dom, .(STRATA[[tb]][[st]]))))
  for (e in names(EXPO)) {
    ex <- EXPO[[e]]
    ref <- levels(sd$variables[[ex]])[1]
    p0 <- coef(svymean(~htn, eval(bquote(subset(sd, .(as.name(ex)) == .(ref))))))[[1]]
    for (m in names(COVS[[tb]])) {
      covs <- COVS[[tb]][[m]]
      o <- fit_exposure(sd, ex, covs)
      r <- fit_exposure(sd, ex, covs, family = quasipoisson(link = "log"),
                        control = list(maxit = 100))
      rows[[length(rows) + 1]] <- data.frame(
        table = tb, stratum = st, exposure = e, model = m, level = o$level,
        p0 = p0, or = o$est, or_lo = o$lo, or_hi = o$hi,
        rr = r$est, rr_lo = r$lo, rr_hi = r$hi,
        rr_zhang_yu = o$est / (1 - p0 + p0 * o$est))
    }
  }
}
res <- do.call(rbind, rows)
res$or_over_rr     <- res$or / res$rr
res$excess_ratio   <- (res$or - 1) / (res$rr - 1)
res$zy_minus_rr    <- res$rr_zhang_yu - res$rr
key <- with(res, paste(table, stratum, exposure, level))
m1 <- res[res$model == "1", ]; m3 <- res[res$model == "3", ]
res$or_change_m1_m3 <- NA_real_; res$rr_change_m1_m3 <- NA_real_
i3 <- res$model == "3"
res$or_change_m1_m3[i3] <- m3$or - m1$or[match(key[i3], key[res$model == "1"])]
res$rr_change_m1_m3[i3] <- m3$rr - m1$rr[match(key[i3], key[res$model == "1"])]
write.csv(res, file.path(TAB_DIR, "41_or_vs_rr.csv"), row.names = FALSE)

## --- Part 2: non-collapsibility -------------------------------------------
expit <- function(x) 1 / (1 + exp(-x))
grid <- expand.grid(a = c(-2, -1, 0), c = seq(0, 3, by = 0.25))
nc <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  a <- grid$a[i]; c <- grid$c[i]
  ## logistic DGM, conditional OR = 2
  b <- log(2)
  p1 <- mean(expit(a + b + c * 0:1)); p0 <- mean(expit(a + c * 0:1))
  or_marg <- (p1 / (1 - p1)) / (p0 / (1 - p0))
  ## log-linear DGM, conditional RR = 1.5 (a shifted so that P < 1 everywhere)
  bl <- log(1.5); al <- log(0.08) + a / 4
  q1 <- mean(exp(al + bl + (c / 3) * 0:1)); q0 <- mean(exp(al + (c / 3) * 0:1))
  data.frame(a = a, c = c, p0_marginal = p0,
             logistic_or_conditional = 2, logistic_or_marginal = or_marg,
             logistic_rr_marginal = p1 / p0,
             loglinear_rr_conditional = 1.5, loglinear_rr_marginal = q1 / q0,
             loglinear_or_marginal = (q1 / (1 - q1)) / (q0 / (1 - q0)))
}))
write.csv(nc, file.path(TAB_DIR, "41_noncollapsibility.csv"), row.names = FALSE)

set.seed(SEED)
n <- 200000L
x <- rbinom(n, 1, 0.5); z <- rbinom(n, 1, 0.5)
y_log <- rbinom(n, 1, expit(-1 + log(2) * x + 2 * z))            # logistic DGM
y_lin <- rbinom(n, 1, exp(log(0.08) + log(1.5) * x + 1 * z))     # log-linear DGM
fit_eff <- function(y, fam, adj) {
  f <- if (adj) y ~ x + z else y ~ x
  exp(coef(glm(f, family = fam))[["x"]])
}
sim <- data.frame(
  dgm = c("logistic (cond. OR = 2)", "logistic (cond. OR = 2)",
          "log-linear (cond. RR = 1.5)", "log-linear (cond. RR = 1.5)"),
  measure = c("OR", "RR", "OR", "RR"),
  crude = c(fit_eff(y_log, binomial(), FALSE), fit_eff(y_log, poisson(), FALSE),
            fit_eff(y_lin, binomial(), FALSE), fit_eff(y_lin, poisson(), FALSE)),
  z_adjusted = c(fit_eff(y_log, binomial(), TRUE), fit_eff(y_log, poisson(), TRUE),
                 fit_eff(y_lin, binomial(), TRUE), fit_eff(y_lin, poisson(), TRUE)),
  n = n, seed = SEED)
write.csv(sim, file.path(TAB_DIR, "41_noncollapsibility_sim.csv"), row.names = FALSE)

## --- figures ---------------------------------------------------------------
LV <- c(Good = "Oral: Good", Fair = "Oral: Fair", Poor = "Oral: Poor", Yes = "Periodontal: Yes")
m3 <- res[res$model == "3", ]
m3$contrast <- factor(LV[m3$level], levels = LV)
STR_LAB <- c(all = "All", nonsmoking = "Non-smoking", smoking = "Smoking",
             "age<45" = "Age < 45", "age>=45" = "Age ≥ 45")
m3$stratum_lab <- factor(STR_LAB[m3$stratum], levels = STR_LAB)

## (1) OR / RR against P0: marginal identity OR/RR = (1 - P0) / (1 - RR P0)
curve <- expand.grid(p0 = seq(0.01, 0.9, by = 0.005), RR = c(1.1, 1.25, 1.5, 2))
curve$ratio <- (1 - curve$p0) / (1 - curve$RR * curve$p0)
curve <- curve[curve$RR * curve$p0 < 0.97, ]
curve$RR_lab <- factor(paste0("RR = ", curve$RR), levels = paste0("RR = ", c(1.1, 1.25, 1.5, 2)))
g1 <- ggplot() +
  geom_hline(yintercept = 1, colour = INK[["axis"]], linewidth = 0.4) +
  geom_line(data = curve, aes(p0, ratio, colour = RR_lab), linewidth = 0.7) +
  scale_colour_manual(values = BLUE_RAMP, name = "Theory (marginal):") +
  geom_point(data = m3, aes(p0, or_over_rr, shape = contrast), size = 2.6,
             colour = INK[["primary"]], fill = COL[["orange"]], stroke = 0.4) +
  scale_shape_manual(values = c(21, 22, 24, 23), name = "Ours, Model 3:") +
  coord_cartesian(ylim = c(1, 2.2)) +   # zoom, do not drop curve points
  labs(x = expression("Baseline prevalence " * P[0] * " (reference group of each contrast)"),
       y = "OR / RR",
       title = "The OR overstates the RR more as the outcome gets common",
       subtitle = "Lines: OR/RR = (1 - P0) / (1 - RR·P0). Points: adjusted OR / adjusted RR, one per contrast and stratum.") +
  theme_chart() + theme(legend.box = "vertical")
ggsave(file.path(FIG_DIR, "41_or_rr_curve.png"), g1, width = 8, height = 5.5, dpi = 150)

## (2) forest: Model 3 OR and RR per contrast and stratum, log scale
fp <- rbind(data.frame(m3[, c("stratum_lab", "contrast")], measure = "OR",
                       est = m3$or, lo = m3$or_lo, hi = m3$or_hi),
            data.frame(m3[, c("stratum_lab", "contrast")], measure = "RR",
                       est = m3$rr, lo = m3$rr_lo, hi = m3$rr_hi))
fp$measure <- factor(fp$measure, levels = c("OR", "RR"))
g2 <- ggplot(fp, aes(est, contrast, colour = measure)) +
  geom_vline(xintercept = 1, colour = INK[["axis"]], linewidth = 0.4) +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.3, linewidth = 0.6,
                  position = position_dodge(width = 0.55)) +
  scale_colour_manual(values = c(OR = COL[["blue"]], RR = COL[["orange"]]), name = NULL,
                      labels = c(OR = "Odds ratio (logistic)", RR = "Risk ratio (modified Poisson)")) +
  scale_x_log10(breaks = c(0.8, 1, 1.25, 1.5, 2, 2.5)) +
  scale_y_discrete(limits = rev) +
  facet_wrap(~ stratum_lab, ncol = 1, strip.position = "left") +
  labs(x = "Adjusted effect, Model 3 (log scale)", y = NULL,
       title = "Same model, two effect scales",
       subtitle = "Model 3 covariates per table footnote; survey-weighted, 95% CI.") +
  theme_chart() + theme(strip.placement = "outside",
                        strip.text.y.left = element_text(angle = 0, hjust = 1))
ggsave(file.path(FIG_DIR, "41_forest_or_rr.png"), g2, width = 7.5, height = 8.5, dpi = 150)

## (3) non-collapsibility
nl <- rbind(
  data.frame(panel = "Logistic DGM: conditional OR = 2", c = nc$c, a = nc$a,
             value = nc$logistic_or_marginal, ref = 2),
  data.frame(panel = "Log-linear DGM: conditional RR = 1.5", c = nc$c, a = nc$a,
             value = nc$loglinear_rr_marginal, ref = 1.5))
nl$a_lab <- factor(paste0("intercept a = ", nl$a), levels = paste0("intercept a = ", c(-2, -1, 0)))
g3 <- ggplot(nl, aes(c, value, colour = a_lab)) +
  geom_hline(aes(yintercept = ref), colour = INK[["secondary"]], linetype = "dashed",
             linewidth = 0.4) +
  geom_line(linewidth = 0.7) + geom_point(size = 1.4) +
  scale_colour_manual(values = unname(COL[c("blue", "orange", "aqua")]), name = NULL) +
  facet_wrap(~ panel, scales = "free_y") +
  labs(x = "Effect of Z on the outcome (c); Z independent of X, so not a confounder",
       y = "Marginal effect (Z ignored)",
       title = "Ignoring a non-confounder moves the OR, not the RR",
       subtitle = paste("Dashed: the conditional effect within each Z stratum. Exact values, no sampling.",
                        "Left: the three intercepts coincide at exactly 1.5.", sep = "\n")) +
  theme_chart()
ggsave(file.path(FIG_DIR, "41_noncollapsibility.png"), g3, width = 9, height = 4.5, dpi = 150)

## --- console ---------------------------------------------------------------
options(width = 200)
show <- res[res$model == "3", c("table", "stratum", "exposure", "level", "p0", "or",
                                 "rr", "rr_zhang_yu", "or_over_rr", "excess_ratio",
                                 "or_change_m1_m3", "rr_change_m1_m3")]
num <- vapply(show, is.numeric, TRUE)
show[num] <- lapply(show[num], round, 3)
print(show, row.names = FALSE)
cat(sprintf("\nModel 3: OR/RR median %.3f (range %.3f-%.3f); excess ratio median %.2f\n",
            median(m3$or_over_rr), min(m3$or_over_rr), max(m3$or_over_rr),
            median(m3$excess_ratio)))
cat("\nNon-collapsibility, exact (c = 0, 1, 2, 3; a = -1):\n")
print(round(nc[nc$a == -1 & nc$c %in% 0:3, -1], 3), row.names = FALSE)
cat("\nSimulation:\n"); print(within(sim, { crude <- round(crude, 3)
                                             z_adjusted <- round(z_adjusted, 3) }),
                              row.names = FALSE)
