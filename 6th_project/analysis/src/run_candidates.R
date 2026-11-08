# 사용법 (작업 디렉터리 = 6th_project/analysis): Rscript src/run_candidates.R R2-20261025
# R1 표만 입력으로 쓰는 탐색적 실행. 이미 있는 run_id에는 쓰지 않는다.
args <- commandArgs(TRUE)
run_id <- if (length(args)) args[1] else stop("run_id를 인자로 주세요")
plan_path <- file.path("config", paste0("plan_", run_id, ".json"))
stopifnot(file.exists(plan_path))
run_dir <- file.path("runs", run_id)
if (dir.exists(run_dir)) stop("이미 존재하는 run: ", run_dir, " (덮어쓰지 않음; 새 run_id를 쓰세요)")
suppressPackageStartupMessages({ library(jsonlite); library(digest) })
source(file.path("src", "05_rounding_candidates.R"), encoding = "UTF-8")
sha <- function(p) digest(file = p, algo = "sha256")

plan <- fromJSON(plan_path)
started <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
corr <- read.csv(plan$inputs[1], stringsAsFactors = FALSE)
err <- read.csv(plan$inputs[2], stringsAsFactors = FALSE)
paper <- read.csv(plan$inputs[3], stringsAsFactors = FALSE, encoding = "UTF-8")
res <- rounding_candidates(corr, err, paper)

dir.create(file.path(run_dir, "tables"), recursive = TRUE)
out <- file.path(run_dir, "tables", "hr06_rounding_candidates.csv")
write.csv(res, out, row.names = FALSE, fileEncoding = "UTF-8")
manifest <- list(
  run_id = run_id, started = started, finished = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  command = paste("Rscript src/run_candidates.R", run_id), status = "exploratory / post-result",
  r_version = R.version.string,
  inputs = setNames(as.list(sapply(c(plan$inputs, plan_path, "src/05_rounding_candidates.R", "src/run_candidates.R"), sha)),
                    c(plan$inputs, plan_path, "src/05_rounding_candidates.R", "src/run_candidates.R")),
  outputs = setNames(list(sha(out)), "tables/hr06_rounding_candidates.csv"),
  n_rows = nrow(res), n_match = sum(res$verdict == "반올림 일치")
)
write_json(manifest, file.path(run_dir, "manifest.json"), auto_unbox = TRUE, pretty = TRUE)
cat("run", run_id, "done;", manifest$n_match, "/", nrow(res), "candidate values rounding-compatible\n")
