source("R/03_simulation.R")

if (!file.exists("results/tables/03_paper_curve.csv")) run_paper_curve()
curve <- read.csv("results/tables/03_paper_curve.csv")

paper_density <- function(x, family) {
  spec <- base_spec(family, config$focal$skewness)
  ratio <- config$focal$sd_ratio
  alignment <- unname(config$paper_alignment[family])
  shift <- alignment_shift(spec, ratio, alignment)
  list(x = spec$d((x - shift) / ratio) / ratio, y = spec$d(x))
}

png("results/figures/04_figure1_density.png", 1600, 650, res = 160)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
for (family in config$distributions) {
  xx <- seq(0.001, 5, length.out = 1200)
  den <- paper_density(xx, family)
  ylim <- if (family == "gamma") c(0, 2) else c(0, 0.8)
  plot(xx, den$x, type = "l", lwd = 2, ylim = ylim,
       xlab = "Value", ylab = "Probability density",
       main = paste0(tools::toTitleCase(family), " distributions"))
  lines(xx, den$y, lwd = 2, lty = 2)
  legend("topright", c("pdf for X", "pdf for Y"), lty = c(1, 2), lwd = 2, bty = "n")
}
dev.off()
record_manifest("results/figures/04_figure1_density.png", "R/04_paper_figures.R", "Paper-style Figure 1")

set.seed(config$seed + 400L)
samples <- lapply(config$distributions, function(f)
  draw_pair(1000L, f, config$focal$skewness, config$focal$sd_ratio,
            unname(config$paper_alignment[f])))
names(samples) <- config$distributions

png("results/figures/04_figure2_histograms.png", 1600, 1200, res = 160)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (family in config$distributions) for (group in c("x", "y")) {
  hist(samples[[family]][[group]], breaks = 35, col = "grey80", border = "white",
       xlab = toupper(group), main = sprintf("%s ~ %s (1000 values)", toupper(group), family))
}
dev.off()

png("results/figures/04_figure3_rejection_curve.png", 1600, 650, res = 160)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
for (family in config$distributions) {
  d <- curve[curve$family == family, ]
  w <- d[d$test == "wmw", ]; tt <- d[d$test == "welch", ]
  plot(w$n, 100 * w$rejection_rate, type = "l", lwd = 2, ylim = c(0, 100),
       xlim = c(0, 1000), xlab = "Number of subjects in each group",
       ylab = "Rejection rate (%)", main = paste0(tools::toTitleCase(family), " distributions"))
  lines(tt$n, 100 * tt$rejection_rate, lwd = 2, lty = 2)
  legend("topleft", c("WMW-test", "t-test"), lty = c(1, 2), lwd = 2, bty = "n")
}
dev.off()

png("results/figures/04_qq_by_group.png", 1800, 650, res = 160)
par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
for (family in config$distributions) {
  z <- samples[[family]]
  qqnorm(z$x, pch = 16, cex = 0.45, col = rgb(0.8, 0, 0, 0.45), xlab = "Normal quantiles",
         main = paste0(tools::toTitleCase(family), " Q-Q"))
  qqline(z$x, col = "firebrick", lwd = 2)
  points(qnorm(ppoints(length(z$y))), sort(z$y), pch = 16, cex = 0.45,
         col = rgb(0, 0.2, 0.8, 0.45))
  qy <- quantile(z$y, c(.25, .75)); slope <- diff(qy) / diff(qnorm(c(.25, .75)))
  abline(a = qy[1] - slope * qnorm(.25), b = slope, col = "navy", lwd = 2, lty = 2)
  legend("topleft", c("X", "Y"), col = c("firebrick", "navy"), lty = c(1, 2), bty = "n")
}
dev.off()

set.seed(config$seed + 401L)
z <- samples$lognormal
boot <- replicate(2000L, mean(sample(z$x, replace = TRUE)) - mean(sample(z$y, replace = TRUE)))
welch <- welch_manual(z$x, z$y)
boot_ci <- quantile(boot, c(.025, .975))
wci <- suppressWarnings(wilcox.test(z$x, z$y, exact = FALSE, conf.int = TRUE))
ci <- data.frame(method = c("Welch mean", "Bootstrap mean", "WMW location"),
                 estimate = c(welch$estimate, mean(boot), unname(wci$estimate)),
                 lower = c(welch$conf.int[1], boot_ci[1], wci$conf.int[1]),
                 upper = c(welch$conf.int[2], boot_ci[2], wci$conf.int[2]))
write.csv(ci, "results/tables/04_confidence_intervals.csv", row.names = FALSE)

png("results/figures/04_resampling_distribution.png", 900, 650, res = 150)
hist(boot, breaks = 35, col = "grey80", border = "white",
     xlab = "Bootstrap difference in means", main = "Resampling distribution")
abline(v = c(0, boot_ci), lty = c(2, 1, 1), lwd = 2, col = c("black", "firebrick", "firebrick"))
dev.off()

png("results/figures/04_ci_juxtaposition.png", 900, 650, res = 150)
par(mar = c(5, 10, 3, 1))
plot(ci$estimate, seq_len(nrow(ci)), xlim = range(c(ci$lower, ci$upper, 0)),
     yaxt = "n", ylab = "", xlab = "Estimated location difference", pch = 16,
     main = "95% confidence intervals")
segments(ci$lower, seq_len(nrow(ci)), ci$upper, seq_len(nrow(ci)), lwd = 3)
abline(v = 0, lty = 2)
axis(2, at = seq_len(nrow(ci)), labels = ci$method, las = 1)
dev.off()

run_grid <- function(reps = config$grid_reps) {
  out <- list(); k <- 0L
  for (family in config$distributions) for (sk in config$skewness) for (sr in config$sd_ratio) {
    k <- k + 1L
    out[[k]] <- simulate_condition(1000L, family, sk, sr,
      unname(config$paper_alignment[family]), reps, config$seed + 4000L + k)
  }
  ans <- do.call(rbind, out)
  write.csv(ans, "results/tables/04_type1_grid.csv", row.names = FALSE)
  ans
}

grid <- if (file.exists("results/tables/04_type1_grid.csv"))
  read.csv("results/tables/04_type1_grid.csv") else run_grid()

png("results/figures/04_type1_error_grid.png", 1600, 650, res = 160)
par(mfrow = c(1, 2), mar = c(5, 5, 3, 1))
for (family in config$distributions) {
  d <- grid[grid$family == family & grid$test == "wmw", ]
  m <- outer(config$skewness, config$sd_ratio,
             Vectorize(function(sk, sr) d$rejection_rate[d$skewness == sk & d$sd_ratio == sr]))
  image(config$sd_ratio, config$skewness, t(m), zlim = c(0, 1),
        col = hcl.colors(30, "YlOrRd", rev = TRUE), xlab = "SD ratio X/Y",
        ylab = "Skewness", main = paste0(tools::toTitleCase(family), ": WMW rejection rate"))
  contour(config$sd_ratio, config$skewness, t(m), add = TRUE, drawlabels = TRUE)
}
dev.off()

invisible(lapply(c("results/figures/04_figure2_histograms.png",
  "results/figures/04_figure3_rejection_curve.png", "results/figures/04_qq_by_group.png",
  "results/figures/04_resampling_distribution.png", "results/figures/04_ci_juxtaposition.png",
  "results/figures/04_type1_error_grid.png"), record_manifest,
  script = "R/04_paper_figures.R", notes = "Visualization"))
