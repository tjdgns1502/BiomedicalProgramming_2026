source("config.R")

dirs <- c("data/derived", "results/tables", "results/figures", "results/logs", "report")
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
set.seed(config$seed)

append_log <- function(title, lines, file = "results/logs/reconciliation.md") {
  stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  cat(sprintf("\n## %s — %s\n\n%s\n", title, stamp, paste(lines, collapse = "\n")),
      file = file, append = TRUE)
}

record_manifest <- function(path, script, notes = "") {
  input_checksum <- trimws(readLines("data/reference/input_pdf_md5.txt", warn = FALSE)[1])
  row <- data.frame(
    file = path, script = script, seed = config$seed,
    created_at = format(file.info(path)$mtime, "%Y-%m-%d %H:%M:%S"),
    input_checksum = input_checksum,
    notes = notes, check.names = FALSE
  )
  old <- if (file.exists("results/manifest.csv")) tryCatch(
    read.csv("results/manifest.csv", stringsAsFactors = FALSE), error = function(e) NULL) else NULL
  if (!is.null(old) && nrow(old)) old <- old[old$file != path, , drop = FALSE]
  write.csv(rbind(old, row), "results/manifest.csv", row.names = FALSE)
}

capture.output(sessionInfo(), file = "results/logs/sessionInfo.txt")
