# Multiple-testing simulation only. No participant data are read.
# Run: Rscript analysis/src/simulation.R --out-dir analysis/runs/M01-simulation --B 10000 --seed 20260928
# Source this file to use functions without starting a run.

check_count <- function(x, name, minimum = 1L) {
  if (length(x) != 1L || !is.finite(x) || x != floor(x) || x < minimum)
    stop(name, " must be an integer >= ", minimum)
  as.integer(x)
}

simulate_z <- function(B, k, rho = 0, n = 30L, delta = rep(0, k)) {
  B <- check_count(B, "B"); k <- check_count(k, "k"); n <- check_count(n, "n")
  stopifnot(length(rho) == 1L, is.finite(rho), rho >= 0, rho <= 1,
            length(delta) == k, all(is.finite(delta)))
  # If X_ij = delta_j + sqrt(rho)*U_i + sqrt(1-rho)*E_ij, i=1,...,n,
  # Z_j = sqrt(n)*mean_i(X_ij) has exactly the following joint distribution.
  # U_i and E_ij are independent standard normals, known marginal SD=1.
  # Generating the sufficient statistic avoids allocating B*n*k raw observations.
  independent <- matrix(rnorm(B * k), nrow = B, ncol = k)
  shared <- rnorm(B)
  z <- sqrt(1 - rho) * independent + sqrt(rho) * shared
  z <- sweep(z, 2L, sqrt(n) * delta, "+")
  p <- matrix(pnorm(z, lower.tail = FALSE), nrow = B, ncol = k)
  list(z = z, p = p)
}

rejections <- function(p, method, alpha = .05) {
  stopifnot(is.matrix(p), all(is.finite(p)), all(p >= 0 & p <= 1),
            length(alpha) == 1L, alpha > 0, alpha < 1)
  if (!method %in% c("unadjusted", "bonferroni", "BH")) stop("Unknown method")
  if (method == "unadjusted") return(p <= alpha)
  # Each row is a separate family; adjustments never pool separate repetitions.
  adjusted <- t(matrix(vapply(seq_len(nrow(p)), function(i)
    p.adjust(p[i, ], method = method), numeric(ncol(p))),
    nrow = ncol(p), ncol = nrow(p)))
  adjusted <= alpha
}

error_metrics <- function(reject, is_null) {
  stopifnot(is.matrix(reject), is.logical(reject), !anyNA(reject),
            is.logical(is_null), !anyNA(is_null), length(is_null) == ncol(reject))
  R <- rowSums(reject)
  V <- rowSums(reject[, is_null, drop = FALSE])
  S <- rowSums(reject[, !is_null, drop = FALSE])
  m1 <- sum(!is_null)
  data.frame(R = R, V = V, S = S, any_false = as.integer(V > 0),
             FDP = V / pmax(R, 1L),
             power = if (m1 > 0L) S / m1 else rep(NA_real_, nrow(reject)))
}

mc_summary <- function(x, bernoulli = FALSE) {
  if (all(is.na(x))) return(c(estimate = NA, mcse = NA, lower95 = NA, upper95 = NA))
  stopifnot(!anyNA(x), length(x) >= 2L, all(x >= 0 & x <= 1))
  B <- length(x); est <- mean(x); z <- qnorm(.975)
  if (bernoulli) {
    stopifnot(all(x %in% c(0, 1)))
    mcse <- sqrt(est * (1 - est) / B)
    center <- (est + z^2 / (2 * B)) / (1 + z^2 / B)
    half <- z * sqrt(est * (1 - est) / B + z^2 / (4 * B^2)) / (1 + z^2 / B)
    ci <- c(center - half, center + half)
  } else {
    mcse <- sd(x) / sqrt(B)
    ci <- pmax(0, pmin(1, est + c(-1, 1) * z * mcse))
  }
  c(estimate = est, mcse = mcse, lower95 = ci[1L], upper95 = ci[2L])
}

simulation_design <- function(seed = 20260928L) {
  # expand.grid is deliberately part of the executed design construction.
  design <- expand.grid(k = c(1L, 5L, 10L, 20L, 50L, 100L),
                        rho = c(0, .5), scenario = c("global_null", "mixed"),
                        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  design <- design[!(design$scenario == "mixed" & design$k < 5L), ]
  rownames(design) <- NULL
  design$design_id <- seq_len(nrow(design))
  design$seed <- as.integer(seed + design$design_id)
  design$n <- 30L
  design$m1 <- ifelse(design$scenario == "mixed", pmax(1L, floor(.2 * design$k)), 0L)
  design$alternative_delta <- ifelse(design$scenario == "mixed", .5, 0)
  design
}

run_cell <- function(k, rho, scenario, seed, design_id, n = 30L, B = 10000L, alpha = .05) {
  set.seed(seed)
  m1 <- if (scenario == "mixed") max(1L, floor(.2 * k)) else 0L
  delta <- c(rep(.5, m1), rep(0, k - m1))
  dat <- simulate_z(B, k, rho, n, delta)
  is_null <- delta == 0
  methods <- c("unadjusted", "bonferroni", "BH")
  metrics <- lapply(methods, function(method) error_metrics(rejections(dat$p, method, alpha), is_null))
  names(metrics) <- methods
  rows <- lapply(methods, function(method) {
    x <- metrics[[method]]
    fwer <- mc_summary(x$any_false, TRUE)
    fdr <- mc_summary(x$FDP, all(is_null))
    power <- mc_summary(x$power)
    values <- c(setNames(fwer, paste0("FWER_", names(fwer))),
                setNames(fdr, paste0("FDR_", names(fdr))),
                setNames(power, paste0("power_", names(power))))
    theory <- if (scenario == "global_null" && rho == 0 && method == "unadjusted") 1 - (1 - alpha)^k else NA_real_
    data.frame(design_id = design_id, simulation = TRUE, B = B, seed = seed,
               k = k, rho = rho, scenario = scenario, m0 = sum(is_null), m1 = m1,
               n = n, alpha = alpha, method = method, as.list(values),
               independent_raw_FWER_theory = theory,
               theory_minus_estimate = theory - fwer[["estimate"]], check.names = FALSE)
  })
  list(summary = do.call(rbind, rows), metrics = metrics)
}

save_plot_pair <- function(outdir, stem, plotter, width = 10, height = 5) {
  png(file.path(outdir, paste0(stem, ".png")), width = width, height = height, units = "in", res = 150)
  tryCatch(plotter(), finally = dev.off())
  pdf(file.path(outdir, paste0(stem, ".pdf")), width = width, height = height)
  tryCatch(plotter(), finally = dev.off())
}

plot_inflation <- function(results, B) {
  par(mfrow = c(1, 2), mar = c(4.2, 4.3, 3.3, .8), oma = c(1.7, 0, 0, 0))
  colors <- c(unadjusted = "#B44132", bonferroni = "#276A91", BH = "#4D8252")
  for (rr in c(0, .5)) {
    plot(NA, xlim = c(1, 100), ylim = c(0, 1), xlab = "Tests per family (k)", ylab = "FWER",
         main = paste0("SIMULATION: global null, rho = ", rr))
    abline(h = .05, lty = 3, col = "gray50")
    for (method in names(colors)) {
      d <- results[results$scenario == "global_null" & results$rho == rr & results$method == method, ]
      lines(d$k, d$FWER_estimate, type = "b", pch = 16, col = colors[method], lwd = 2)
      arrows(d$k, d$FWER_lower95, d$k, d$FWER_upper95, angle = 90, code = 3, length = .025, col = colors[method])
    }
    if (rr == 0) curve(1 - .95^x, 1, 100, add = TRUE, lty = 2, lwd = 1.5)
    legend("topleft", legend = c("Unadjusted", "Bonferroni", "BH", if (rr == 0) "1 - .95^k (independent)"),
           col = c(unname(colors), if (rr == 0) "black"), lty = c(1, 1, 1, if (rr == 0) 2), bty = "n", cex = .8)
  }
  mtext(paste0("Simulation only | B = ", B, " | bars: pointwise 95% Monte Carlo Wilson intervals"), outer = TRUE, side = 1, cex = .8)
}

plot_mixed <- function(results, B) {
  par(mfrow = c(1, 2), mar = c(4.2, 4.3, 3.3, .8), oma = c(1.7, 0, 0, 0))
  colors <- c(unadjusted = "#B44132", bonferroni = "#276A91", BH = "#4D8252")
  for (metric in c("FDR", "power")) {
    plot(NA, xlim = c(5, 100), ylim = c(0, 1), xlab = "Tests per family (k)", ylab = metric,
         main = paste0("SIMULATION: mixed null, ", metric))
    if (metric == "FDR") abline(h = .05, lty = 3, col = "gray50")
    for (method in names(colors)) for (rr in c(0, .5)) {
      d <- results[results$scenario == "mixed" & results$rho == rr & results$method == method, ]
      lines(d$k, d[[paste0(metric, "_estimate")]], type = "b", pch = if (rr == 0) 16 else 1,
            col = colors[method], lty = if (rr == 0) 1 else 2, lwd = 1.5)
    }
    legend(if (metric == "FDR") "topright" else "bottomleft", legend = c("Unadjusted", "Bonferroni", "BH", "rho=0: solid", "rho=.5: dashed"),
           col = c(unname(colors), "gray30", "gray30"), lty = c(1, 1, 1, 1, 2), bty = "n", cex = .8)
  }
  mtext(paste0("Simulation only | B = ", B, " | 20% nonnull, delta=.5, n=30 | FDR and power have different denominators"), outer = TRUE, side = 1, cex = .75)
}

run_simulation <- function(outdir, B = 10000L, seed = 20260928L) {
  B <- check_count(B, "B", 2L); seed <- check_count(seed, "seed")
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  logfile <- file(file.path(outdir, "execution.log"), "wt")
  sink(logfile, split = TRUE)
  warning_messages <- character()
  on.exit({
    writeLines(if (length(warning_messages)) warning_messages else "No warnings.", file.path(outdir, "warnings.txt"))
    capture.output(sessionInfo(), file = file.path(outdir, "sessionInfo.txt"))
    cat("Finished:", format(Sys.time(), tz = "UTC"), "UTC\n")
    sink(); close(logfile)
  }, add = TRUE)
  withCallingHandlers({
    cat("SIMULATION ONLY. Started:", format(Sys.time(), tz = "UTC"), "UTC\n")
    cat("Master seed:", seed, " B:", B, "\n")
    RNGkind("Mersenne-Twister", "Inversion", "Rejection")
    cat("RNGkind:", paste(RNGkind(), collapse = ", "), "\n")
    design <- simulation_design(seed)
    write.csv(design, file.path(outdir, "design_and_seeds.csv"), row.names = FALSE)
    writeLines(c("SIMULATION ONLY", paste0("B=", B), paste0("master_seed=", seed),
                 "alpha=.05", "n=30", "known_sd=1", "test=one-sided normal z", "diagnostic_seed=master_seed+50000"),
               file.path(outdir, "run_parameters.txt"))
    # Map pairs each design row's parameters; it is not an unused demonstration.
    cells <- Map(function(k, rho, scenario, cell_seed, id, n) {
      cat("Design", id, "k", k, "rho", rho, scenario, "seed", cell_seed, "\n")
      run_cell(k, rho, scenario, cell_seed, id, n, B)
    }, design$k, design$rho, design$scenario, design$seed, design$design_id, design$n)
    results <- do.call(rbind, lapply(cells, `[[`, "summary"))
    rownames(results) <- NULL
    write.csv(results, file.path(outdir, "simulation_summary.csv"), row.names = FALSE, na = "NA")
    saveRDS(list(design = design, B = B, seed = seed, cells = cells, RNGkind = RNGkind()), file.path(outdir, "simulation_replicates.rds"))
    theory <- results[!is.na(results$independent_raw_FWER_theory), ]
    theory$theory_inside_pointwise95 <- with(theory, independent_raw_FWER_theory >= FWER_lower95 & independent_raw_FWER_theory <= FWER_upper95)
    theory$theory_mcse <- with(theory, sqrt(independent_raw_FWER_theory * (1 - independent_raw_FWER_theory) / B))
    theory$standardized_deviation <- with(theory, (FWER_estimate - independent_raw_FWER_theory) / theory_mcse)
    write.csv(theory, file.path(outdir, "theory_comparison.csv"), row.names = FALSE)
    set.seed(seed + 50000L)
    independent <- simulate_z(B, 20, 0)
    dependent <- simulate_z(B, 20, .5)
    diagnostics <- data.frame(simulation = TRUE, rho = c(0, .5), diagnostic_seed = seed + 50000L,
      mean_z = c(mean(independent$z), mean(dependent$z)),
      mean_variance_z = c(mean(apply(independent$z, 2, var)), mean(apply(dependent$z, 2, var))),
      average_correlation = c(mean(cor(independent$z)[upper.tri(cor(independent$z))]), mean(cor(dependent$z)[upper.tri(cor(dependent$z))])),
      null_p_below_05 = c(mean(independent$p <= .05), mean(dependent$p <= .05)))
    write.csv(diagnostics, file.path(outdir, "generator_diagnostics.csv"), row.names = FALSE)
    save_plot_pair(outdir, "null_raw_p_histogram", function() {
      par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
      for (i in 1:2) {
        p <- if (i == 1) independent$p else dependent$p
        hist(as.vector(p), breaks = seq(0, 1, by = .05), probability = TRUE, col = "#C4DDE7", border = "white",
             xlab = "Raw null p-value", ylim = c(0, 1.3), main = paste0("SIMULATION: null p, rho=", c(0, .5)[i]))
        abline(h = 1, col = "#B44132", lty = 2, lwd = 2)
      }
    })
    save_plot_pair(outdir, "fwer_inflation", function() plot_inflation(results, B))
    save_plot_pair(outdir, "mixed_fdr_power", function() plot_mixed(results, B))
    cat("Theory comparisons (pointwise intervals may miss by chance):\n")
    print(theory[, c("k", "FWER_estimate", "independent_raw_FWER_theory", "standardized_deviation", "theory_inside_pointwise95")])
    cat("Generator diagnostics:\n"); print(diagnostics)
    cat("Completed", nrow(design), "design cells and", nrow(results), "method summaries.\n")
    invisible(results)
  }, warning = function(w) {
    warning_messages <<- c(warning_messages, conditionMessage(w))
    cat("WARNING:", conditionMessage(w), "\n")
    invokeRestart("muffleWarning")
  })
}

parse_cli <- function(args) {
  opt <- list(outdir = "analysis/runs/M01-simulation", B = 10000L, seed = 20260928L)
  i <- 1L
  while (i <= length(args)) {
    key <- args[i]
    if (key == "--pilot") { opt$B <- 1000L; i <- i + 1L; next }
    if (!key %in% c("--out-dir", "--B", "--seed") || i == length(args)) stop("Usage: --out-dir PATH --B INTEGER --seed INTEGER [--pilot]")
    value <- args[i + 1L]
    if (key == "--out-dir") opt$outdir <- value
    if (key == "--B") opt$B <- as.numeric(value)
    if (key == "--seed") opt$seed <- as.numeric(value)
    i <- i + 2L
  }
  opt
}

if (sys.nframe() == 0L) {
  args <- parse_cli(commandArgs(trailingOnly = TRUE))
  do.call(run_simulation, args)
}
