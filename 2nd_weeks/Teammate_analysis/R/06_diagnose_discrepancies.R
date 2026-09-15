# =============================================================================
# 06_diagnose_discrepancies.R — 남은 불일치의 원인을 가설별로 검정한다
#   원칙: 한 번에 하나만 바꾼다. 각 가설의 "점수" = Σ|재현 − 논문| (4개 사분위, 평균과 SD).
#         점수가 가장 작은 가설이 논문이 실제로 쓴 규칙일 가능성이 가장 높다.
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(dplyr); library(survey) })
options(width = 140)

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
raw_dir  <- file.path(proj_dir, "data", "raw")
dat <- readRDS(file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))

# ---- 논문 Table 1 값 (검정 대상 행만) -----------------------------------------
P <- list(
  RIDAGEYR = list(m = c(37.06, 46.33, 51.74, 57.47), s = c(13.45, 15.05, 15.90, 16.14)),
  BMXBMI   = list(m = c(24.96, 28.32, 30.67, 34.22), s = c(4.70, 5.32, 6.37, 7.82)),
  BMXWAIST = list(m = c(86.09, 97.24, 104.79, 115.34), s = c(10.56, 11.61, 13.19, 16.13)),
  BMXWT    = list(m = c(74.70, 82.06, 86.29, 91.65), s = c(16.85, 19.41, 21.81, 25.21)),
  INDFMPIR = list(m = c(3.08, 3.14, 2.96, 2.61), s = c(1.62, 1.59, 1.60, 1.52)),
  LBDHDD   = list(m = c(57.27, 54.00, 52.22, 51.20), s = c(16.23, 16.65, 16.84, 14.41)),
  LBXTC    = list(m = c(183.55, 194.32, 196.08, 192.35), s = c(37.46, 39.38, 42.12, 42.86)),
  LBXTR    = list(m = c(107.49, 117.45, 124.53, 126.97), s = c(63.03, 67.70, 80.28, 61.62)),
  LBDLDL   = list(m = c(109.30, 113.27, 113.47, 111.61), s = c(22.37, 23.74, 24.32, 24.87))
)
P_educ  <- rbind(`Less than high school` = c(9.01, 12.32, 16.07, 19.36), `High school` = c(18.20, 21.31, 24.15, 26.44), `More than high school` = c(72.79, 66.33, 59.76, 54.17))
P_stroke <- c(0.90, 2.00, 3.08, 5.49)

# ---- 도구 -----------------------------------------------------------------------
wstat <- function(x, w, g) {            # 가중 평균·SD (Hájek) — svymean/svyvar 와 동일한 점추정
  sapply(split(seq_along(x), g), function(i) { xi <- x[i]; wi <- w[i]; ok <- !is.na(xi); xi <- xi[ok]; wi <- wi[ok]
    m <- sum(wi * xi) / sum(wi); v <- sum(wi * (xi - m)^2) / sum(wi) * length(xi) / (length(xi) - 1); c(m = m, s = sqrt(v)) })
}
score <- function(st, ref) sum(abs(st["m", ] - ref$m)) + sum(abs(st["s", ] - ref$s))
fmt   <- function(st) paste(sprintf("%.2f±%.2f", st["m", ], st["s", ]), collapse = "  ")
hr    <- function(t) cat("\n", strrep("=", 120), "\n", t, "\n", strrep("=", 120), "\n", sep = "")

# =============================================================================
hr("검정 A. 가중치 방식 — Q4 쪽 근소 차이(나이·체중·교육·뇌졸중)의 원인인가?")
# =============================================================================
raw_mec <- dat$wt_mec_raw
raw_int <- dat$wt_int_raw

schemes <- list(
  "A0 MEC, CDC 재조정 2/9.2 & 3.2/9.2 (처음 재현)" = dat$wt_mec_cdc,
  "A1 MEC 원가중치 그대로 (재조정 없음)"           = raw_mec,
  "A2 MEC, 모든 주기 1/4"                         = raw_mec / 4,
  "A3 MEC, P주기도 2/9.2 (기간 무시)"              = raw_mec * (2 / 9.2),
  "A4 설문가중치 WTINT, CDC 재조정"                = ifelse(dat$cycle == "P", raw_int * 3.2 / 9.2, raw_int * 2 / 9.2),
  "A5 비가중 (전원 1)"                             = rep(1, nrow(dat)),
  "A6 설문가중치 WTINT 원가중치 그대로"            = raw_int
)
vars_A <- c("RIDAGEYR", "BMXBMI", "BMXWAIST", "BMXWT", "INDFMPIR", "LBDHDD", "LBXTC")
resA <- sapply(schemes, function(w) {
  sc <- sapply(vars_A, function(v) score(wstat(dat[[v]], w, dat$WWI_q), P[[v]]))
  ed <- { tb <- tapply(w[!is.na(dat$educ)], list(dat$educ[!is.na(dat$educ)], dat$WWI_q[!is.na(dat$educ)]), sum); sum(abs(prop.table(tb, 2) * 100 - P_educ)) }
  stk <- sum(abs(tapply(w * dat$stroke, dat$WWI_q, sum) / tapply(w, dat$WWI_q, sum) * 100 - P_stroke))
  c(sc, educ = ed, stroke = stk)
})
resA <- rbind(resA, 합계 = colSums(resA))
cat("점수 = Σ|Δ| (작을수록 논문에 가까움)\n"); print(round(t(resA), 2))
best_A <- names(which.min(resA["합계", ])); cat("\n→ 최적 가중치 방식:", best_A, "\n")
cat("   나이 Q1~Q4 (최적):", fmt(wstat(dat$RIDAGEYR, schemes[[best_A]], dat$WWI_q)), "\n")
cat("   나이 Q1~Q4 (논문):", paste(sprintf("%.2f±%.2f", P$RIDAGEYR$m, P$RIDAGEYR$s), collapse = "  "), "\n")

# 가중치 재조정 계수를 연속적으로 바꿔 보기: P 주기 계수 f 를 0.20~0.45 로 (현재 3.2/9.2 = 0.348)
cat("\nA6. P 주기 계수 f 를 바꿔가며 (G,H,I 는 (1-f)/3 씩) — 나이·체중·뇌졸중 합계 점수\n")
fs <- seq(0.20, 0.45, by = 0.025)
sc_f <- sapply(fs, function(f) { w <- ifelse(dat$cycle == "P", raw_mec * f, raw_mec * (1 - f) / 3)
  sum(sapply(c("RIDAGEYR", "BMXWT", "BMXWAIST"), function(v) score(wstat(dat[[v]], w, dat$WWI_q), P[[v]]))) +
  sum(abs(tapply(w * dat$stroke, dat$WWI_q, sum) / tapply(w, dat$WWI_q, sum) * 100 - P_stroke)) })
print(data.frame(f = fs, score = round(sc_f, 2)), row.names = FALSE)
cat("→ 최소 점수 f =", fs[which.min(sc_f)], " (CDC 지침값 0.348 과 비교)\n")

# =============================================================================
hr("검정 B. 중성지방·LDL — SD 가 작은 이유는 결측 대치(imputation)인가?")
# =============================================================================
w <- schemes[[best_A]]
for (v in c("LBXTR", "LBDLDL")) {
  x <- dat[[v]]; miss <- is.na(x); n_obs <- sum(!miss)
  cat(sprintf("\n[%s] 관측 %d명 (%.1f%%), 결측 %d명\n", v, n_obs, 100 * n_obs / length(x), sum(miss)))
  cat(sprintf("   이론: 결측을 평균으로 채우면 SD 는 √(관측비율) = √%.3f = %.3f 배로 줄어야 함 → 예상 SD ≈ %.1f (논문 Q1 SD %.2f)\n",
              n_obs / length(x), sqrt(n_obs / length(x)), sqrt(n_obs / length(x)) * wstat(x, w, dat$WWI_q)["s", 1], P[[v]]$s[1]))
  m_all_u <- mean(x, na.rm = TRUE); m_all_w <- sum(w * x, na.rm = TRUE) / sum(w[!miss])
  m_q <- tapply(x, dat$WWI_q, mean, na.rm = TRUE); med <- median(x, na.rm = TRUE)
  set.seed(1); fit <- lm(x ~ RIDAGEYR + sex + BMXBMI, data = dat); pred <- predict(fit, newdata = dat)
  hyp <- list(
    "B0 대치 없음 (현재)"                     = x,
    "B1 전체 비가중 평균으로 대치"             = ifelse(miss, m_all_u, x),
    "B2 전체 가중 평균으로 대치"               = ifelse(miss, m_all_w, x),
    "B3 사분위별 평균으로 대치"                = ifelse(miss, m_q[as.integer(dat$WWI_q)], x),
    "B4 전체 중앙값으로 대치"                  = ifelse(miss, med, x),
    "B5 회귀 예측값(나이·성별·BMI)으로 대치"   = ifelse(miss, pred, x),
    "B6 대치 없음 + 비가중"                    = NULL
  )
  out <- lapply(names(hyp), function(h) {
    st <- if (h == "B6 대치 없음 + 비가중") wstat(x, rep(1, length(x)), dat$WWI_q) else wstat(hyp[[h]], w, dat$WWI_q)
    data.frame(가설 = h, Q1_Q4 = fmt(st), 점수 = round(score(st, P[[v]]), 1))
  }) |> bind_rows()
  out <- rbind(out, data.frame(가설 = "논문", Q1_Q4 = paste(sprintf("%.2f±%.2f", P[[v]]$m, P[[v]]$s), collapse = "  "), 점수 = 0))
  print(out, row.names = FALSE, right = FALSE)
  cat("→ 최적:", out$가설[which.min(out$점수[out$가설 != "논문"])], "\n")
}

# =============================================================================
hr("검정 C. 교육 Q4 — 가중치(A) 로 설명되는가, 아니면 코딩 규칙인가?")
# =============================================================================
ed_tab <- function(e, w) { ok <- !is.na(e); tb <- tapply(w[ok], list(e[ok], dat$WWI_q[ok]), sum); round(prop.table(tb, 2) * 100, 2) }
cat("DMDEDUC2 코드 분포 (23,389명):\n"); print(table(dat$DMDEDUC2, useNA = "always"))
hypC <- list(
  "C0 현재 (1,2 / 3 / 4,5; 7,9 결측)"           = dat$educ,
  "C1 코드 2(9-11학년)를 High school 로"        = factor(case_when(dat$DMDEDUC2 == 1 ~ "Less than high school", dat$DMDEDUC2 %in% 2:3 ~ "High school", dat$DMDEDUC2 %in% 4:5 ~ "More than high school"), levels = rownames(P_educ)),
  "C2 코드 4(전문대/일부대학)를 High school 로" = factor(case_when(dat$DMDEDUC2 %in% 1:2 ~ "Less than high school", dat$DMDEDUC2 %in% 3:4 ~ "High school", dat$DMDEDUC2 == 5 ~ "More than high school"), levels = rownames(P_educ)),
  "C3 결측(7,9,NA)을 More than HS 로 (최빈값 대치)" = factor(ifelse(is.na(dat$educ), "More than high school", as.character(dat$educ)), levels = rownames(P_educ))
)
for (h in names(hypC)) { for (wn in c("A0 MEC, CDC 재조정 2/9.2 & 3.2/9.2 (처음 재현)", best_A)) {
  tb <- ed_tab(hypC[[h]], schemes[[wn]]); cat(sprintf("\n%s  ×  가중치 %s   점수 %.2f\n", h, wn, sum(abs(tb - P_educ)))); print(tb) } }
cat("\n논문:\n"); print(P_educ)

# =============================================================================
hr("요약")
# =============================================================================
cat("A. 가중치:", best_A, " / P 주기 계수 최적 f =", fs[which.min(sc_f)], "\n")
cat("B. 중성지방·LDL: 위 표의 '최적' 가설 참조 — SD 축소 배율이 √(관측비율) 과 일치하면 평균 대치가 원인\n")
cat("C. 교육: 위 표에서 점수가 가장 작은 조합 참조\n")

# =============================================================================
hr("검정 D. 다른 연속변수(PIR·HDL·TC·음주)도 평균 대치되었는가? — 가중치는 A 의 최적(원가중치) 사용")
# =============================================================================
w_best <- schemes[[best_A]]
P$ALQ130 <- list(m = c(3.24, 4.29, 2.99, 3.33), s = c(18.67, 39.96, 20.49, 29.64))
for (v in c("INDFMPIR", "LBDHDD", "LBXTC", "ALQ130")) {
  x <- dat[[v]]; miss <- is.na(x); ratio <- sqrt(mean(!miss))
  st0 <- wstat(x, w_best, dat$WWI_q); st1 <- wstat(ifelse(miss, mean(x, na.rm = TRUE), x), w_best, dat$WWI_q)
  cat(sprintf("\n[%s] 결측 %d명 (%.1f%%) → 평균 대치 시 SD 예상 배율 %.3f\n", v, sum(miss), 100 * mean(miss), ratio))
  print(data.frame(가설 = c("D0 대치 없음", "D1 전체 평균 대치", "논문"),
                   Q1_Q4 = c(fmt(st0), fmt(st1), paste(sprintf("%.2f±%.2f", P[[v]]$m, P[[v]]$s), collapse = "  ")),
                   점수 = c(round(score(st0, P[[v]]), 2), round(score(st1, P[[v]]), 2), 0)), row.names = FALSE, right = FALSE)
}
