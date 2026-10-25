# HR02-HR05: 기기별(n = 22) 상관, OLS, 측정오차, 진단, 한 명씩 제외 민감도.

by_device <- function(pairs, f) {
  out <- lapply(split(pairs, pairs$device, drop = TRUE), f)
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

fisher_ci <- function(r, n, level = 0.95) {
  z <- atanh(r); se <- 1 / sqrt(n - 3); q <- qnorm(1 - (1 - level) / 2)
  tanh(c(z - q * se, z + q * se))
}

corr_table <- function(pairs) by_device(pairs, function(d) {
  p <- cor.test(d$device_hr, d$ecg_hr, method = "pearson")
  s <- suppressWarnings(cor.test(d$device_hr, d$ecg_hr, method = "spearman", exact = FALSE))
  rho_ci <- fisher_ci(unname(s$estimate), nrow(d))
  data.frame(
    device = as.character(d$device[1]), n = nrow(d),
    pearson_r = unname(p$estimate),
    pearson_lo = p$conf.int[1], pearson_hi = p$conf.int[2],
    pearson_p = p$p.value,
    spearman_rho = unname(s$estimate),
    spearman_lo_fisher = rho_ci[1], spearman_hi_fisher = rho_ci[2],
    spearman_p = s$p.value,
    stringsAsFactors = FALSE
  )
})

fit_models <- function(pairs) {
  lapply(split(pairs, pairs$device, drop = TRUE),
         function(d) lm(device_hr ~ ecg_hr, data = d))
}

ols_table <- function(models) {
  res <- do.call(rbind, lapply(names(models), function(nm) {
    m <- models[[nm]]; s <- summary(m); ci <- confint(m)
    data.frame(
      device = nm, n = nobs(m),
      intercept = coef(m)[1], intercept_lo = ci[1, 1], intercept_hi = ci[1, 2],
      slope = coef(m)[2], slope_lo = ci[2, 1], slope_hi = ci[2, 2],
      slope_p = s$coefficients[2, 4],
      r2 = s$r.squared, adj_r2 = s$adj.r.squared, sigma = s$sigma,
      df_resid = m$df.residual,
      slope_ci_contains_1 = ci[2, 1] <= 1 && 1 <= ci[2, 2],
      intercept_ci_contains_0 = ci[1, 1] <= 0 && 0 <= ci[1, 2],
      stringsAsFactors = FALSE
    )
  }))
  rownames(res) <- NULL
  res
}

# 평균반응 95% CI와 개인 예측 95% 구간을 따로 계산한다 (그림은 평균반응 CI만 사용).
ols_bands <- function(models, pairs, n_grid = 60) {
  do.call(rbind, lapply(names(models), function(nm) {
    d <- pairs[pairs$device == nm, ]
    g <- data.frame(ecg_hr = seq(min(d$ecg_hr), max(d$ecg_hr), length.out = n_grid))
    cf <- predict(models[[nm]], g, interval = "confidence")
    pr <- predict(models[[nm]], g, interval = "prediction")
    data.frame(device = nm, ecg_hr = g$ecg_hr, fit = cf[, 1],
               conf_lo = cf[, 2], conf_hi = cf[, 3],
               pred_lo = pr[, 2], pred_hi = pr[, 3], stringsAsFactors = FALSE)
  }))
}

error_summary <- function(d) {
  e <- d$error; n <- length(e); b <- mean(e); s <- sd(e)
  tq <- qt(0.975, n - 1)
  data.frame(
    device = as.character(d$device[1]), n = n,
    device_mean = mean(d$device_hr), device_sd = sd(d$device_hr),
    ecg_mean = mean(d$ecg_hr), ecg_sd = sd(d$ecg_hr),
    bias = b, bias_sd = s, bias_se = s / sqrt(n),
    bias_lo = b - tq * s / sqrt(n), bias_hi = b + tq * s / sqrt(n),
    median = median(e), q1 = unname(quantile(e, 0.25)), q3 = unname(quantile(e, 0.75)),
    min = min(e), max = max(e),
    mae = mean(abs(e)), rmse = sqrt(mean(e^2)),
    pct_bias = 100 * b / mean(d$ecg_hr),
    mape = 100 * mean(abs(e) / d$ecg_hr),
    loa_lower = b - 1.96 * s, loa_upper = b + 1.96 * s,
    n_negative = sum(e < 0),
    stringsAsFactors = FALSE
  )
}

error_table <- function(pairs) by_device(pairs, error_summary)

diagnostics_table <- function(models, pairs) {
  do.call(rbind, lapply(names(models), function(nm) {
    m <- models[[nm]]; d <- pairs[pairs$device == nm, ]
    sr <- rstandard(m)
    qq <- qqnorm(sr, plot.it = FALSE)
    data.frame(device = nm, id = d$id, pair_id = d$pair_id,
               ecg_hr = d$ecg_hr, device_hr = d$device_hr,
               fitted = fitted(m), resid = resid(m), std_resid = sr,
               qq_theoretical = qq$x, leverage = hatvalues(m),
               cooks = cooks.distance(m), cooks_ref = 4 / nobs(m),
               stringsAsFactors = FALSE)
  }))
}

# 한 명씩 제외: 각 기기에서 참가자 i를 빼고 다시 계산 (주 분석과 별도 시나리오).
loo_detail <- function(pairs) {
  do.call(rbind, lapply(split(pairs, pairs$device, drop = TRUE), function(d) {
    do.call(rbind, lapply(d$id, function(i) {
      k <- d[d$id != i, ]
      m <- lm(device_hr ~ ecg_hr, data = k)
      es <- error_summary(k)
      data.frame(device = as.character(d$device[1]), dropped_id = i, n = nrow(k),
                 pearson_r = cor(k$device_hr, k$ecg_hr),
                 intercept = unname(coef(m)[1]), slope = unname(coef(m)[2]),
                 bias = es$bias, bias_sd = es$bias_sd,
                 loa_lower = es$loa_lower, loa_upper = es$loa_upper,
                 stringsAsFactors = FALSE)
    }))
  }))
}

loo_summary <- function(detail, corr, ols, err) {
  metrics <- c("pearson_r", "intercept", "slope", "bias", "bias_sd", "loa_lower", "loa_upper")
  full <- merge(merge(corr[, c("device", "pearson_r")],
                      ols[, c("device", "intercept", "slope")], by = "device"),
                err[, c("device", "bias", "bias_sd", "loa_lower", "loa_upper")], by = "device")
  res <- do.call(rbind, lapply(split(detail, detail$device), function(d) {
    f <- full[full$device == d$device[1], ]
    do.call(rbind, lapply(metrics, function(mt) {
      v <- d[[mt]]
      data.frame(device = d$device[1], metric = mt, full_value = f[[mt]],
                 loo_min = min(v), loo_max = max(v),
                 id_at_min = d$dropped_id[which.min(v)],
                 id_at_max = d$dropped_id[which.max(v)],
                 max_abs_change = max(abs(v - f[[mt]])),
                 id_at_max_change = d$dropped_id[which.max(abs(v - f[[mt]]))],
                 stringsAsFactors = FALSE)
    }))
  }))
  rownames(res) <- NULL
  res
}
