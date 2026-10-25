# =============================================================================
# 02_preprocess.R
# 논문 Fig.1 (제외 단계) 재현, WWI 계산, 사분위 절단, 분포 진단(왜도·Shapiro-Wilk·Levene)
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(dplyr); library(survey); library(moments); library(car) })

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
raw_dir  <- file.path(proj_dir, "data", "raw")
rd <- function(nm) readRDS(file.path(raw_dir, paste0(nm, ".rds")))

# ---- 1. 주기별 표 결합 ------------------------------------------------------
cyc <- list(G = "_G", H = "_H", I = "_I", P = "P_")
nm_of <- function(tb, cy) if (cy == "P") paste0("P_", tb) else paste0(tb, cyc[[cy]])

pick <- function(df, vars) { miss <- setdiff(vars, names(df)); for (m in miss) df[[m]] <- NA; df[, vars] }

merged <- lapply(names(cyc), function(cy) {
  demo <- pick(rd(nm_of("DEMO", cy)),  c("SEQN","RIDAGEYR","RIAGENDR","RIDRETH3","DMDEDUC2","INDFMPIR","SDMVPSU","SDMVSTRA","WTMEC2YR","WTINT2YR"))
  bmx  <- pick(rd(nm_of("BMX", cy)),   c("SEQN","BMXWT","BMXWAIST","BMXBMI"))
  mcq  <- pick(rd(nm_of("MCQ", cy)),   c("SEQN","MCQ160F","MCQ160C","MCQ220"))
  diq  <- pick(rd(nm_of("DIQ", cy)),   c("SEQN","DIQ010"))
  bpq  <- pick(rd(nm_of("BPQ", cy)),   c("SEQN","BPQ020"))
  smq  <- pick(rd(nm_of("SMQ", cy)),   c("SEQN","SMQ020"))
  alq  <- pick(rd(nm_of("ALQ", cy)),   c("SEQN","ALQ130"))
  tg   <- pick(rd(nm_of("TRIGLY", cy)),c("SEQN","LBXTR","LBDLDL","WTSAF2YR"))
  hdl  <- pick(rd(nm_of("HDL", cy)),   c("SEQN","LBDHDD"))
  tc   <- pick(rd(nm_of("TCHOL", cy)), c("SEQN","LBXTC"))
  out <- Reduce(function(a, b) left_join(a, b, by = "SEQN"), list(demo, bmx, mcq, diq, bpq, smq, alq, tg, hdl, tc))
  out$cycle <- cy
  out
}) |> bind_rows()

# ---- 2. 논문 Fig.1 제외 단계 재현 -------------------------------------------
flow <- data.frame(step = "NHANES 2011-2020 초기 인원", n = nrow(merged), paper = 45462)
d1 <- merged |> filter(!is.na(BMXWT));    flow <- rbind(flow, data.frame(step = "체중(BMXWT) 결측 제외",       n = nrow(d1), paper = 45462 - 2976))
d2 <- d1     |> filter(!is.na(BMXWAIST)); flow <- rbind(flow, data.frame(step = "허리둘레(BMXWAIST) 결측 제외", n = nrow(d2), paper = 45462 - 2976 - 4767))
# 주의: MCQ160F 는 20세 이상에게만 질문하므로 결측(NA) 14,330명은 거의 전부 20세 미만이다.
#       "모름(9)" 22명은 논문이 제외하지 않았다(23,389 = 893 예 + 22,474 아니오 + 22 모름).
#       논문과 동일하게 맞추기 위해 9 는 남기고 뇌졸중 = 0 으로 처리한다.
d3 <- d2     |> filter(!is.na(MCQ160F)); flow <- rbind(flow, data.frame(step = "뇌졸중(MCQ160F) 결측 제외", n = nrow(d3), paper = 23389))
flow$excluded <- c(NA, -diff(flow$n)); flow$paper_excluded <- c(NA, 2976, 4767, 14330)
cat("\n==== Fig.1 제외 단계 대조 ====\n"); print(flow, row.names = FALSE)

# ---- 3. 변수 정의 -------------------------------------------------------------
# 가중치. NHANES 에는 두 종류가 있다: 설문 가중치(WTINT2YR / P: WTINTPRP), 검진 가중치(WTMEC2YR / P: WTMECPRP).
#   체중·허리둘레는 검진(MEC) 자료이므로 원칙은 MEC 가중치이고, 4개 주기(9.2년)를 합치면 CDC 지침대로
#   2011-2016 × (2/9.2), 2017-Mar2020 × (3.2/9.2) 로 재조정해야 한다.
#   그러나 06_diagnose_discrepancies.R 검정 A·I 에서 논문 Table 1 은 **설문 가중치를 재조정 없이 그대로** 쓴 것이
#   확인됐다 (전체 132셀 점수 13.5 → 1.0, 음주량 행 소수 둘째 자리까지 일치).
#   weight_mode: "paper" = 설문 원가중치 (논문 재현용, 기본값) / "cdc" = MEC 가중치 CDC 재조정 (올바른 실무)
weight_mode <- "paper"
p_demo <- rd("P_DEMO")[, c("SEQN", "WTMECPRP", "WTINTPRP")]
dat <- d3 |>
  left_join(p_demo, by = "SEQN") |>
  mutate(
    wt_mec_raw = ifelse(cycle == "P", WTMECPRP, WTMEC2YR),
    wt_int_raw = ifelse(cycle == "P", WTINTPRP, WTINT2YR),
    wt_mec_cdc = ifelse(cycle == "P", WTMECPRP * (3.2 / 9.2), WTMEC2YR * (2 / 9.2)),
    wt         = if (weight_mode == "paper") wt_int_raw else wt_mec_cdc,      # 이후 모든 분석이 쓰는 가중치
    WWI    = BMXWAIST / sqrt(BMXWT),                                    # 논문 식: WC(cm)/√weight(kg)
    stroke = ifelse(MCQ160F == 1, 1L, 0L),
    sex    = factor(RIAGENDR, 1:2, c("Male", "Female")),
    race   = factor(case_when(RIDRETH3 == 3 ~ "Non-Hispanic White", RIDRETH3 == 4 ~ "Non-Hispanic Black",
                              RIDRETH3 == 1 ~ "Mexican American", TRUE ~ "Other race/multiracial"),
                    levels = c("Non-Hispanic White","Non-Hispanic Black","Mexican American","Other race/multiracial")),
    educ   = factor(case_when(DMDEDUC2 %in% 1:2 ~ "Less than high school", DMDEDUC2 == 3 ~ "High school",
                              DMDEDUC2 %in% 4:5 ~ "More than high school", TRUE ~ NA_character_),
                    levels = c("Less than high school","High school","More than high school")),
    smoking  = factor(case_when(SMQ020 == 1 ~ "Ever", SMQ020 == 2 ~ "Never", TRUE ~ NA_character_)),
    # DIQ010: 1=Yes, 2=No, 3=Borderline. 경계성을 "Yes"로 세어야 논문 Table 1 (Q1 3.01%, Q4 26.76%) 과 일치함
    diabetes = factor(case_when(DIQ010 %in% c(1, 3) ~ "Yes", DIQ010 == 2 ~ "No", TRUE ~ NA_character_)),
    htn      = factor(case_when(BPQ020 == 1 ~ "Yes", BPQ020 == 2 ~ "No", TRUE ~ NA_character_)),
    chd      = factor(case_when(MCQ160C == 1 ~ "Yes", MCQ160C == 2 ~ "No", TRUE ~ NA_character_)),
    cancer   = factor(case_when(MCQ220 == 1 ~ "Yes", MCQ220 == 2 ~ "No", TRUE ~ NA_character_)),
    alcohol  = ifelse(ALQ130 %in% c(777, 999), NA, ALQ130)
  )

# 사분위: 논문 절단점 10.51 / 11.09 / 11.67 과 비교
q_cut <- quantile(dat$WWI, c(.25, .5, .75), na.rm = TRUE)
cat("\n==== WWI 사분위 절단점 ====\n비가중 표본 사분위수: "); print(round(q_cut, 2))
cat("논문 절단점: 10.51 / 11.09 / 11.67\n")
# right = FALSE: 구간을 [a, b) 로 잘라야 절단점과 정확히 같은 값(각 1명)이 위 그룹으로 가서
#                논문의 5,847 / 5,847 / 5,847 / 5,848 과 일치한다.
dat$WWI_q <- cut(dat$WWI, c(-Inf, q_cut, Inf), labels = paste0("Q", 1:4), right = FALSE)
cat("사분위별 n: "); print(table(dat$WWI_q))

# 06_diagnose_discrepancies.R 검정 B·D 에서 논문 Table 1 이 결측이 있는 연속형 공변량(중성지방·LDL 54%,
# PIR 10%, HDL·총콜레스테롤 5%)을 전체 평균으로 대치한 것이 확인됨 (SD 축소 배율 √(관측비율) 이 이론값과 일치).
# 음주량은 대치하지 않았음. 원자료는 그대로 두고, 논문 방식 재현용 열(*_imp)을 따로 만든다. 회귀분석에는 원자료를 쓴다.
for (v in c("LBXTR", "LBDLDL", "INDFMPIR", "LBDHDD", "LBXTC"))
  dat[[paste0(v, "_imp")]] <- ifelse(is.na(dat[[v]]), mean(dat[[v]], na.rm = TRUE), dat[[v]])
cat("전체 WWI mean ± SD (비가중): ", round(mean(dat$WWI), 2), "±", round(sd(dat$WWI), 2), " (논문 11.09 ± 0.86)\n")
cat("뇌졸중 유병 (비가중): ", sum(dat$stroke), "/", nrow(dat), "=", round(100 * mean(dat$stroke), 2), "% (논문 893, 3.82%)\n")
cat("나이 mean ± SD (비가중): ", round(mean(dat$RIDAGEYR), 2), "±", round(sd(dat$RIDAGEYR), 2), " (논문 49.32 ± 17.42)\n")
cat("성별 남/여: "); print(table(dat$sex)); cat("(논문 11,409 / 11,980)\n")

# ---- 4. 분포 진단: 왜도, Shapiro-Wilk, Levene -------------------------------
cont_vars <- c("RIDAGEYR","WWI","BMXBMI","BMXWAIST","BMXWT","INDFMPIR","alcohol","LBXTR","LBDHDD","LBDLDL","LBXTC")
set.seed(2026)
diag <- lapply(cont_vars, function(v) {
  x <- dat[[v]]; x <- x[!is.na(x)]
  xs <- if (length(x) > 5000) sample(x, 5000) else x          # shapiro.test 는 n ≤ 5000 제한
  pos <- x[x > 0]
  data.frame(variable = v, n = length(x),
             mean = mean(x), sd = sd(x), median = median(x), IQR = IQR(x),
             skew_raw = skewness(x), kurt_raw = kurtosis(x) - 3,
             sw_W_raw = shapiro.test(xs)$statistic, sw_p_raw = shapiro.test(xs)$p.value,
             skew_log = if (length(pos) > 3) skewness(log(pos)) else NA,
             sw_W_log = if (length(pos) > 3) shapiro.test(if (length(pos) > 5000) sample(log(pos), 5000) else log(pos))$statistic else NA,
             n_zero_or_neg = sum(x <= 0))
}) |> bind_rows()
cat("\n==== 연속변수 분포 진단 (원자료 vs 로그변환) ====\n"); print(diag, digits = 3, row.names = FALSE)

# Levene: 사분위군 간 등분산 (원자료 vs 로그)
lev <- lapply(c("LBXTR","alcohol","BMXBMI","WWI"), function(v) {
  sub <- dat[!is.na(dat[[v]]) & dat[[v]] > 0, ]
  data.frame(variable = v,
             levene_p_raw = leveneTest(sub[[v]] ~ sub$WWI_q)$`Pr(>F)`[1],
             levene_p_log = leveneTest(log(sub[[v]]) ~ sub$WWI_q)$`Pr(>F)`[1])
}) |> bind_rows()
cat("\n==== Levene 등분산 검정 (WWI 사분위군 간) ====\n"); print(lev, digits = 3, row.names = FALSE)

# ---- 5. 복합표본 설계 & 가중 Table 1 일부 -----------------------------------
des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt, nest = TRUE, data = dat)
cat("\n==== 가중(svy) vs 비가중 비교 ====\n")
w_age  <- svyby(~RIDAGEYR, ~WWI_q, des, svymean); u_age <- tapply(dat$RIDAGEYR, dat$WWI_q, mean)
cmp <- data.frame(Q = levels(dat$WWI_q), age_unweighted = round(u_age, 2), age_weighted = round(w_age$RIDAGEYR, 2),
                  paper = c(37.06, 46.33, 51.74, 57.47))
print(cmp, row.names = FALSE)
w_stroke <- svyby(~stroke, ~WWI_q, des, svymean); u_stroke <- tapply(dat$stroke, dat$WWI_q, mean)
cmp2 <- data.frame(Q = levels(dat$WWI_q), stroke_unweighted_pct = round(100 * u_stroke, 2),
                   stroke_weighted_pct = round(100 * w_stroke$stroke, 2), paper = c(0.90, 2.00, 3.08, 5.49))
print(cmp2, row.names = FALSE)

# 가중 카이제곱 (Rao-Scott) & 가중 선형회귀 p — Table 1 의 P value 방식
cat("\nRao-Scott χ² (stroke ~ WWI_q) p =", format.pval(svychisq(~stroke + WWI_q, des)$p.value, digits = 3), "\n")
cat("가중 선형회귀 (age ~ WWI_q) F-test p =", format.pval(regTermTest(svyglm(RIDAGEYR ~ WWI_q, des), ~WWI_q)$p, digits = 3), "\n")

# ---- 6. 로지스틱 회귀 Model 1 (crude) ---------------------------------------
m1 <- svyglm(stroke ~ WWI, des, family = quasibinomial())
ci <- exp(confint(m1))["WWI", ]
cat("\nModel 1 (가중, 미보정) OR per 1 unit WWI =", round(exp(coef(m1)["WWI"]), 2),
    " 95% CI", round(ci[1], 2), "-", round(ci[2], 2), "  (논문 1.94 (1.79, 2.10))\n")
m1u <- glm(stroke ~ WWI, dat, family = binomial())
cat("Model 1 (비가중) OR =", round(exp(coef(m1u)["WWI"]), 2), "\n")

# ---- 저장 ---------------------------------------------------------------------
saveRDS(dat, file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))
write.csv(dat, file.path(proj_dir, "data", "analysis_wwi_stroke.csv"), row.names = FALSE)
write.csv(flow, file.path(proj_dir, "data", "flowchart_check.csv"), row.names = FALSE)
write.csv(diag, file.path(proj_dir, "data", "distribution_diagnostics.csv"), row.names = FALSE)
cat("\n저장 완료: data/analysis_wwi_stroke.(rds|csv), flowchart_check.csv, distribution_diagnostics.csv\n")
