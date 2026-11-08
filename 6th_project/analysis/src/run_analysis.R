# 사용법 (작업 디렉터리 = 6th_project/analysis):
#   Rscript src/run_analysis.R R1-20261025
# 이미 있는 run_id에는 쓰지 않는다 (덮어쓰기 방지).

args <- commandArgs(TRUE)
run_id <- if (length(args)) args[1] else stop("run_id를 인자로 주세요")
plan_path <- file.path("config", paste0("plan_", run_id, ".json"))
stopifnot(file.exists(plan_path))
run_dir <- file.path("runs", run_id)
if (dir.exists(run_dir)) stop("이미 존재하는 run: ", run_dir, " (덮어쓰지 않음; 새 run_id를 쓰세요)")

suppressPackageStartupMessages({ library(jsonlite); library(digest) })
for (f in c("01_build_pairs.R", "02_stats.R", "03_figures.R", "04_compare_paper.R"))
  source(file.path("src", f), encoding = "UTF-8")

started <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
plan <- fromJSON(plan_path)
sha <- function(p) digest(file = p, algo = "sha256")
raw_path <- plan$raw_input$path
if (sha(raw_path) != plan$raw_input$sha256) stop("원자료 해시가 계획과 다름: ", raw_path)

for (d in c("tables", "figures", "models", "logs", "env")) dir.create(file.path(run_dir, d), recursive = TRUE)
log_path <- file.path(run_dir, "logs", "run_log.txt")
logf <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", file = log_path, append = TRUE, sep = "")
warn <- character()

withCallingHandlers({
  logf("run ", run_id, " start; raw sha256 ok")
  pairs <- build_pairs(raw_path)
  qa <- qa_pairs(pairs)
  if (!all(qa$checks$pass)) stop("QA 실패: ", paste(qa$checks$check[!qa$checks$pass], collapse = "; "))
  logf("pairs built: ", nrow(pairs), " rows; all QA checks passed")

  # 파생자료 버전 = 쌍 CSV의 SHA-256 앞 20자리
  tmp <- tempfile(fileext = ".csv")
  write.csv(pairs, tmp, row.names = FALSE, fileEncoding = "UTF-8")
  data_version <- paste0("wallen-hr-", substr(sha(tmp), 1, 20))
  der_dir <- file.path("data", "derived", data_version)
  der_csv <- file.path(der_dir, "hr_pairs_88.csv")
  if (file.exists(der_csv)) {
    if (sha(der_csv) != sha(tmp)) stop("같은 data_version에 다른 내용: ", der_csv)
  } else {
    dir.create(der_dir, recursive = TRUE, showWarnings = FALSE)
    file.copy(tmp, der_csv)
  }
  logf("data_version ", data_version)

  tab <- function(x, name) write.csv(x, file.path(run_dir, "tables", name), row.names = FALSE, fileEncoding = "UTF-8")
  file.copy(der_csv, file.path(run_dir, "tables", "hr01_pairs_88.csv"))
  tab(qa$checks, "hr01_qa_checks.csv")
  tab(qa$trial_qa, "hr01_trial_qa.csv")

  lv <- levels(pairs$device)
  ord <- function(x) { x <- x[order(match(x$device, lv)), ]; rownames(x) <- NULL; x }
  corr <- ord(corr_table(pairs)); tab(corr, "hr02_correlation.csv")
  models <- fit_models(pairs); saveRDS(models, file.path(run_dir, "models", "ols_models.rds"))
  ols <- ord(ols_table(models)); tab(ols, "hr03_ols.csv")
  bands <- ols_bands(models, pairs); tab(bands, "hr03_ols_bands.csv")
  err <- ord(error_table(pairs)); tab(err, "hr04_error.csv")
  diag <- diagnostics_table(models, pairs); tab(diag, "hr05_diagnostics.csv")
  loo <- loo_detail(pairs); tab(loo, "hr05_loo_detail.csv")
  loo_s <- ord(loo_summary(loo, corr, ols, err)); tab(loo_s, "hr05_loo_summary.csv")
  paper <- read.csv(file.path("config", "paper_table1_hr.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
  cmp <- compare_paper(paper, corr, err); tab(cmp, "hr06_paper_comparison.csv")
  logf("tables written")

  fd <- file.path(run_dir, "figures")
  fig_scatter(pairs, bands, corr, ols, file.path(fd, "F1_scatter_ols_identity.png"))
  fig_error_hist(pairs, err, file.path(fd, "F2_error_histogram.png"))
  fig_bland_altman(pairs, err, file.path(fd, "F3_bland_altman_fixed_loa.png"))
  fig_corr_vs_bias(corr, err, file.path(fd, "F4_correlation_vs_agreement.png"))
  fig_resid_fitted(diag, lv, file.path(fd, "F5_residual_vs_fitted.png"))
  fig_qq(diag, lv, file.path(fd, "F6_residual_qq.png"))
  fig_cooks(diag, lv, file.path(fd, "F7_cooks_distance.png"))
  logf("figures written")
}, warning = function(w) {
  warn <<- c(warn, conditionMessage(w)); logf("WARNING: ", conditionMessage(w))
  invokeRestart("muffleWarning")
})

writeLines(capture.output(sessionInfo()), file.path(run_dir, "env", "sessionInfo.txt"))
src_files <- list.files("src", full.names = TRUE)
outs <- list.files(run_dir, recursive = TRUE, full.names = TRUE)
outs <- outs[!grepl("manifest.json$", outs)]
manifest <- list(
  run_id = run_id, started = started, finished = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  command = paste("Rscript src/run_analysis.R", run_id), working_dir = "6th_project/analysis",
  data_version = data_version, seed = "not_applicable",
  r_version = R.version.string,
  packages = sapply(c("readxl", "ggplot2", "patchwork", "jsonlite", "digest"), function(p) as.character(packageVersion(p))),
  inputs = c(setNames(as.list(sapply(c(raw_path, plan_path, "config/paper_table1_hr.csv"), sha)),
                      c(raw_path, plan_path, "config/paper_table1_hr.csv")),
             setNames(as.list(sapply(src_files, sha)), src_files)),
  derived = setNames(list(sha(der_csv)), der_csv),
  outputs = setNames(as.list(sapply(outs, sha)), sub(paste0("^", run_dir, "/"), "", outs)),
  n_pairs = nrow(pairs), n_per_device = as.list(table(as.character(pairs$device))),
  warnings = warn
)
write_json(manifest, file.path(run_dir, "manifest.json"), auto_unbox = TRUE, pretty = TRUE)
logf("done; warnings = ", length(warn))
cat("run", run_id, "done. data_version =", data_version, "; warnings =", length(warn), "\n")
