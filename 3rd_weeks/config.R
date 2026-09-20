config <- list(
  seed = 22697476L,
  alpha = 0.05,
  reps = 10000L,
  pilot_reps = 1000L,
  grid_reps = 500L,
  permutation_reps = 4999L,
  n = c(10L, 25L, 50L, 100L, 250L, 500L, 1000L),
  skewness = c(1, 2, 3, 4),
  sd_ratio = c(1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.40, 1.50),
  distributions = c("gamma", "lognormal"),
  candidate_alignment = c("mean", "median"),
  paper_alignment = c(gamma = "mean", lognormal = "mean"),
  focal = list(n = 1000L, skewness = 3, sd_ratio = 1.10),
  paper_focal_percent = list(
    gamma = c(wmw = 98.8, welch = 5.1),
    lognormal = c(wmw = 27.6, welch = 4.9)
  ),
  tolerance_df = 1e-10,
  validation_z = 3,
  max_calibration_rounds = 3L
)
