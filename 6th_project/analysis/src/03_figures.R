# F1-F7. 그림 안의 글자는 Windows PNG 장치의 한글 글꼴 문제를 피하려고 영어로 둔다.
library(ggplot2)

DEVICE_COLS <- c("Apple Watch" = "#0072B2", "Fitbit Charge HR" = "#E69F00",
                 "Samsung Gear S" = "#009E73", "Mio Alpha" = "#CC79A7")

theme_hr <- function() {
  theme_bw(base_size = 11) +
    theme(legend.position = "none", strip.text = element_text(face = "bold"),
          plot.title = element_text(face = "bold"),
          plot.caption = element_text(hjust = 0, colour = "grey30"))
}

save_fig <- function(p, path, w = 8, h = 7) {
  ggsave(path, p, width = w, height = h, dpi = 150, bg = "white")
  path
}

fig_scatter <- function(pairs, bands, corr, ols, path) {
  lim <- range(c(pairs$device_hr, pairs$ecg_hr))
  lab <- merge(corr[, c("device", "pearson_r")], ols[, c("device", "intercept", "slope")])
  lab$text <- sprintf("r = %.3f\nwatch = %.2f + %.3f x ECG", lab$pearson_r, lab$intercept, lab$slope)
  lab$device <- factor(lab$device, levels = levels(pairs$device))
  bands$device <- factor(bands$device, levels = levels(pairs$device))
  p <- ggplot(pairs, aes(ecg_hr, device_hr, colour = device)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey40") +
    geom_ribbon(data = bands, aes(x = ecg_hr, ymin = conf_lo, ymax = conf_hi, fill = device),
                inherit.aes = FALSE, alpha = 0.18) +
    geom_line(data = bands, aes(ecg_hr, fit, colour = device), linewidth = 0.9) +
    geom_point(size = 2) +
    geom_text(data = lab, aes(x = lim[1], y = lim[2], label = text), hjust = 0, vjust = 1,
              size = 3.2, colour = "black", inherit.aes = FALSE) +
    facet_wrap(~ device, ncol = 2) +
    scale_colour_manual(values = DEVICE_COLS) + scale_fill_manual(values = DEVICE_COLS) +
    coord_equal(xlim = lim, ylim = lim) +
    labs(x = "ECG heart rate, protocol mean (bpm)", y = "Watch heart rate, protocol mean (bpm)",
         title = "F1. Watch vs ECG: OLS line (95% CI of mean response) and y = x",
         caption = "n = 22 participants per device. Dashed: y = x (perfect agreement). Solid: OLS watch ~ ECG.") +
    theme_hr()
  save_fig(p, path)
}

fig_error_hist <- function(pairs, err, path) {
  err$device <- factor(err$device, levels = levels(pairs$device))
  p <- ggplot(pairs, aes(error, fill = device)) +
    geom_histogram(binwidth = 2, boundary = 0, colour = "white") +
    geom_vline(xintercept = 0, colour = "grey30") +
    geom_vline(data = err, aes(xintercept = bias), linetype = "dashed", linewidth = 0.8) +
    facet_wrap(~ device, ncol = 2) +
    scale_fill_manual(values = DEVICE_COLS) +
    labs(x = "Measurement error = watch - ECG (bpm)", y = "Participants",
         title = "F2. Distribution of measurement error",
         caption = "Bin width 2 bpm. Solid line: 0 (no error). Dashed line: mean error (bias). n = 22 per device.") +
    theme_hr()
  save_fig(p, path, h = 6)
}

fig_bland_altman <- function(pairs, err, path) {
  err$device <- factor(err$device, levels = levels(pairs$device))
  p <- ggplot(pairs, aes(mean_device_ecg, error, colour = device)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_hline(data = err, aes(yintercept = bias, colour = device), linewidth = 0.9) +
    geom_hline(data = err, aes(yintercept = loa_upper, colour = device), linetype = "dashed") +
    geom_hline(data = err, aes(yintercept = loa_lower, colour = device), linetype = "dashed") +
    geom_point(size = 2) +
    facet_wrap(~ device, ncol = 2) +
    scale_colour_manual(values = DEVICE_COLS) +
    labs(x = "Mean of watch and ECG (bpm)", y = "Watch - ECG (bpm)",
         title = "F3. Bland-Altman: bias and fixed 95% limits of agreement",
         caption = "Solid: bias. Dashed: bias +/- 1.96 SD (fixed LoA, analyst computed). Not the paper's regression-based Mio limits.") +
    theme_hr()
  save_fig(p, path, h = 6.5)
}

fig_corr_vs_bias <- function(corr, err, path) {
  lv <- names(DEVICE_COLS)
  corr$device <- factor(corr$device, levels = rev(lv))
  err$device <- factor(err$device, levels = rev(lv))
  p1 <- ggplot(corr, aes(pearson_r, device, colour = device)) +
    geom_errorbar(aes(xmin = pearson_lo, xmax = pearson_hi), width = 0.2, orientation = "y") +
    geom_point(size = 3) + scale_colour_manual(values = DEVICE_COLS) +
    scale_x_continuous(limits = c(0, 1)) +
    labs(x = "Pearson r (95% CI, Fisher z)", y = NULL, title = "Correlation") + theme_hr()
  p2 <- ggplot(err, aes(bias, device, colour = device)) +
    geom_vline(xintercept = 0, colour = "grey50") +
    geom_errorbar(aes(xmin = loa_lower, xmax = loa_upper), width = 0.12, linetype = "dotted", orientation = "y") +
    geom_errorbar(aes(xmin = bias_lo, xmax = bias_hi), width = 0.3, linewidth = 1, orientation = "y") +
    geom_point(size = 3) + scale_colour_manual(values = DEVICE_COLS) +
    labs(x = "Mean error watch - ECG (bpm)", y = NULL,
         title = "Agreement") + theme_hr() + theme(axis.text.y = element_blank())
  p <- patchwork::wrap_plots(p1, p2, ncol = 2) +
    patchwork::plot_annotation(
      title = "F4. High correlation does not imply agreement",
      caption = "Left: r with 95% CI. Right: thick bar = 95% CI of mean error; dotted bar = fixed 95% LoA (individual differences). n = 22 per device.",
      theme = theme(plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0, colour = "grey30")))
  save_fig(p, path, w = 9, h = 4.2)
}

fig_resid_fitted <- function(diag, lv, path) {
  diag$device <- factor(diag$device, levels = lv)
  lab <- diag[abs(diag$std_resid) > 2, ]
  p <- ggplot(diag, aes(fitted, resid, colour = device)) +
    geom_hline(yintercept = 0, colour = "grey50") +
    geom_point(size = 2) +
    geom_text(data = lab, aes(label = paste0("ID ", id)), vjust = -0.7, size = 3, colour = "black") +
    facet_wrap(~ device, ncol = 2, scales = "free_x") +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.15))) +
    scale_colour_manual(values = DEVICE_COLS) +
    labs(x = "Fitted watch HR from OLS (bpm)", y = "OLS residual (bpm)",
         title = "F5. OLS residuals vs fitted values",
         caption = "Residual = watch - fitted(OLS); this is not the measurement error watch - ECG. Labels: |standardized residual| > 2.") +
    theme_hr()
  save_fig(p, path, h = 6.5)
}

fig_qq <- function(diag, lv, path) {
  diag$device <- factor(diag$device, levels = lv)
  p <- ggplot(diag, aes(sample = std_resid, colour = device)) +
    stat_qq_line(colour = "grey40") + stat_qq(size = 2) +
    facet_wrap(~ device, ncol = 2) +
    scale_colour_manual(values = DEVICE_COLS) +
    labs(x = "Theoretical normal quantile", y = "Standardized OLS residual",
         title = "F6. Normal Q-Q of standardized OLS residuals",
         caption = "n = 22 per device; with this n, curvature in the tails is weak evidence either way.") +
    theme_hr()
  save_fig(p, path, h = 6.5)
}

fig_cooks <- function(diag, lv, path) {
  diag$device <- factor(diag$device, levels = lv)
  lab <- do.call(rbind, lapply(split(diag, diag$device), function(d) d[which.max(d$cooks), ]))
  p <- ggplot(diag, aes(id, cooks, fill = device)) +
    geom_col() +
    geom_hline(aes(yintercept = cooks_ref), linetype = "dashed", colour = "grey30") +
    geom_text(data = lab, aes(label = paste0("ID ", id)), vjust = -0.4, size = 3) +
    facet_wrap(~ device, ncol = 2) +
    scale_fill_manual(values = DEVICE_COLS) +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 22)) +
    labs(x = "Participant ID", y = "Cook's distance",
         title = "F7. Influence of each participant on the OLS fit",
         caption = "Dashed: 4/n = 0.18, a rule of thumb, not a test. All participants stay in the main analysis.") +
    theme_hr()
  save_fig(p, path, h = 6.5)
}
