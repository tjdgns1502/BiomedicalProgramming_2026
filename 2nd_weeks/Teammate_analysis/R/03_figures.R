# =============================================================================
# 03_figures.R — 히스토그램 · 상자그림 · Q-Q plot (원자료 vs 로그변환)
#   + Q-Q plot 이론분위수 산출식 검증 (ppoints / qnorm 을 손계산과 대조)
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(ggplot2); library(dplyr); library(tidyr); library(moments) })

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
fig_dir  <- file.path(proj_dir, "figures"); dir.create(fig_dir, showWarnings = FALSE)
dat <- readRDS(file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))

theme_set(theme_minimal(base_size = 13))

# ---- 1. 변수별 원자료 vs 로그 : 히스토그램 + Q-Q --------------------------
plot_var <- function(v, label) {
  x <- dat[[v]]; x <- x[!is.na(x) & x > 0]
  df <- bind_rows(data.frame(scale = "원자료 (raw)", value = x),
                  data.frame(scale = "로그변환 (log)", value = log(x))) |>
    mutate(scale = factor(scale, c("원자료 (raw)", "로그변환 (log)")))
  sk <- df |> group_by(scale) |> summarise(g1 = skewness(value), .groups = "drop") |>
    mutate(lab = sprintf("왜도 g1 = %.2f", g1))
  h <- ggplot(df, aes(value)) + geom_histogram(bins = 60, fill = "#4C72B0", colour = "white", linewidth = 0.2) +
    facet_wrap(~scale, scales = "free") +
    geom_text(data = sk, aes(x = Inf, y = Inf, label = lab), hjust = 1.1, vjust = 1.5, size = 4.5) +
    labs(title = paste0(label, " — 히스토그램"), x = NULL, y = "빈도")
  q <- ggplot(df, aes(sample = value)) + stat_qq(size = 0.6, alpha = 0.4, colour = "#4C72B0") + stat_qq_line(colour = "#C44E52") +
    facet_wrap(~scale, scales = "free") +
    labs(title = paste0(label, " — 정규 Q-Q plot"), x = "이론 분위수 Φ⁻¹(pᵢ)", y = "표본 분위수 x₍ᵢ₎")
  ggsave(file.path(fig_dir, paste0("hist_", v, ".png")), h, width = 9, height = 3.6, dpi = 110, bg = "white")
  ggsave(file.path(fig_dir, paste0("qq_",   v, ".png")), q, width = 9, height = 3.6, dpi = 110, bg = "white")
}
plot_var("LBXTR",   "중성지방 (mg/dL)")
plot_var("alcohol", "하루 평균 음주량 (잔)")
plot_var("BMXBMI",  "BMI (kg/m²)")
plot_var("WWI",     "WWI (cm/√kg)")

# ---- 2. 상자그림: WWI 사분위군별 중성지방 (원 vs 로그) ---------------------
bx <- dat |> filter(!is.na(LBXTR)) |>
  transmute(WWI_q, `원자료 (raw)` = LBXTR, `로그변환 (log)` = log(LBXTR)) |>
  pivot_longer(-WWI_q, names_to = "scale", values_to = "value") |>
  mutate(scale = factor(scale, c("원자료 (raw)", "로그변환 (log)")))
b <- ggplot(bx, aes(WWI_q, value, fill = WWI_q)) + geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.3, show.legend = FALSE) +
  facet_wrap(~scale, scales = "free_y") + scale_fill_brewer(palette = "Blues") +
  labs(title = "WWI 사분위군별 중성지방 — 상자그림", x = "WWI 사분위", y = NULL)
ggsave(file.path(fig_dir, "box_LBXTR_by_WWIq.png"), b, width = 9, height = 3.6, dpi = 110, bg = "white")

# ---- 3. WWI 사분위군별 뇌졸중 유병률 (가중) -------------------------------
suppressPackageStartupMessages(library(survey))
des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt, nest = TRUE, data = dat)
sp <- svyby(~stroke, ~WWI_q, des, svymean) |> as.data.frame()
sp$unweighted <- as.numeric(tapply(dat$stroke, dat$WWI_q, mean))
sp_long <- sp |> transmute(WWI_q, `가중 (survey)` = 100 * stroke, `비가중` = 100 * unweighted) |>
  pivot_longer(-WWI_q, names_to = "type", values_to = "pct")
p <- ggplot(sp_long, aes(WWI_q, pct, fill = type)) + geom_col(position = position_dodge(0.7), width = 0.65) +
  geom_text(aes(label = sprintf("%.2f", pct)), position = position_dodge(0.7), vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = c("#4C72B0", "#BBBBBB")) +
  labs(title = "WWI 사분위군별 뇌졸중 유병률 (%)", x = "WWI 사분위", y = "유병률 (%)", fill = NULL) +
  theme(legend.position = "top")
ggsave(file.path(fig_dir, "stroke_by_WWIq.png"), p, width = 7, height = 4, dpi = 110, bg = "white")

# ---- 4. 검증과제: Q-Q plot 이론분위수 산출식을 내장함수와 대조 --------------
# 수식: p_i = (i - a) / (n + 1 - 2a),  a = 3/8 (n<=10), a = 1/2 (n>10);  x축 = Φ^{-1}(p_i)
manual_p <- function(n) { a <- if (n <= 10) 3/8 else 1/2; ((1:n) - a) / (n + 1 - 2 * a) }
for (n in c(5, 20)) {
  cat(sprintf("\nn = %d\n  손계산 p_i     : %s\n  ppoints(n)     : %s\n  손계산 Φ⁻¹(p) : %s\n  qqnorm()$x     : %s\n",
              n, paste(round(manual_p(n), 4), collapse = " "), paste(round(ppoints(n), 4), collapse = " "),
              paste(round(qnorm(manual_p(n)), 3), collapse = " "),
              paste(round(sort(qqnorm(rnorm(n), plot.it = FALSE)$x), 3), collapse = " ")))
  stopifnot(all.equal(manual_p(n), ppoints(n)))
}
cat("\n검증 완료: ppoints() 와 수식 (i-a)/(n+1-2a) 가 일치합니다.\n")
cat("그림 저장 위치:", fig_dir, "\n")
