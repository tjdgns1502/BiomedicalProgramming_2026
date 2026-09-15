# =============================================================================
# 04_table1.R — 논문 Table 1 재현 (복합표본 가중치 반영)
#   연속변수: 가중 평균 ± SD, P = 가중 선형회귀 (svyglm) 의 F 검정
#   범주변수: 가중 %,          P = 가중 카이제곱 (svychisq, Rao-Scott 보정)
# =============================================================================
.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages({ library(dplyr); library(survey) })

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
dat <- readRDS(file.path(proj_dir, "data", "analysis_wwi_stroke.rds"))
des <- svydesign(id = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~wt, nest = TRUE, data = dat)

fmt_p <- function(p) ifelse(p < 0.001, "<0.001", sprintf("%.3f", p))

# ---- 연속변수: 가중 평균 ± 가중 SD --------------------------------------------
cont <- c(Age = "RIDAGEYR", BMI = "BMXBMI", `Waist circumference` = "BMXWAIST", PIR = "INDFMPIR",
          Weight = "BMXWT", `Alcohol (drinks/day)` = "alcohol", Triglycerides = "LBXTR",
          `HDL-C` = "LBDHDD", `LDL-C` = "LBDLDL", `Total cholesterol` = "LBXTC")
row_cont <- function(label, v) {
  f <- as.formula(paste0("~", v)); d <- subset(des, !is.na(dat[[v]]))
  m  <- svyby(f, ~WWI_q, d, svymean)[, 2]
  sd <- sqrt(svyby(f, ~WWI_q, d, svyvar)[, 2])
  p  <- regTermTest(svyglm(as.formula(paste0(v, " ~ WWI_q")), d), ~WWI_q)$p
  data.frame(Characteristic = label, t(sprintf("%.2f ± %.2f", m, sd)), P = fmt_p(p))
}
# ---- 범주변수: 가중 % ------------------------------------------------------
cat_vars <- c(Sex = "sex", `Race/ethnicity` = "race", `Education level` = "educ", Smoking = "smoking",
              Diabetes = "diabetes", `High blood pressure` = "htn", `Coronary heart disease` = "chd",
              Cancer = "cancer", Stroke = "stroke_f")
dat$stroke_f <- factor(dat$stroke, 0:1, c("No", "Yes")); des <- update(des, stroke_f = factor(stroke, 0:1, c("No", "Yes")))
row_cat <- function(label, v) {
  d  <- subset(des, !is.na(dat[[v]]))
  tb <- svytable(as.formula(paste0("~", v, " + WWI_q")), d)
  pct <- prop.table(tb, 2) * 100
  p  <- svychisq(as.formula(paste0("~", v, " + WWI_q")), d)$p.value
  hdr <- data.frame(Characteristic = paste0(label, ", (%)"), X1 = "", X2 = "", X3 = "", X4 = "", P = fmt_p(p))
  body <- data.frame(Characteristic = paste0("  ", rownames(pct)), matrix(sprintf("%.2f", pct), ncol = 4), P = "")
  rbind(hdr, body)
}

t1 <- rbind(
  row_cont("Age (years)", "RIDAGEYR"),
  do.call(rbind, lapply(names(cat_vars), function(l) row_cat(l, cat_vars[[l]]))),
  do.call(rbind, lapply(names(cont)[-1], function(l) row_cont(l, cont[[l]])))
)
names(t1) <- c("Characteristic", paste0("Q", 1:4, " (n=", table(dat$WWI_q), ")"), "P value")
print(t1, row.names = FALSE, right = FALSE)
write.csv(t1, file.path(proj_dir, "data", "table1_reproduced.csv"), row.names = FALSE)
cat("\n저장: data/table1_reproduced.csv\n")
