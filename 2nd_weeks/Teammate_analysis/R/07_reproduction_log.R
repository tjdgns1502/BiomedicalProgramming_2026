# =============================================================================
# 07_reproduction_log.R — 발표용 재현 기록의 근거 숫자를 다시 계산한다
#   (1) v0  = 세션 최초 코드 상태를 복원:  MEC 가중치 + CDC 재조정, 경계성 당뇨 → 없음,
#             사분위 (a, b] (right = TRUE), 결측 대치 없음, 음주 777/999 → NA
#   (2) vF  = 최종 상태 (data/analysis_wwi_stroke.rds 의 규칙: 설문 원가중치, 경계성 → 있음, [a, b), *_imp 대치)
#   (3) 되돌리기 검증: 최종 상태에서 가중치만 MEC 원가중치로 되돌리면 오차가 얼마나 되돌아오는가
#   출력: data/reproduction_log.json
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(dplyr); library(survey); library(jsonlite) })
proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
dat <- readRDS(file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))

# ---- 논문 Table 1 -----------------------------------------------------------
paper_cont <- list(
  "Age (years)"                   = list(m = c(37.06, 46.33, 51.74, 57.47), s = c(13.45, 15.05, 15.90, 16.14)),
  "BMI (kg/m2)"                   = list(m = c(24.96, 28.32, 30.67, 34.22), s = c(4.70, 5.32, 6.37, 7.82)),
  "Waist circumference (cm)"      = list(m = c(86.09, 97.24, 104.79, 115.34), s = c(10.56, 11.61, 13.19, 16.13)),
  "PIR"                           = list(m = c(3.08, 3.14, 2.96, 2.61), s = c(1.62, 1.59, 1.60, 1.52)),
  "Weight (kg)"                   = list(m = c(74.70, 82.06, 86.29, 91.65), s = c(16.85, 19.41, 21.81, 25.21)),
  "Alcohol (drinks/day)"          = list(m = c(3.24, 4.29, 2.99, 3.33), s = c(18.67, 39.96, 20.49, 29.64)),
  "Triglycerides (mg/dL)"         = list(m = c(107.49, 117.45, 124.53, 126.97), s = c(63.03, 67.70, 80.28, 61.62)),
  "HDL-C (mg/dL)"                 = list(m = c(57.27, 54.00, 52.22, 51.20), s = c(16.23, 16.65, 16.84, 14.41)),
  "LDL-C (mg/dL)"                 = list(m = c(109.30, 113.27, 113.47, 111.61), s = c(22.37, 23.74, 24.32, 24.87)),
  "Total cholesterol (mg/dL)"     = list(m = c(183.55, 194.32, 196.08, 192.35), s = c(37.46, 39.38, 42.12, 42.86)))
paper_cat <- list(
  "Sex" = list("Male" = c(59.02, 52.33, 46.07, 32.29), "Female" = c(40.98, 47.67, 53.93, 67.71)),
  "Race/ethnicity" = list("Non-Hispanic White" = c(64.39, 64.73, 64.07, 67.08), "Non-Hispanic Black" = c(14.97, 10.25, 10.01, 9.27),
                          "Mexican American" = c(5.58, 8.57, 10.60, 9.91), "Other race/multiracial" = c(15.06, 16.45, 15.32, 13.74)),
  "Education level" = list("Less than high school" = c(9.01, 12.32, 16.07, 19.36), "High school" = c(18.20, 21.31, 24.15, 26.44), "More than high school" = c(72.79, 66.33, 59.76, 54.17)),
  "Smoking" = list("Ever" = c(36.91, 43.59, 46.87, 47.93), "Never" = c(63.09, 56.41, 53.13, 52.07)),
  "Diabetes" = list("Yes" = c(3.01, 8.60, 14.85, 26.76), "No" = c(96.99, 91.40, 85.15, 73.24)),
  "High blood pressure" = list("Yes" = c(13.89, 29.05, 38.80, 52.73), "No" = c(86.11, 70.95, 61.20, 47.27)),
  "Coronary heart disease" = list("Yes" = c(0.83, 2.23, 4.28, 7.20), "No" = c(99.17, 97.77, 95.72, 92.80)),
  "Cancer" = list("Yes" = c(5.09, 9.75, 11.87, 16.89), "No" = c(94.91, 90.25, 88.13, 83.11)),
  "Stroke" = list("Yes" = c(0.90, 2.00, 3.08, 5.49), "No" = c(99.10, 98.00, 96.92, 94.51)))
paper_n <- c(5847, 5847, 5847, 5848)
var_cont <- c("Age (years)" = "RIDAGEYR", "BMI (kg/m2)" = "BMXBMI", "Waist circumference (cm)" = "BMXWAIST", "PIR" = "INDFMPIR",
              "Weight (kg)" = "BMXWT", "Alcohol (drinks/day)" = "alcohol", "Triglycerides (mg/dL)" = "LBXTR",
              "HDL-C (mg/dL)" = "LBDHDD", "LDL-C (mg/dL)" = "LBDLDL", "Total cholesterol (mg/dL)" = "LBXTC")
var_cat <- c("Sex" = "sex", "Race/ethnicity" = "race", "Education level" = "educ", "Smoking" = "smoking", "Diabetes" = "diabetes",
             "High blood pressure" = "htn", "Coronary heart disease" = "chd", "Cancer" = "cancer", "Stroke" = "stroke_f")

# ---- 한 구성(configuration)에 대해 132 셀을 계산 ------------------------------
compute_cells <- function(d, wcol, cont_map) {
  d$stroke_f <- factor(d$stroke, 0:1, c("No", "Yes"))
  des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = as.formula(paste0("~", wcol)), nest = TRUE, data = d)
  rows <- list(); add <- function(...) rows[[length(rows) + 1]] <<- data.frame(..., stringsAsFactors = FALSE)
  nq <- as.numeric(table(d$WWI_q))
  for (q in 1:4) add(row = "N", level = "", col = paste0("Q", q), type = "n", repro = nq[q], repro_sd = NA, paper = paper_n[q], paper_sd = NA)
  for (lab in names(var_cont)) {
    v <- cont_map[[lab]]; f <- as.formula(paste0("~", v)); dd <- subset(des, !is.na(d[[v]]))
    m <- svyby(f, ~WWI_q, dd, svymean)[, 2]; s <- sqrt(svyby(f, ~WWI_q, dd, svyvar)[, 2]); pp <- paper_cont[[lab]]
    for (q in 1:4) add(row = lab, level = "", col = paste0("Q", q), type = "cont", repro = m[q], repro_sd = s[q], paper = pp$m[q], paper_sd = pp$s[q])
  }
  for (lab in names(var_cat)) {
    v <- var_cat[[lab]]; dd <- subset(des, !is.na(d[[v]])); tb <- prop.table(svytable(as.formula(paste0("~", v, " + WWI_q")), dd), 2) * 100
    for (lv in names(paper_cat[[lab]])) for (q in 1:4)
      add(row = lab, level = lv, col = paste0("Q", q), type = "cat", repro = tb[lv, q], repro_sd = NA, paper = paper_cat[[lab]][[lv]][q], paper_sd = NA)
  }
  out <- bind_rows(rows) |> mutate(abs_err = abs(repro - paper), rel_err = 100 * abs_err / abs(paper),
                                   abs_err_sd = abs(repro_sd - paper_sd), rel_err_sd = 100 * abs_err_sd / abs(paper_sd),
                                   worst = pmax(abs_err, ifelse(is.na(abs_err_sd), 0, abs_err_sd)),
                                   grade = ifelse(worst <= 0.1, "O", ifelse(worst <= 1, "△", "X")))
  out
}
score9 <- function(cells) {  # 06 검정 A 와 같은 정의: 7개 연속변수 + 교육 + 뇌졸중 의 Σ|Δ| (평균+SD / %)
  c9 <- cells |> filter(row %in% c("Age (years)", "BMI (kg/m2)", "Waist circumference (cm)", "Weight (kg)", "PIR", "HDL-C (mg/dL)", "Total cholesterol (mg/dL)") |
                        (row == "Education level") | (row == "Stroke" & level == "Yes"))
  sum(c9$abs_err) + sum(c9$abs_err_sd, na.rm = TRUE)
}

# ---- v0: 최초 상태 복원 --------------------------------------------------------
v0 <- dat
v0$diabetes <- factor(case_when(v0$DIQ010 == 1 ~ "Yes", v0$DIQ010 %in% c(2, 3) ~ "No", TRUE ~ NA_character_))
q_cut <- quantile(v0$WWI, c(.25, .5, .75)); v0$WWI_q <- cut(v0$WWI, c(-Inf, q_cut, Inf), labels = paste0("Q", 1:4), right = TRUE)
cells_v0 <- compute_cells(v0, "wt_mec_cdc", var_cont)

# ---- vF: 최종 상태 (본행 = 올바른 처리, 참고행 = 논문 방식) ------------------
cells_vF_main <- compute_cells(dat, "wt", var_cont)
cont_paper <- var_cont; for (v in c("PIR", "Triglycerides (mg/dL)", "HDL-C (mg/dL)", "LDL-C (mg/dL)", "Total cholesterol (mg/dL)")) cont_paper[[v]] <- paste0(var_cont[[v]], "_imp")
cont_paper[["Alcohol (drinks/day)"]] <- "ALQ130"
cells_vF_paper <- compute_cells(dat, "wt", cont_paper)

# ---- 되돌리기 검증: 결정적 변경(설문 원가중치)만 MEC 원가중치로 되돌림 ------------
cells_revert <- compute_cells(dat, "wt_mec_raw", cont_paper)
cells_revert_cdc <- compute_cells(dat, "wt_mec_cdc", cont_paper)

summ <- function(cells, nm) data.frame(config = nm, O = sum(cells$grade == "O"), tri = sum(cells$grade == "△"), X = sum(cells$grade == "X"),
                                       score9 = round(score9(cells), 2), sum_abs_err = round(sum(cells$abs_err) + sum(cells$abs_err_sd, na.rm = TRUE), 2))
summary_tbl <- bind_rows(summ(cells_v0, "v0 최초 (MEC+CDC 재조정, 경계성→없음, (a,b], 대치 없음)"),
                         summ(cells_vF_main, "vF 최종 본행 (설문 원가중치, 올바른 결측·코드 처리)"),
                         summ(cells_vF_paper, "vF 최종 논문방식 (설문 원가중치 + 평균 대치 + 코드 유지)"),
                         summ(cells_revert, "되돌리기: 논문방식에서 가중치만 MEC 원가중치로"),
                         summ(cells_revert_cdc, "되돌리기: 논문방식에서 가중치만 MEC + CDC 재조정으로"))
print(summary_tbl, row.names = FALSE)

# 음주 참고행의 P (논문 방식 vs 설계기반), 최종 상태
des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt, nest = TRUE, data = dat)
r <- dat[!is.na(dat$ALQ130), ]
p_alc <- list(lm_int = anova(lm(ALQ130 ~ WWI_q, r, weights = wt))$`Pr(>F)`[1],
              design_int = regTermTest(svyglm(ALQ130 ~ WWI_q, subset(des, !is.na(ALQ130))), ~WWI_q)$p,
              lm_mec_raw = anova(lm(ALQ130 ~ WWI_q, r, weights = wt_mec_raw))$`Pr(>F)`[1])

write_json(list(summary = summary_tbl, v0 = cells_v0, vF_main = cells_vF_main, vF_paper = cells_vF_paper, revert = cells_revert, p_alc = p_alc),
           file.path(proj_dir, "data", "reproduction_log.json"), digits = 6, pretty = TRUE, na = "null")
cat("\n저장: data/reproduction_log.json\n")
