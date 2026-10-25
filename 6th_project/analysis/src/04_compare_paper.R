# HR06: 원문 Table 1 (Heart rate)와 같은 정의의 값만 비교한다. 허용오차는 plan에 사전 고정.

compare_paper <- function(paper, corr, err) {
  ours <- function(dev, metric) {
    e <- err[err$device == dev, ]; c <- corr[corr$device == dev, ]
    spear <- dev == "Samsung Gear S"   # 원문 * 표시: Spearman rho
    switch(metric,
      n = e$n, device_mean = e$device_mean, device_sd = e$device_sd,
      ecg_mean = e$ecg_mean, ecg_sd = e$ecg_sd,
      corr = if (spear) c$spearman_rho else c$pearson_r,
      corr_lo = if (spear) c$spearman_lo_fisher else c$pearson_lo,
      corr_hi = if (spear) c$spearman_hi_fisher else c$pearson_hi,
      bias = e$bias, bias_sd = e$bias_sd,
      loa_upper = e$loa_upper, loa_lower = e$loa_lower,
      icc = NA_real_)
  }
  statistic <- function(dev, metric) {
    if (metric %in% c("corr", "corr_lo", "corr_hi"))
      return(if (dev == "Samsung Gear S") "Spearman rho (CI: Fisher z, SE=1/sqrt(n-3))" else "Pearson r (CI: Fisher z)")
    if (metric %in% c("loa_upper", "loa_lower")) return("fixed LoA = bias +/- 1.96 SD")
    if (metric == "icc") return("ICC (not computed)")
    "same definition"
  }
  res <- do.call(rbind, lapply(seq_len(nrow(paper)), function(i) {
    p <- paper[i, ]
    v <- ours(p$device, p$metric)
    tol <- if (is.na(p$decimals)) NA_real_ else if (p$decimals == 0) 0 else 0.5 * 10^(-p$decimals)
    if (p$metric == "icc") {
      verdict <- "비교 불가"; note <- "ICC는 과제 범위 밖이라 계산하지 않음"
    } else if (is.na(p$paper_value)) {
      verdict <- "비교 불가"; note <- "원문은 평균값에 따라 변하는 회귀식 LoA(가변 한계)를 보고; 고정 LoA와 다른 추정 대상"
    } else {
      d <- v - p$paper_value
      verdict <- if (abs(d) <= tol + 1e-9) "반올림 일치" else "불일치"
      note <- ""
    }
    data.frame(device = p$device, metric = p$metric, statistic = statistic(p$device, p$metric),
               paper_text = p$paper_text, paper_value = p$paper_value, ours = v,
               ours_rounded = if (is.na(p$decimals)) NA_real_ else round(v, p$decimals),
               diff = if (is.na(p$paper_value)) NA_real_ else v - p$paper_value,
               tolerance = tol, verdict = verdict, note = note,
               evidence_paper = p$evidence, source = p$source, stringsAsFactors = FALSE)
  }))
  # Samsung Pearson r은 원문 0.67(Spearman)과 다른 통계량이므로 별도 행으로 '비교 불가' 표시.
  sam <- corr[corr$device == "Samsung Gear S", ]
  extra <- data.frame(device = "Samsung Gear S", metric = "corr_pearson",
                      statistic = "Pearson r (CI: Fisher z)", paper_text = "0.67* (Spearman)",
                      paper_value = NA_real_, ours = sam$pearson_r, ours_rounded = round(sam$pearson_r, 2),
                      diff = NA_real_, tolerance = NA_real_, verdict = "비교 불가",
                      note = "원문 값은 Spearman rho; 과제 Pearson r을 원문 값으로 바꾸지 않음",
                      evidence_paper = "paper_reported", source = "Table 1 r/Rho", stringsAsFactors = FALSE)
  rbind(res, extra)
}
