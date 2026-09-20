source("R/00_setup.R")
source("R/01_generators.R")
source("R/02_tests_effects.R")

simulate_condition <- function(n, family, skewness, sd_ratio, alignment, reps, seed) {
  set.seed(seed)
  pvals <- replicate(reps, {
    z <- draw_pair(n, family, skewness, sd_ratio, alignment)
    c(
      welch = welch_p_fast(z$x, z$y),
      wmw = wmw_p_fast(z$x, z$y, correct = TRUE)
    )
  })
  rates <- rowMeans(pvals < config$alpha)
  se <- sqrt(as.numeric(rates) * (1 - as.numeric(rates)) / reps)
  data.frame(
    family, alignment, n, skewness, sd_ratio, test = names(rates),
    rejection_rate = as.numeric(rates), mcse = se,
    lower = pmax(0, as.numeric(rates) - 1.96 * se),
    upper = pmin(1, as.numeric(rates) + 1.96 * se), reps, seed
  )
}

run_paper_curve <- function(reps = config$reps) {
  out <- list(); k <- 0L
  for (family in config$distributions) for (n in config$n) {
    k <- k + 1L
    out[[k]] <- simulate_condition(
      n, family, config$focal$skewness, config$focal$sd_ratio,
      unname(config$paper_alignment[family]), reps, config$seed + k
    )
  }
  ans <- do.call(rbind, out)
  write.csv(ans, "results/tables/03_paper_curve.csv", row.names = FALSE)
  record_manifest("results/tables/03_paper_curve.csv", "R/03_simulation.R",
                  sprintf("Figure 3 curve; %d replications", reps))
  ans
}

if (sys.nframe() == 0L) run_paper_curve()
