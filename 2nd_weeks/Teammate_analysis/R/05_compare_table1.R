# =============================================================================
# 05_compare_table1.R — 논문 Table 1 (원본) vs 재현값 셀 단위 비교
#   출력: data/table1_comparison.csv  (long 형식: 행, 열, 재현값, 논문값, 차이)
#         이후 build_table1_compare_html.py 가 이 CSV로 시각화 HTML을 만든다.
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(dplyr); library(survey) })

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
dat <- readRDS(file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))
dat$stroke_f <- factor(dat$stroke, 0:1, c("Yes", "No")[2:1])
des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt, nest = TRUE, data = dat)

# ---- 논문 Table 1 원본 값 (PDF Table 1 을 그대로 옮김) -----------------------
paper_cont <- list(
  "Age (years)"                          = list(m = c(37.06, 46.33, 51.74, 57.47), s = c(13.45, 15.05, 15.90, 16.14), p = "<0.001"),
  "BMI (kg/m2)"                          = list(m = c(24.96, 28.32, 30.67, 34.22), s = c(4.70, 5.32, 6.37, 7.82),     p = "<0.001"),
  "Waist circumference (cm)"             = list(m = c(86.09, 97.24, 104.79, 115.34), s = c(10.56, 11.61, 13.19, 16.13), p = "<0.001"),
  "PIR"                                  = list(m = c(3.08, 3.14, 2.96, 2.61), s = c(1.62, 1.59, 1.60, 1.52),         p = "<0.001"),
  "Weight (kg)"                          = list(m = c(74.70, 82.06, 86.29, 91.65), s = c(16.85, 19.41, 21.81, 25.21), p = "<0.001"),
  "Average alcohol consumption past 12 months" = list(m = c(3.24, 4.29, 2.99, 3.33), s = c(18.67, 39.96, 20.49, 29.64), p = "0.187"),
  "Triglycerides (mg/dL)"                = list(m = c(107.49, 117.45, 124.53, 126.97), s = c(63.03, 67.70, 80.28, 61.62), p = "<0.001"),
  "HDL-C (mg/dL)"                        = list(m = c(57.27, 54.00, 52.22, 51.20), s = c(16.23, 16.65, 16.84, 14.41), p = "<0.001"),
  "LDL-C (mg/dL)"                        = list(m = c(109.30, 113.27, 113.47, 111.61), s = c(22.37, 23.74, 24.32, 24.87), p = "<0.001"),
  "Total cholesterol (mg/dL)"            = list(m = c(183.55, 194.32, 196.08, 192.35), s = c(37.46, 39.38, 42.12, 42.86), p = "<0.001")
)
paper_cat <- list(
  "Sex, (%)"                    = list(p = "<0.001", lv = list("Male" = c(59.02, 52.33, 46.07, 32.29), "Female" = c(40.98, 47.67, 53.93, 67.71))),
  "Race/ethnicity, (%)"         = list(p = "<0.001", lv = list("Non-Hispanic White" = c(64.39, 64.73, 64.07, 67.08), "Non-Hispanic Black" = c(14.97, 10.25, 10.01, 9.27),
                                                            "Mexican American" = c(5.58, 8.57, 10.60, 9.91), "Other race/multiracial" = c(15.06, 16.45, 15.32, 13.74))),
  "Education level, (%)"        = list(p = "<0.001", lv = list("Less than high school" = c(9.01, 12.32, 16.07, 19.36), "High school" = c(18.20, 21.31, 24.15, 26.44),
                                                            "More than high school" = c(72.79, 66.33, 59.76, 54.17))),
  "Smoking, (%)"                = list(p = "<0.001", lv = list("Ever" = c(36.91, 43.59, 46.87, 47.93), "Never" = c(63.09, 56.41, 53.13, 52.07))),
  "Diabetes, (%)"               = list(p = "<0.001", lv = list("Yes" = c(3.01, 8.60, 14.85, 26.76), "No" = c(96.99, 91.40, 85.15, 73.24))),
  "High blood pressure, (%)"    = list(p = "<0.001", lv = list("Yes" = c(13.89, 29.05, 38.80, 52.73), "No" = c(86.11, 70.95, 61.20, 47.27))),
  "Coronary heart disease, (%)" = list(p = "<0.001", lv = list("Yes" = c(0.83, 2.23, 4.28, 7.20), "No" = c(99.17, 97.77, 95.72, 92.80))),
  "Cancer, (%)"                 = list(p = "<0.001", lv = list("Yes" = c(5.09, 9.75, 11.87, 16.89), "No" = c(94.91, 90.25, 88.13, 83.11))),
  "Stroke, (%)"                 = list(p = "<0.001", lv = list("Yes" = c(0.90, 2.00, 3.08, 5.49), "No" = c(99.10, 98.00, 96.92, 94.51)))
)
paper_n <- c(5847, 5847, 5847, 5848)

# ---- 재현 계산 ----------------------------------------------------------------
var_cont <- c("Age (years)" = "RIDAGEYR", "BMI (kg/m2)" = "BMXBMI", "Waist circumference (cm)" = "BMXWAIST", "PIR" = "INDFMPIR",
              "Weight (kg)" = "BMXWT", "Average alcohol consumption past 12 months" = "alcohol", "Triglycerides (mg/dL)" = "LBXTR",
              "HDL-C (mg/dL)" = "LBDHDD", "LDL-C (mg/dL)" = "LBDLDL", "Total cholesterol (mg/dL)" = "LBXTC")
var_cat  <- c("Sex, (%)" = "sex", "Race/ethnicity, (%)" = "race", "Education level, (%)" = "educ", "Smoking, (%)" = "smoking",
              "Diabetes, (%)" = "diabetes", "High blood pressure, (%)" = "htn", "Coronary heart disease, (%)" = "chd",
              "Cancer, (%)" = "cancer", "Stroke, (%)" = "stroke_f")
fmt_p <- function(p) ifelse(p < 0.001, "<0.001", sprintf("%.3f", p))
rows <- list()
add <- function(...) rows[[length(rows) + 1]] <<- data.frame(..., stringsAsFactors = FALSE)

# N
for (q in 1:4) add(section = "N", row = "N", level = "", col = paste0("Q", q), type = "n", repro = as.numeric(table(dat$WWI_q)[q]), repro_sd = NA, paper = paper_n[q], paper_sd = NA, p_repro = "", p_paper = "")

# p_method: "design" = 설계기반(층·군집·가중) F검정 — 올바른 방법
#           "lm"     = 단순 가중회귀 lm(weights = w) F검정 — 06 검정 F 에서 논문이 쓴 방식으로 확인 (음주량 P 0.187 일치)
cont_stat <- function(v, p_method = "design") {
  f <- as.formula(paste0("~", v)); d <- subset(des, !is.na(dat[[v]]))
  p <- if (p_method == "lm") anova(lm(as.formula(paste0(v, " ~ WWI_q")), data = dat, weights = wt))$`Pr(>F)`[1]
       else regTermTest(svyglm(as.formula(paste0(v, " ~ WWI_q")), d), ~WWI_q)$p
  list(m = svyby(f, ~WWI_q, d, svymean)[, 2], s = sqrt(svyby(f, ~WWI_q, d, svyvar)[, 2]), p = p)
}
cat_stat <- function(v) {
  d <- subset(des, !is.na(dat[[v]])); tb <- svytable(as.formula(paste0("~", v, " + WWI_q")), d)
  list(pct = prop.table(tb, 2) * 100, p = svychisq(as.formula(paste0("~", v, " + WWI_q")), d)$p.value)
}

order_rows <- c("Age (years)", names(var_cat), setdiff(names(var_cont), "Age (years)"))
for (lab in order_rows) {
  if (lab %in% names(var_cont)) {
    st <- cont_stat(var_cont[[lab]]); pp <- paper_cont[[lab]]
    for (q in 1:4) add(section = lab, row = lab, level = "", col = paste0("Q", q), type = "cont", repro = st$m[q], repro_sd = st$s[q],
                       paper = pp$m[q], paper_sd = pp$s[q], p_repro = fmt_p(st$p), p_paper = pp$p)
  } else {
    st <- cat_stat(var_cat[[lab]]); pp <- paper_cat[[lab]]
    for (lv in names(pp$lv)) for (q in 1:4)
      add(section = lab, row = lab, level = lv, col = paste0("Q", q), type = "cat", repro = st$pct[lv, q], repro_sd = NA,
          paper = pp$lv[[lv]][q], paper_sd = NA, p_repro = fmt_p(st$p), p_paper = pp$p)
  }
}
# 참고 행: 음주량을 코드값(777/999) 정리 없이 계산 (논문 방식 재현)
st <- cont_stat("ALQ130", p_method = "lm"); pp <- paper_cont[["Average alcohol consumption past 12 months"]]
for (q in 1:4) add(section = "Average alcohol consumption past 12 months", row = "  (참고) 777/999 코드값 유지 + 단순가중회귀 P (논문 방식)", level = "", col = paste0("Q", q), type = "cont",
                   repro = st$m[q], repro_sd = st$s[q], paper = pp$m[q], paper_sd = pp$s[q], p_repro = fmt_p(st$p), p_paper = pp$p)

# 참고 행: 결측을 전체 평균으로 대치 (논문 방식 재현) — 검정 B·D 에서 확인된 5개 변수
for (v in c("PIR", "Triglycerides (mg/dL)", "HDL-C (mg/dL)", "LDL-C (mg/dL)", "Total cholesterol (mg/dL)")) {
  st <- cont_stat(paste0(var_cont[[v]], "_imp"), p_method = "lm"); pp <- paper_cont[[v]]
  for (q in 1:4) add(section = v, row = "  (참고) 결측 평균 대치 + 단순가중회귀 P (논문 방식)", level = "", col = paste0("Q", q), type = "cont",
                     repro = st$m[q], repro_sd = st$s[q], paper = pp$m[q], paper_sd = pp$s[q], p_repro = fmt_p(st$p), p_paper = pp$p)
}

cmp <- bind_rows(rows) |> mutate(diff = repro - paper, diff_sd = repro_sd - paper_sd)
write.csv(cmp, file.path(proj_dir, "data", "table1_comparison.csv"), row.names = FALSE)

# ---- 요약 ---------------------------------------------------------------------
tol <- 0.1
cmp <- cmp |> mutate(flag = case_when(abs(diff) <= tol & (is.na(diff_sd) | abs(diff_sd) <= tol) ~ "match",
                                      abs(diff) <= 1 & (is.na(diff_sd) | abs(diff_sd) <= 1) ~ "minor", TRUE ~ "diff"))
cat("셀 판정 요약 (허용오차 ±0.1 = 일치, ±1 = 근소, 그 이상 = 차이):\n"); print(table(cmp$flag))
cat("\n'차이' 셀:\n"); print(cmp |> filter(flag == "diff") |> select(row, level, col, repro, paper, diff, repro_sd, paper_sd), row.names = FALSE, digits = 4)
cat("\n저장: data/table1_comparison.csv\n")
