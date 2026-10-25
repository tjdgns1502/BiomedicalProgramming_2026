# templates/*.md 의 자리표시자를 검토된 run 표에서 채워 docs/learning/ 에 쓴다. 통계를 다시 계산하지 않는다.
# 사용법 (작업 디렉터리 = 6th_project/analysis): Rscript src/10_render_docs.R
#   {{v:<표>|<선택자>|<열>|<자릿수>}}  값 하나 (선택자: Apple/Fitbit/Samsung/Alpha 또는 열=값, 쉼표로 여러 개)
#   {{n:<표>|<선택자>}}                조건에 맞는 행 수
#   {{t:<이름>}}                       미리 정의한 표
#   {{f:<F1..F7>}}                     그림 링크
#   {{meta:<키>}}                      실행 메타데이터
suppressPackageStartupMessages({ library(jsonlite); library(digest) })

RUN_MAIN <- "R1-20261025"; RUN_CAND <- "R2-20261025"
DOCS <- file.path("..", "docs", "learning")
DEV <- c(Apple = "Apple Watch", Fitbit = "Fitbit Charge HR", Samsung = "Samsung Gear S", Alpha = "Mio Alpha")

table_path <- function(name) {
  for (r in c(RUN_MAIN, RUN_CAND)) {
    p <- file.path("runs", r, "tables", paste0(name, ".csv"))
    if (file.exists(p)) return(p)
  }
  stop("표 없음: ", name)
}
tables <- new.env()
get_table <- function(name) {
  if (is.null(tables[[name]])) tables[[name]] <- read.csv(table_path(name), stringsAsFactors = FALSE, encoding = "UTF-8")
  tables[[name]]
}

select_rows <- function(d, sel) {
  keep <- rep(TRUE, nrow(d))
  for (tok in strsplit(sel, ",")[[1]]) {
    if (grepl("=", tok)) {
      kv <- strsplit(tok, "=")[[1]]
      keep <- keep & as.character(d[[kv[1]]]) == kv[2]
    } else {
      keep <- keep & d$device == DEV[[tok]]
    }
  }
  d[keep, , drop = FALSE]
}

fmt <- function(x, digits) {
  if (is.logical(x)) return(if (x) "예" else "아니오")
  if (!is.numeric(x)) return(as.character(x))
  if (digits == "p") return(if (x < 0.001) "< 0.001" else formatC(x, format = "f", digits = 3))
  if (digits == "int") return(formatC(x, format = "d"))
  formatC(x, format = "f", digits = as.integer(digits))
}

f2 <- function(x, d = 2) formatC(x, format = "f", digits = d)
ci <- function(lo, hi, d = 2) paste0("[", f2(lo, d), ", ", f2(hi, d), "]")

md_table <- function(df) {
  esc <- function(x) gsub("|", "\\|", as.character(x), fixed = TRUE)
  paste(c(paste0("| ", paste(names(df), collapse = " | "), " |"),
          paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
          apply(df, 1, function(r) paste0("| ", paste(esc(r), collapse = " | "), " |"))),
        collapse = "\n")
}

FIG <- c(F1 = "F1_scatter_ols_identity.png", F2 = "F2_error_histogram.png",
         F3 = "F3_bland_altman_fixed_loa.png", F4 = "F4_correlation_vs_agreement.png",
         F5 = "F5_residual_vs_fitted.png", F6 = "F6_residual_qq.png", F7 = "F7_cooks_distance.png")
FIG_CAP <- c(F1 = "F1. ECG(x)와 시계(y) 산점도, OLS 회귀선과 평균반응 95% CI 띠, y = x 기준선 (기기별 n = 22)",
             F2 = "F2. 측정오차(시계 − ECG) 히스토그램, 실선 0, 점선 평균오차 (기기별 n = 22)",
             F3 = "F3. Bland–Altman 그림, 실선 bias, 점선 고정 95% LoA (분석자 계산)",
             F4 = "F4. 상관(r, 95% CI)과 일치(평균오차 95% CI, 고정 LoA)의 병치",
             F5 = "F5. OLS 잔차 대 적합값 (잔차 ≠ 측정오차)",
             F6 = "F6. 표준화 OLS 잔차의 정규 Q–Q",
             F7 = "F7. 참가자별 Cook's distance, 점선 4/n (경험칙)")

named_table <- function(name) {
  switch(name,
    pairs_sample = {
      d <- get_table("hr01_pairs_88"); d <- d[d$id %in% 1:2, ]
      md_table(data.frame(pair_id = d$pair_id, 기기 = d$device, trial = d$trial,
        `시계 셀` = d$cell_device, `xlsx 저장 문자열` = d$xml_text_device, `시계 HR` = f2(d$device_hr),
        `ECG 셀` = d$cell_ecg, `ECG 헤더` = d$header_ecg, `ECG HR` = f2(d$ecg_hr), `오차` = f2(d$error),
        check.names = FALSE))
    },
    column_map = md_table(data.frame(
      기기 = unname(DEV), `시계 열` = c("B", "E", "H", "K"), `ECG 열` = c("C", "F", "I", "L"),
      `trial 열` = c("D", "G", "J", "M"),
      `원래 헤더(시계 / ECG / trial)` = c("Apple_device / Apple_ECG / Trial_number",
        "Fitbit_device / **Fitbit_metamax** / Trial_number", "Samsung_device / Samsung_ECG / Trial_number",
        "Alpha_device / Alpha_ECG / Trial_number"),
      `Key 정의(ECG 열)` = c("Key 73행: ECG HR", "Key 76행: ECG HR", "Key 79행: ECG HR", "Key 82행: ECG HR"),
      check.names = FALSE)),
    qa_checks = {
      d <- get_table("hr01_qa_checks")
      md_table(data.frame(점검 = d$check, 결과 = ifelse(d$pass, "통과", "실패"), check.names = FALSE))
    },
    corr = {
      d <- get_table("hr02_correlation")
      md_table(data.frame(기기 = d$device, n = d$n, `Pearson r` = f2(d$pearson_r, 3),
        `95% CI (Fisher z)` = ci(d$pearson_lo, d$pearson_hi, 3), `p (H0: ρ=0)` = sapply(d$pearson_p, fmt, "p"),
        `Spearman ρ` = f2(d$spearman_rho, 3), `ρ 95% CI (Fisher z 근사)` = ci(d$spearman_lo_fisher, d$spearman_hi_fisher, 3),
        check.names = FALSE))
    },
    ols = {
      d <- get_table("hr03_ols")
      md_table(data.frame(기기 = d$device, n = d$n, `절편 (bpm)` = f2(d$intercept), `절편 95% CI` = ci(d$intercept_lo, d$intercept_hi),
        기울기 = f2(d$slope, 3), `기울기 95% CI` = ci(d$slope_lo, d$slope_hi, 3), `R²` = f2(d$r2, 3),
        `잔차 SE (bpm)` = f2(d$sigma), `기울기 CI에 1 포함` = ifelse(d$slope_ci_contains_1, "예", "아니오"),
        check.names = FALSE))
    },
    err = {
      d <- get_table("hr04_error")
      md_table(data.frame(기기 = d$device, n = d$n,
        `시계 평균 ± SD` = paste0(f2(d$device_mean, 1), " ± ", f2(d$device_sd, 1)),
        `ECG 평균 ± SD` = paste0(f2(d$ecg_mean, 1), " ± ", f2(d$ecg_sd, 1)),
        `평균오차(bias)` = f2(d$bias), `bias 95% CI (t)` = ci(d$bias_lo, d$bias_hi), `오차 SD` = f2(d$bias_sd),
        MAE = f2(d$mae), RMSE = f2(d$rmse), `bias/ECG 평균 (%)` = f2(d$pct_bias, 1),
        `고정 95% LoA` = ci(d$loa_lower, d$loa_upper), `음수 오차 수` = paste0(d$n_negative, "/", d$n),
        check.names = FALSE))
    },
    influential = {
      d <- get_table("hr05_diagnostics"); d <- d[d$cooks > d$cooks_ref | abs(d$std_resid) > 2, ]
      d <- d[order(match(d$device, DEV), -d$cooks), ]
      md_table(data.frame(기기 = d$device, ID = d$id, `시계 HR` = f2(d$device_hr), `ECG HR` = f2(d$ecg_hr),
        `측정오차` = f2(d$device_hr - d$ecg_hr), `OLS 잔차` = f2(d$resid), `표준화 잔차` = f2(d$std_resid),
        레버리지 = f2(d$leverage, 3), `Cook's D` = f2(d$cooks, 3), check.names = FALSE))
    },
    loo = {
      d <- get_table("hr05_loo_summary")
      lab <- c(pearson_r = "Pearson r", slope = "기울기", intercept = "절편", bias = "bias",
               bias_sd = "오차 SD", loa_lower = "LoA 하한", loa_upper = "LoA 상한")
      d <- d[d$metric %in% c("pearson_r", "slope", "bias", "loa_lower", "loa_upper"), ]
      dg <- ifelse(d$metric %in% c("pearson_r", "slope"), 3, 2)
      md_table(data.frame(기기 = d$device, 지표 = lab[d$metric],
        `전체 22명` = mapply(f2, d$full_value, dg),
        `한 명씩 제외한 21명 결과의 범위` = paste0(mapply(f2, d$loo_min, dg), " ~ ", mapply(f2, d$loo_max, dg)),
        `가장 크게 바꾼 제외 ID` = d$id_at_max_change, check.names = FALSE))
    },
    cmp = {
      d <- get_table("hr06_paper_comparison")
      lab <- c(n = "N", device_mean = "시계 평균", device_sd = "시계 SD", ecg_mean = "ECG 평균", ecg_sd = "ECG SD",
               corr = "r/ρ", corr_lo = "r/ρ CI 하한", corr_hi = "r/ρ CI 상한", bias = "평균차", bias_sd = "평균차 SD",
               loa_upper = "LoA 상한", loa_lower = "LoA 하한", icc = "ICC", corr_pearson = "Pearson r (Samsung)")
      dg <- ifelse(d$metric %in% c("corr", "corr_lo", "corr_hi", "icc", "corr_pearson"), 3, ifelse(d$metric == "n", 0, 2))
      md_table(data.frame(기기 = d$device, 항목 = lab[d$metric], 통계량 = d$statistic, `원문 표기` = d$paper_text,
        `우리 값` = ifelse(is.na(d$ours), "—", mapply(f2, d$ours, dg)),
        `차이` = ifelse(is.na(d$diff), "—", mapply(f2, d$diff, dg + 1)),
        `허용오차` = ifelse(is.na(d$tolerance) | d$verdict == "비교 불가", "—", d$tolerance),
        판정 = d$verdict, check.names = FALSE))
    },
    cand = {
      d <- get_table("hr06_rounding_candidates")
      dg <- ifelse(d$metric %in% c("corr_lo", "corr_hi"), 3, 3)
      md_table(data.frame(후보 = d$candidate, 기기 = d$device, 항목 = d$metric, 계산 = d$rule,
        `후보 값` = mapply(f2, d$candidate_value, dg), `원문 값` = d$paper_value, 판정 = d$verdict, check.names = FALSE))
    },
    stop("정의되지 않은 표: ", name))
}

meta <- function(key) {
  m <- fromJSON(file.path("runs", RUN_MAIN, "manifest.json"))
  switch(key,
    run_id = RUN_MAIN, cand_run_id = RUN_CAND, data_version = m$data_version,
    raw_sha = m$inputs[["data/raw/pone.0154420.s001.xlsx"]],
    r_version = m$r_version, finished = m$finished,
    stop("정의되지 않은 meta: ", key))
}

render_one <- function(txt) {
  rep_fun <- function(pattern, f) {
    repeat {
      m <- regmatches(txt, regexpr(pattern, txt, perl = TRUE))
      if (!length(m)) break
      txt <<- sub(m, f(m), txt, fixed = TRUE)
    }
  }
  rep_fun("\\{\\{v:[^}]+\\}\\}", function(m) {
    p <- strsplit(sub("^\\{\\{v:(.*)\\}\\}$", "\\1", m), "|", fixed = TRUE)[[1]]
    r <- select_rows(get_table(p[1]), p[2])
    if (nrow(r) != 1) stop("선택 결과가 1행이 아님: ", m)
    fmt(r[[p[3]]], p[4])
  })
  rep_fun("\\{\\{n:[^}]+\\}\\}", function(m) {
    p <- strsplit(sub("^\\{\\{n:(.*)\\}\\}$", "\\1", m), "|", fixed = TRUE)[[1]]
    as.character(nrow(select_rows(get_table(p[1]), p[2])))
  })
  rep_fun("\\{\\{t:[^}]+\\}\\}", function(m) named_table(sub("^\\{\\{t:(.*)\\}\\}$", "\\1", m)))
  rep_fun("\\{\\{f:[^}]+\\}\\}", function(m) {
    k <- sub("^\\{\\{f:(.*)\\}\\}$", "\\1", m)
    sprintf("![%s](assets/%s/%s)", FIG_CAP[[k]], RUN_MAIN, FIG[[k]])
  })
  rep_fun("\\{\\{meta:[^}]+\\}\\}", function(m) meta(sub("^\\{\\{meta:(.*)\\}\\}$", "\\1", m)))
  if (grepl("{{", txt, fixed = TRUE)) stop("채우지 못한 자리표시자가 남음")
  txt
}

# 그림 사본: 원본 경로·해시를 함께 남긴다
asset_dir <- file.path(DOCS, "assets", RUN_MAIN)
dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)
src_figs <- file.path("runs", RUN_MAIN, "figures", FIG)
invisible(file.copy(src_figs, asset_dir, overwrite = TRUE))
write_json(lapply(setNames(src_figs, FIG), function(p) list(source = p, sha256 = digest(file = p, algo = "sha256"))),
           file.path(asset_dir, "SOURCES.json"), auto_unbox = TRUE, pretty = TRUE)

for (tp in list.files("templates", pattern = "\\.md$", full.names = TRUE)) {
  txt <- paste(readLines(tp, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  out <- render_one(txt)
  header <- sprintf("<!-- 자동 생성: analysis/%s 에서 run %s / %s 표로 채움. 직접 고치지 말고 템플릿을 고칠 것. -->\n",
                    tp, RUN_MAIN, RUN_CAND)
  con <- file(file.path(DOCS, basename(tp)), open = "w", encoding = "UTF-8")
  writeLines(paste0(header, out), con); close(con)
  cat("rendered", basename(tp), "\n")
}
