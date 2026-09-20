source("R/00_setup.R")
source("R/01_generators.R")
source("R/02_tests_effects.R")

validate_rate <- function(local, paper_percent, reps) {
  paper <- unname(paper_percent) / 100
  combined_se <- sqrt(local * (1 - local) / reps + paper * (1 - paper) / 10000 +
                      (0.0005 / sqrt(3))^2)
  difference <- local - paper
  z <- if (combined_se == 0) ifelse(difference == 0, 0, Inf) else difference / combined_se
  c(difference = difference, combined_mcse = combined_se,
    z = z, pass = abs(z) <= config$validation_z)
}

validate_focal <- function(path = "results/tables/08_calibration.csv") {
  x <- read.csv(path)
  x <- x[x$stage == "confirmation", ]
  rows <- list(); k <- 0L
  for (i in seq_len(nrow(x))) {
    target <- config$paper_focal_percent[[x$family[i]]][x$test[i]]
    v <- validate_rate(x$rejection_rate[i], target, x$reps[i])
    k <- k + 1L
    rows[[k]] <- cbind(x[i, ], as.data.frame(as.list(v)))
  }
  ans <- do.call(rbind, rows)
  ans$verdict <- ifelse(ans$pass == 1, "pass", "fail")
  ans$cause <- ifelse(ans$pass == 1, "Monte Carlo 오차 범위 내 일치",
                      "분포 정렬·검정 구현 또는 미공개 원 구현 차이")
  write.csv(ans, "results/tables/validation.csv", row.names = FALSE)
  ans
}

validate_curve <- function(local_path = "results/tables/03_paper_curve.csv",
                           reference_path = "data/reference/paper_curve_skew3_sd1.10.csv") {
  local <- read.csv(local_path)
  ref <- read.csv(reference_path)
  x <- merge(local, ref, by = c("family", "n", "test"), sort = FALSE)
  v <- t(mapply(validate_rate, x$rejection_rate, x$paper_percent, x$reps))
  ans <- cbind(x, as.data.frame(v))
  ans$verdict <- ifelse(ans$pass == 1, "pass", "fail")
  ans$cause <- ifelse(ans$pass == 1, "Monte Carlo 오차 범위 내 일치",
                      "분포 정렬·근사 검정·난수 생성 구현 차이 검토 필요")
  write.csv(ans, "results/tables/03_curve_validation.csv", row.names = FALSE)
  ans
}

similarity_row <- function(d, scope) {
  local <- d$rejection_rate
  paper <- d$paper_percent / 100
  error <- local - paper
  fit <- lm(local ~ paper)
  vp <- mean((paper - mean(paper))^2)
  vl <- mean((local - mean(local))^2)
  cp <- mean((paper - mean(paper)) * (local - mean(local)))
  paper_range <- diff(range(paper))
  data.frame(
    scope = scope,
    comparisons = nrow(d),
    bias_pp = 100 * mean(error),
    mae_pp = 100 * mean(abs(error)),
    rmse_pp = 100 * sqrt(mean(error^2)),
    max_abs_error_pp = 100 * max(abs(error)),
    nrmse_range_percent = if (paper_range > 0) 100 * sqrt(mean(error^2)) / paper_range else NA_real_,
    pearson_r = cor(local, paper),
    r_squared = cor(local, paper)^2,
    lin_ccc = 2 * cp / (vp + vl + (mean(paper) - mean(local))^2),
    regression_intercept_pp = 100 * unname(coef(fit)[1]),
    regression_slope = unname(coef(fit)[2]),
    within_0_5pp_percent = 100 * mean(abs(error) <= 0.005),
    within_1pp_percent = 100 * mean(abs(error) <= 0.01),
    mc_pass_percent = 100 * mean(d$pass == 1),
    mean_abs_z = mean(abs(d$z)),
    max_abs_z = max(abs(d$z))
  )
}

summarize_similarity <- function(path = "results/tables/03_curve_validation.csv") {
  x <- read.csv(path)
  rows <- list(similarity_row(x, "overall"))
  for (f in unique(x$family)) rows[[length(rows) + 1L]] <-
    similarity_row(x[x$family == f, ], paste0("family:", f))
  for (tt in unique(x$test)) rows[[length(rows) + 1L]] <-
    similarity_row(x[x$test == tt, ], paste0("test:", tt))
  for (f in unique(x$family)) for (tt in unique(x$test)) rows[[length(rows) + 1L]] <-
    similarity_row(x[x$family == f & x$test == tt, ], paste0("family_test:", f, "/", tt))
  ans <- do.call(rbind, rows)
  write.csv(ans, "results/tables/07_similarity_metrics.csv", row.names = FALSE)
  ans
}

set.seed(config$seed + 700L)
a <- rnorm(31); b <- rnorm(23, sd = 1.7)
manual <- welch_manual(a, b)
builtin <- t.test(a, b, var.equal = FALSE)
df_check <- data.frame(manual_df = manual$parameter, r_df = unname(builtin$parameter),
                       absolute_difference = abs(manual$parameter - unname(builtin$parameter)),
                       pass = abs(manual$parameter - unname(builtin$parameter)) <= config$tolerance_df)
write.csv(df_check, "results/tables/07_satterthwaite_check.csv", row.names = FALSE)

if (sys.nframe() == 0L && file.exists("results/tables/08_calibration.csv")) validate_focal()
if (sys.nframe() == 0L && file.exists("results/tables/03_paper_curve.csv")) {
  validate_curve()
  summarize_similarity()
}
