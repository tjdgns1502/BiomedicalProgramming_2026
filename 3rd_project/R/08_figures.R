## 08_figures.R -----------------------------------------------------------
## All figures, from the cached .rds files. Nothing is recomputed that an
## earlier stage already computed, except the small resampling exercises
## that only exist to be drawn.
##
## Axis labels are in English on purpose: Korean glyphs in ggplot2 devices
## need a platform-specific font family and would make the figures
## non-reproducible on another machine. The report's captions are Korean.
##
## Standalone:  Rscript R/08_figures.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

suppressPackageStartupMessages({
  library(ggplot2); library(scales); library(boot)
})

need <- function(f) {
  p <- file.path(RES_DIR, f)
  if (!file.exists(p)) stop("missing ", f, " -- run the earlier stage first.")
  readRDS(p)
}
d02 <- need("02_distributions.rds")
d03 <- need("03_hetero_normal.rds")
d04 <- need("04_main_grid.rds")
d05 <- need("05_counterexamples.rds")
d07 <- need("07_nhanes.rds")

## ---- house style ---------------------------------------------------
theme_set(
  theme_bw(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      panel.border     = element_rect(colour = "grey70", fill = NA),
      strip.background = element_rect(fill = "grey93", colour = "grey70"),
      strip.text       = element_text(face = "bold", size = 9),
      plot.title       = element_text(face = "bold", size = 12),
      plot.subtitle    = element_text(size = 9, colour = "grey30"),
      plot.caption     = element_text(size = 8, colour = "grey30", hjust = 0),
      legend.position  = "right"
    )
)
## names must match the factor levels used on the colour aesthetic
PAL <- c(`Welch t` = "#1B6CA8", `Student t` = "#E08214",
         `WMW (rank-sum)` = "#B2182B")
sv <- function(name, plot, w, h) {
  f <- file.path(FIG_DIR, name)
  ggsave(f, plot, width = w, height = h, dpi = 200, bg = "white")
  cat("  wrote ", name, " (", w, "x", h, " in)\n", sep = "")
}
cat("\n== figures ==\n")

## ========================================================================
## FIGURE 1 -- group-wise Q-Q plots
## ========================================================================
qq_df <- function(v, grp, panel) {
  v <- v[is.finite(v)]
  n <- length(v)
  data.frame(theoretical = qnorm(ppoints(n)), sample = sort(v),
             group = grp, panel = panel)
}
X3 <- base_lnorm(3)
Y3 <- fit_shifted_lnorm(X3$mean, X3$median, 1.10 * X3$sd)
set.seed(SEED + 800L)
sim_x <- rspec(X3, 1000); sim_y <- rspec(Y3, 1000)

tg <- d07$full$LBXTR; hd <- d07$full$LBDHDD
set.seed(SEED + 801L)
q1 <- rbind(
  qq_df(sim_x, "X  (SD 1.056, skew 3.00)", "Simulated: shifted-lognormal pair, n = 1000"),
  qq_df(sim_y, "Y  (SD 1.162, skew 2.28)", "Simulated: shifted-lognormal pair, n = 1000"),
  qq_df(tg$x[sample.int(length(tg$x), 1500)], "Male",   "NHANES: triglycerides (mg/dL), n = 1500 each"),
  qq_df(tg$y[sample.int(length(tg$y), 1500)], "Female", "NHANES: triglycerides (mg/dL), n = 1500 each"),
  qq_df(hd$x[sample.int(length(hd$x), 1500)], "Male",   "NHANES: HDL cholesterol (mg/dL), n = 1500 each"),
  qq_df(hd$y[sample.int(length(hd$y), 1500)], "Female", "NHANES: HDL cholesterol (mg/dL), n = 1500 each")
)
q1$panel <- factor(q1$panel, levels = unique(q1$panel))

p1 <- ggplot(q1, aes(theoretical, sample)) +
  geom_abline(data = do.call(rbind, lapply(split(q1, list(q1$panel, q1$group), drop = TRUE),
    function(g) {
      qs <- quantile(g$sample, c(0.25, 0.75)); tq <- qnorm(c(0.25, 0.75))
      sl <- diff(qs) / diff(tq)
      data.frame(panel = g$panel[1], group = g$group[1],
                 slope = sl, intercept = qs[1] - sl * tq[1])
    })),
    aes(slope = slope, intercept = intercept),
    colour = "grey45", linetype = "dashed", linewidth = 0.4) +
  geom_point(aes(colour = group), size = 0.5, alpha = 0.55, show.legend = FALSE) +
  facet_grid(group ~ panel, scales = "free_y", switch = "y") +
  scale_colour_manual(values = c("#1B6CA8", "#B2182B", "#1B6CA8", "#B2182B",
                                 "#1B6CA8", "#B2182B")) +
  labs(title = "Group-wise normal Q-Q plots",
       subtitle = "Each group plotted separately: a difference in SD shows up as a difference in SLOPE, skewness as upward curvature at the right",
       x = "Theoretical quantile (standard normal)",
       y = "Sample quantile (data units)",
       caption = paste0(
         "Dashed line passes through the first and third sample quartiles. ",
         "Right-skewed data bend upward at the right-hand end.\n",
         "Normality is judged from these plots only -- never from a ",
         "significance test, which in large samples rejects harmless departures."))
sv("fig1_qq_groupwise.png", p1, 13, 6)

## ========================================================================
## FIGURE 2 -- resampling distributions + the CLT panel
## ========================================================================
set.seed(SEED + 802L)
nsub <- 300L
gx <- tg$x[sample.int(length(tg$x), nsub)]
gy <- tg$y[sample.int(length(tg$y), nsub)]
obs_diff <- mean(gx) - mean(gy)

BPERM <- 4000L
zall <- c(gx, gy); Nz <- length(zall)
perm_diff <- vapply(seq_len(BPERM), function(i) {
  idx <- sample.int(Nz)
  mean(zall[idx[seq_len(nsub)]]) - mean(zall[idx[(nsub + 1L):Nz]])
}, numeric(1))
p_perm <- (1 + sum(abs(perm_diff) >= abs(obs_diff) - 1e-12)) / (BPERM + 1)

BBOOT <- 4000L
boot_diff <- vapply(seq_len(BBOOT), function(i) {
  mean(gx[sample.int(nsub, nsub, TRUE)]) - mean(gy[sample.int(nsub, nsub, TRUE)])
}, numeric(1))

res_df <- rbind(
  data.frame(value = perm_diff,
             panel = "Permutation null distribution\n(labels shuffled; H0: exchangeable)"),
  data.frame(value = boot_diff,
             panel = "Bootstrap distribution of the mean difference\n(resampled within groups)")
)
res_df$panel <- factor(res_df$panel, levels = unique(res_df$panel))
vl <- data.frame(panel = levels(res_df$panel), x = obs_diff)

p2a <- ggplot(res_df, aes(value)) +
  geom_histogram(bins = 60, fill = "grey78", colour = "white", linewidth = 0.15) +
  geom_vline(data = vl, aes(xintercept = x), colour = "#B2182B", linewidth = 0.8) +
  facet_wrap(~panel, scales = "free") +
  labs(title = "What a p-value is, geometrically",
       subtitle = sprintf(
         "NHANES triglycerides, n = %d per group. Observed mean difference (M - F) = %.2f mg/dL; permutation p = %.4f",
         nsub, obs_diff, p_perm),
       x = "Mean difference, Male - Female (mg/dL)", y = "Frequency",
       caption = paste0(
         "Red line = observed statistic. LEFT: the p-value is the tail area of the permutation null beyond it.\n",
         "RIGHT: the bootstrap distribution is centred at the observed value and gives the uncertainty of the estimate; the two answer different questions."))

## CLT panel: the mean difference becomes bell-shaped even though the raw
## data never do
set.seed(SEED + 803L)
clt_ns <- c(5, 10, 30, 100, 1000)
clt <- do.call(rbind, lapply(clt_ns, function(n) {
  v <- vapply(seq_len(4000L), function(i) {
    x <- rspec(X3, n); y <- rspec(Y3, n)
    (mean(x) - mean(y)) / sqrt(var(x) / n + var(y) / n)
  }, numeric(1))
  data.frame(z = v, n = factor(sprintf("n = %d per group", n),
                               levels = sprintf("n = %d per group", clt_ns)))
}))
raw <- data.frame(z = (rspec(X3, 4000) - X3$mean) / X3$sd,
                  n = factor("raw data (for contrast)"))
clt$n <- factor(as.character(clt$n),
                levels = c("raw data (for contrast)", levels(clt$n)))
raw$n <- factor("raw data (for contrast)", levels = levels(clt$n))
clt2 <- rbind(raw, clt)

p2b <- ggplot(clt2, aes(z)) +
  geom_histogram(aes(y = after_stat(density)), bins = 60,
                 fill = "grey78", colour = "white", linewidth = 0.15) +
  stat_function(fun = dnorm, colour = "#1B6CA8", linewidth = 0.7) +
  facet_wrap(~n, nrow = 1) +
  coord_cartesian(xlim = c(-4, 6)) +
  labs(title = "Why the t-test survives skewness: the central limit theorem at work",
       subtitle = "Shifted-lognormal pair with skewness 3.00 / 2.28. Leftmost panel is the RAW data, standardised; the rest are the studentized mean difference",
       x = "Standardised value", y = "Density",
       caption = paste0(
         "Blue curve = standard normal. The raw data are strongly right-skewed at every sample size, ",
         "but the mean DIFFERENCE is already close to normal by n = 30\n",
         "and indistinguishable from it by n = 100. This is why Welch's rejection rate sits at 5% in the main grid even for heavily skewed data."))

sv("fig2a_resampling.png", p2a, 11, 4.6)
sv("fig2b_clt.png", p2b, 14, 3.8)

## ========================================================================
## FIGURE 3 -- confidence interval comparison
## ========================================================================
tw <- t.test(gx, gy); ts <- t.test(gx, gy, var.equal = TRUE)
bt <- boot(data.frame(v = c(gx, gy), g = rep(1:2, c(nsub, nsub))),
           statistic = function(dd, i) {
             s <- dd[i, ]; mean(s$v[s$g == 1]) - mean(s$v[s$g == 2])
           },
           R = 4000, strata = rep(1:2, c(nsub, nsub)))
bci <- boot.ci(bt, type = c("perc", "bca"))

## permutation interval by inverting the studentized permutation test
perm_p_shift <- function(delta, Bp = 1200L) {
  x <- gx - delta
  n1 <- length(x); n2 <- length(gy); N <- n1 + n2
  z <- c(x, gy)
  obs <- (mean(x) - mean(gy)) / sqrt(var(x) / n1 + var(gy) / n2)
  M <- matrix(z[as.vector(replicate(Bp, sample.int(N)))], nrow = N)
  xs <- M[seq_len(n1), , drop = FALSE]; ys <- M[(n1 + 1L):N, , drop = FALSE]
  mx <- colMeans(xs); my <- colMeans(ys)
  vx <- (colSums(xs^2) - n1 * mx^2) / (n1 - 1)
  vy <- (colSums(ys^2) - n2 * my^2) / (n2 - 1)
  st <- (mx - my) / sqrt(vx / n1 + vy / n2)
  (1 + sum(abs(st) >= abs(obs) - 1e-12)) / (Bp + 1)
}
set.seed(SEED + 804L)
f_lo <- function(dd) perm_p_shift(dd) - 0.05
perm_lo <- uniroot(f_lo, c(obs_diff - 4 * (tw$conf.int[2] - obs_diff), obs_diff),
                   tol = 0.05)$root
perm_hi <- uniroot(f_lo, c(obs_diff, obs_diff + 4 * (tw$conf.int[2] - obs_diff)),
                   tol = 0.05)$root

hl <- suppressWarnings(wilcox.test(gx, gy, conf.int = TRUE,
                                   exact = FALSE, correct = FALSE))

ci_main <- data.frame(
  method = c("Student t (pooled)", "Welch t", "Bootstrap (percentile)",
             "Bootstrap (BCa)", "Permutation (studentized, inverted)"),
  est = obs_diff,
  lo = c(ts$conf.int[1], tw$conf.int[1], bci$percent[4], bci$bca[4], perm_lo),
  hi = c(ts$conf.int[2], tw$conf.int[2], bci$percent[5], bci$bca[5], perm_hi)
)
ci_main$method <- factor(ci_main$method, levels = rev(ci_main$method))
ci_main$width <- ci_main$hi - ci_main$lo

p3a <- ggplot(ci_main, aes(y = method)) +
  geom_vline(xintercept = 0, colour = "grey45", linetype = "dashed") +
  geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0.18,
                 colour = "#1B6CA8", linewidth = 0.7) +
  geom_point(aes(x = est), size = 2.3, colour = "#1B6CA8") +
  geom_text(aes(x = hi, label = sprintf("width %.2f", width)),
            hjust = -0.15, size = 3, colour = "grey30") +
  scale_x_continuous(expand = expansion(mult = c(0.06, 0.22))) +
  labs(title = "Five 95% intervals for the SAME estimand: the difference in MEANS",
       subtitle = sprintf("NHANES triglycerides, n = %d per group. These are comparable to each other; compare their WIDTH, not their centre", nsub),
       x = "Difference in means, Male - Female (mg/dL)", y = NULL,
       caption = "Dashed line at 0. All five target the same quantity, so stacking them is legitimate.")

ci_hl <- data.frame(method = "Hodges-Lehmann (from wilcox.test)",
                    est = unname(hl$estimate),
                    lo = hl$conf.int[1], hi = hl$conf.int[2])
p3b <- ggplot(ci_hl, aes(y = method)) +
  geom_vline(xintercept = 0, colour = "grey45", linetype = "dashed") +
  geom_errorbar(aes(xmin = lo, xmax = hi), orientation = "y", width = 0.12,
                 colour = "#B2182B", linewidth = 0.7) +
  geom_point(aes(x = est), size = 2.3, colour = "#B2182B") +
  scale_x_continuous(expand = expansion(mult = c(0.06, 0.22))) +
  labs(title = "SEPARATE PANEL -- a different estimand, deliberately not stacked with the above",
       subtitle = "The WMW interval estimates the median of all pairwise differences (Hodges-Lehmann), not the difference in means",
       x = "Median of all pairwise differences, Male - Female (mg/dL)", y = NULL,
       caption = paste0(
         sprintf("Welch's mean-difference estimate is %.2f; the Hodges-Lehmann estimate is %.2f. They are not the same number and need not agree.\n",
                 obs_diff, unname(hl$estimate)),
         "This is the paper's point about interval estimation: the t-test's test and its interval share one standard error, whereas the WMW test\n",
         "cannot answer 'by how much?' in the units the question was asked in."))

sv("fig3a_ci_means.png", p3a, 10, 3.4)
sv("fig3b_ci_hodges_lehmann.png", p3b, 10, 2.9)

## ========================================================================
## FIGURE 4 -- Type I error heat map
## ========================================================================
r4 <- d04$results
r4$test <- NA_character_
long4 <- do.call(rbind, lapply(c("welch", "student", "wmw"), function(tt) {
  z <- r4[, c("family", "skew", "sd_ratio", "n")]
  z$rate <- r4[[tt]]
  z$test <- switch(tt, welch = "Welch t", student = "Student t",
                   wmw = "WMW (rank-sum)")
  z
}))
long4$test <- factor(long4$test, levels = c("Student t", "Welch t", "WMW (rank-sum)"))
long4$n_lab <- factor(sprintf("n = %d", long4$n),
                      levels = sprintf("n = %d", d04$ns))
se_pp <- 100 * mc_se(0.05, d04$B)

for (fam in c("gamma", "lognormal")) {
  dd <- long4[long4$family == fam, ]
  p4 <- ggplot(dd, aes(factor(skew), factor(sd_ratio), fill = rate)) +
    geom_tile(colour = "white", linewidth = 0.25) +
    geom_text(aes(label = sprintf("%.0f", 100 * rate)), size = 2.1,
              colour = ifelse(dd$rate > 0.55 | dd$rate < 0.02, "white", "grey15")) +
    facet_grid(test ~ n_lab) +
    scale_fill_gradient2(
      low = "#2166AC", mid = "#F7F7F7", high = "#B2182B",
      midpoint = 0.05, limits = c(0, 1),
      breaks = c(0.05, 0.25, 0.5, 0.75, 1),
      labels = c("5% (nominal)", "25%", "50%", "75%", "100%"),
      guide = guide_colourbar(barheight = grid::unit(70, "mm")),
      name = "Rejection\nrate") +
    labs(
      title = sprintf("Type I error rate, %s distributions (equal means AND equal medians by construction)", fam),
      subtitle = "Every rejection shown is a Type I error for the hypothesis of equal means; the nominal level is 5%, so white = correct",
      x = "Skewness of the base distribution X",
      y = "SD ratio  (SD of Y / SD of X)",
      caption = paste0(
        sprintf("B = %s replicates per cell; Monte Carlo SE at 5%% is %.2f percentage points, so 4.8%% and 5.2%% are the same number.\n",
                format(d04$B, big.mark = ","), se_pp),
        "Colour scale is diverging with its neutral point fixed at the nominal 5%. Cell labels are rejection rates in per cent.\n",
        sprintf("Construction: equal mean, equal median, SD ratio exact; skewness of Y is left free (4 constraints cannot be met by 3 parameters).%s",
                if (fam == "gamma") "\nNOTE the skewness-4 column: the shifted-gamma family turns over at skewness 3.75, so there Y is MORE skewed than X, not less." else "")))
  sv(sprintf("fig4_type1_heatmap_%s.png", fam), p4, 15, 7.5)
}

## ========================================================================
## FIGURE 5 -- rejection rate vs n (the paper's Figure 3)
## ========================================================================
fig5 <- long4[long4$skew == 3 & long4$sd_ratio == 1.10 &
                long4$test != "Student t", ]
fig5$family_lab <- ifelse(fig5$family == "gamma",
                          "Gamma pair (skewness 3.00 / 2.70)",
                          "Lognormal pair (skewness 3.00 / 2.28)")
paper_pts <- data.frame(
  family_lab = c("Gamma pair (skewness 3.00 / 2.70)",
                 "Lognormal pair (skewness 3.00 / 2.28)"),
  n = 1000, rate = c(0.99, 0.28), test = "WMW (rank-sum)")

p5 <- ggplot(fig5, aes(n, 100 * rate, colour = test)) +
  geom_hline(yintercept = 5, colour = "grey45", linetype = "dashed") +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.9) +
  geom_point(data = paper_pts, aes(n, 100 * rate), shape = 4, size = 3.2,
             stroke = 1.1, colour = "black", inherit.aes = FALSE) +
  geom_text(data = paper_pts, aes(n, 100 * rate, label = "Fagerland's published value"),
            hjust = 1.08, vjust = 1.9, size = 2.9, colour = "black",
            inherit.aes = FALSE) +
  facet_wrap(~family_lab) +
  scale_x_continuous(breaks = d04$ns, trans = "sqrt") +
  scale_y_continuous(limits = c(0, 108), breaks = seq(0, 100, 20)) +
  scale_colour_manual(values = PAL, name = NULL) +
  labs(title = "Rejection rate against sample size, SD ratio 1.10, base skewness 3",
       subtitle = "The null hypotheses of equal means and of equal medians are BOTH exactly true; only the SDs differ, by 10%",
       x = "Number of observations in each group (square-root scale)",
       y = "Rejection rate at alpha = 0.05 (%)",
       caption = paste0(
         sprintf("B = %s per point; Monte Carlo SE at 5%% is %.2f pp. Dashed line = nominal 5%%.\n",
                 format(d04$B, big.mark = ","), se_pp),
         "Welch stays flat at 5% at every sample size. WMW climbs, because its own null hypothesis P(X<Y) = 0.5 is false here -- that rise is POWER, not error."))
sv("fig5_rejection_vs_n.png", p5, 11, 4.4)

## ========================================================================
## FIGURE 6 -- heteroscedastic normal baseline (supporting)
## ========================================================================
r3 <- d03$results
long3 <- do.call(rbind, lapply(c("student", "welch", "wmw"), function(tt) {
  z <- r3[, c("split", "sd_ratio")]; z$rate <- r3[[tt]]
  z$test <- switch(tt, student = "Student t", welch = "Welch t",
                   wmw = "WMW (rank-sum)")
  z
}))
long3$test <- factor(long3$test, levels = c("Student t", "Welch t", "WMW (rank-sum)"))
long3$split <- factor(long3$split,
                      levels = sapply(d03$splits, function(s) sprintf("%d:%d", s[1], s[2])))
p6 <- ggplot(long3, aes(factor(sd_ratio), split, fill = rate)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(aes(label = sprintf("%.1f", 100 * rate)), size = 2.9,
            colour = ifelse(long3$rate > 0.2 | long3$rate < 0.01, "white", "grey15")) +
  facet_wrap(~test) +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B",
                       midpoint = 0.05, limits = c(0, 0.32),
                       breaks = c(0, 0.05, 0.15, 0.3),
                       labels = c("0%", "5%", "15%", "30%"),
                       name = "Rejection\nrate") +
  labs(title = "Normality perfect, only homoscedasticity broken",
       subtitle = "Equal means, normal data, total N fixed at 50. This isolates the Student-vs-Welch difference from any effect of skewness",
       x = "SD ratio  (SD of group 1 / SD of group 2)",
       y = "Group sizes  n1 : n2",
       caption = paste0(
         sprintf("B = %s per cell; Monte Carlo SE at 5%% is %.2f pp. Cell labels are rejection rates in per cent.\n",
                 format(d03$B, big.mark = ","), 100 * mc_se(0.05, d03$B)),
         "Student's t inflates when the SMALLER group has the larger SD and goes conservative when the LARGER group does -- note the diagonal symmetry.\n",
         "Welch is flat everywhere. WMW is affected too, which is the point often missed: a rank test is not automatically safe under unequal variances."))
sv("fig6_hetero_normal.png", p6, 12, 4.2)

## ========================================================================
## FIGURE 7 -- NHANES subsampling
## ========================================================================
s7 <- d07$subsample
s7$lab <- ifelse(s7$variable == "LBXTR",
                 "Triglycerides (skewness 7.1 / 19.8)",
                 "HDL cholesterol (skewness 1.4 / 1.1)")
l7 <- rbind(
  data.frame(lab = s7$lab, n = s7$n, p = s7$median_p_welch, test = "Welch t"),
  data.frame(lab = s7$lab, n = s7$n, p = s7$median_p_wmw, test = "WMW (rank-sum)"))
p7 <- ggplot(l7, aes(n, p, colour = test)) +
  geom_hline(yintercept = 0.05, colour = "grey45", linetype = "dashed") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.9) +
  facet_wrap(~lab, scales = "free_y") +
  scale_x_continuous(trans = "log10", breaks = unique(s7$n)) +
  scale_y_continuous(trans = "log10", labels = label_scientific(digits = 2)) +
  scale_colour_manual(values = PAL, name = NULL) +
  labs(title = "NHANES: how the Welch and WMW p-values separate as the subsample grows",
       subtitle = sprintf("Median p-value over %s subsamples of n per group drawn without replacement from the observed data, by sex",
                          format(d07$nrep, big.mark = ",")),
       x = "Subsample size per group (log scale)",
       y = "Median p-value (log scale)",
       caption = paste0(
         "Dashed line at 0.05. Unlike the simulation, the null is FALSE here -- the sexes really do differ -- so these are power curves, not Type I error curves.\n",
         "The two variables disagree: for HDL the WMW p-value falls far faster than Welch's, while for triglycerides Welch is ahead until about n = 2500.\n",
         "Which test yields the smaller p-value depends on the shape of the actual alternative, not on skewness alone."))
sv("fig7_nhanes_subsample.png", p7, 11, 4.4)

## ========================================================================
## FIGURE 8 -- Satterthwaite df sampling distribution
## ========================================================================
d01 <- need("01_satterthwaite.rds")
p8 <- ggplot(data.frame(nu = d01$nu_draws), aes(nu)) +
  geom_histogram(bins = 70, fill = "grey78", colour = "white", linewidth = 0.15) +
  geom_vline(xintercept = d01$nu_summary[["lower_bound"]],
             colour = "#B2182B", linetype = "dotted", linewidth = 0.7) +
  geom_vline(xintercept = d01$nu_summary[["upper_bound"]],
             colour = "#B2182B", linetype = "dotted", linewidth = 0.7) +
  geom_vline(xintercept = d01$nu_summary[["nu_at_truth"]],
             colour = "#1B6CA8", linewidth = 0.8) +
  annotate("text", x = d01$nu_summary[["lower_bound"]], y = Inf,
           label = "min(n1,n2)-1 = 14", hjust = -0.05, vjust = 1.6,
           size = 3, colour = "#B2182B") +
  annotate("text", x = d01$nu_summary[["upper_bound"]], y = Inf,
           label = "n1+n2-2 = 38", hjust = 1.05, vjust = 1.6,
           size = 3, colour = "#B2182B") +
  labs(title = "Satterthwaite's degrees of freedom is a random variable",
       subtitle = sprintf("One fixed design (n1 = %d with SD %g, n2 = %d with SD %g), %s independent samples",
                          d01$design$n1, d01$design$sd1, d01$design$n2,
                          d01$design$sd2, format(length(d01$nu_draws), big.mark = ",")),
       x = "Satterthwaite degrees of freedom, nu", y = "Frequency",
       caption = paste0(
         sprintf("Blue line = nu evaluated at the POPULATION variances (%.2f). Dotted red lines = the theoretical bounds, both attainable.\n",
                 d01$nu_summary[["nu_at_truth"]]),
         sprintf("Observed range %.2f to %.2f; %.0f%% of draws are non-integer. nu depends on the SAMPLE variances, so it changes from sample to sample.",
                 d01$nu_summary[["min"]], d01$nu_summary[["max"]],
                 100 * d01$frac_noninteger)))
sv("fig8_satterthwaite_df.png", p8, 9, 4)

saveRDS(list(nsub = nsub, obs_diff = obs_diff, p_perm = p_perm,
             ci_main = ci_main, ci_hl = ci_hl,
             perm_ci = c(perm_lo, perm_hi)),
        file.path(RES_DIR, "08_figures.rds"))
cat("\nall figures written to figs/\n")
