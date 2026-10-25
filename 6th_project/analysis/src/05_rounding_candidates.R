# HR06 (탐색적, post-result): 원문 값이 반올림된 중간값으로 계산됐을 가능성 점검. 계획: config/plan_R2-20261025.json

round_away <- function(x, d) sign(x) * floor(abs(x) * 10^d + 0.5 + 1e-9) / 10^d

rounding_candidates <- function(corr, err, paper) {
  pv <- function(dev, m) paper$paper_value[paper$device == dev & paper$metric == m]
  row <- function(cand, dev, metric, rule, value) {
    p <- pv(dev, metric); tol <- if (metric %in% c("corr_lo", "corr_hi")) 0.005 else 0.05
    data.frame(candidate = cand, device = dev, metric = metric, rule = rule,
               candidate_value = value, paper_value = p, diff = value - p, tolerance = tol,
               verdict = if (abs(value - p) <= tol + 1e-9) "반올림 일치" else "불일치",
               evidence = "reproduction_candidate", post_result = TRUE, stringsAsFactors = FALSE)
  }
  out <- list()
  for (dev in corr$device) {
    c <- corr[corr$device == dev, ]; e <- err[err$device == dev, ]
    r2 <- round_away(if (dev == "Samsung Gear S") c$spearman_rho else c$pearson_r, 2)
    ci <- tanh(atanh(r2) + c(-1, 1) * qnorm(0.975) / sqrt(c$n - 3))
    rule1 <- sprintf("Fisher z on r rounded = %.2f", r2)
    out[[length(out) + 1]] <- row("C1", dev, "corr_lo", rule1, ci[1])
    out[[length(out) + 1]] <- row("C1", dev, "corr_hi", rule1, ci[2])

    b2 <- round_away(e$device_mean, 1) - round_away(e$ecg_mean, 1)
    out[[length(out) + 1]] <- row("C2", dev, "bias",
      sprintf("%.1f - %.1f", round_away(e$device_mean, 1), round_away(e$ecg_mean, 1)), b2)
    b3 <- round_away(round_away(e$bias, 2), 1)
    out[[length(out) + 1]] <- row("C3", dev, "bias",
      sprintf("%.4f -> %.2f -> %.1f", e$bias, round_away(e$bias, 2), b3), b3)

    if (dev != "Mio Alpha") {
      s1 <- round_away(e$bias_sd, 1); rule4 <- sprintf("%.1f +/- 1.96 x %.1f", b2, s1)
      out[[length(out) + 1]] <- row("C4", dev, "loa_upper", rule4, b2 + 1.96 * s1)
      out[[length(out) + 1]] <- row("C4", dev, "loa_lower", rule4, b2 - 1.96 * s1)
    }
  }
  res <- do.call(rbind, out); rownames(res) <- NULL
  res
}
