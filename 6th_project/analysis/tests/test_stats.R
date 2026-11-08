# 핵심 계산 검사: 내장함수 결과를 교과서 공식으로 직접 계산한 값과 대조한다.
# 사용법 (작업 디렉터리 = 6th_project/analysis): Rscript tests/test_stats.R runs/R1-20261025
args <- commandArgs(TRUE)
run_dir <- if (length(args)) args[1] else stop("run 디렉터리를 인자로 주세요")
for (f in c("01_build_pairs.R", "02_stats.R")) source(file.path("src", f), encoding = "UTF-8")

n_fail <- 0
check <- function(label, ok) {
  cat(if (ok) "PASS" else "FAIL", " ", label, "\n", sep = "")
  if (!ok) n_fail <<- n_fail + 1
}
near <- function(a, b, tol = 1e-10) isTRUE(all(abs(a - b) < tol))

pairs <- build_pairs("data/raw/pone.0154420.s001.xlsx")
check("88 pairs, 22 per device", nrow(pairs) == 88 && all(table(pairs$device) == 22))
check("error = device - ECG", near(pairs$error, pairs$device_hr - pairs$ecg_hr))
check("spot cell H2 (Samsung ID1) = 78.07", near(pairs$device_hr[pairs$pair_id == "P01-Samsung"], 78.07, 1e-9))
check("spot cell L23 (Mio ID22 ECG) = 96.36", near(pairs$ecg_hr[pairs$pair_id == "P22-Alpha"], 96.36, 1e-9))
check("Fitbit ECG read from column F (header 'Fitbit_metamax')",
      all(pairs$cell_ecg[pairs$device_key == "Fitbit"] == paste0("F", 2:23)))

corr <- read.csv(file.path(run_dir, "tables", "hr02_correlation.csv"))
ols <- read.csv(file.path(run_dir, "tables", "hr03_ols.csv"))
err <- read.csv(file.path(run_dir, "tables", "hr04_error.csv"))
loo <- read.csv(file.path(run_dir, "tables", "hr05_loo_detail.csv"))

for (dev in levels(pairs$device)) {
  d <- pairs[pairs$device == dev, ]; x <- d$ecg_hr; y <- d$device_hr; n <- nrow(d)
  sxy <- sum((x - mean(x)) * (y - mean(y))); sxx <- sum((x - mean(x))^2); syy <- sum((y - mean(y))^2)
  r <- sxy / sqrt(sxx * syy)
  z <- atanh(r); ci <- tanh(z + c(-1, 1) * qnorm(0.975) / sqrt(n - 3))
  b1 <- sxy / sxx; b0 <- mean(y) - b1 * mean(x)
  res <- y - (b0 + b1 * x); s <- sqrt(sum(res^2) / (n - 2))
  se_b1 <- s / sqrt(sxx)
  e <- y - x; bias <- sum(e) / n; sd_e <- sqrt(sum((e - bias)^2) / (n - 1))
  rk <- cor(rank(x), rank(y))
  cr <- corr[corr$device == dev, ]; ol <- ols[ols$device == dev, ]; er <- err[err$device == dev, ]
  check(paste(dev, "Pearson r manual"), near(cr$pearson_r, r))
  check(paste(dev, "Pearson CI = Fisher z manual"), near(c(cr$pearson_lo, cr$pearson_hi), ci))
  check(paste(dev, "Spearman = Pearson on ranks"), near(cr$spearman_rho, rk))
  check(paste(dev, "OLS slope/intercept manual"), near(c(ol$slope, ol$intercept), c(b1, b0)))
  check(paste(dev, "slope CI manual"), near(c(ol$slope_lo, ol$slope_hi), b1 + c(-1, 1) * qt(0.975, n - 2) * se_b1))
  check(paste(dev, "R2 = r^2 (simple regression)"), near(ol$r2, r^2))
  check(paste(dev, "bias and SD manual"), near(c(er$bias, er$bias_sd), c(bias, sd_e)))
  check(paste(dev, "LoA = bias +/- 1.96 SD"), near(c(er$loa_lower, er$loa_upper), bias + c(-1, 1) * 1.96 * sd_e))
  check(paste(dev, "RMSE^2 = bias^2 + SD^2 (n-1)/n"), near(er$rmse^2, bias^2 + sd_e^2 * (n - 1) / n))
  check(paste(dev, "LOO has 22 fits of n = 21"), sum(loo$device == dev) == 22 && all(loo$n[loo$device == dev] == 21))
}
cat(if (n_fail == 0) "ALL PASS\n" else sprintf("%d FAILED\n", n_fail))
quit(status = if (n_fail == 0) 0 else 1)
