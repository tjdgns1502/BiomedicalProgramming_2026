## 13_verify_parallel.R --------------------------------------------------
## Before trusting the v2 scripts (11, 12) for the B = 10000 run:
##
##   (a) legacy RNG, 7 workers, B = 1000  must reproduce the committed v1
##       CSVs (01, 02) line for line. For 12 this also covers the JT swap:
##       any p-value difference would change a rejection rate or KS value.
##   (b) streams RNG, B = 1000: 1 worker (sequential) and 7 workers must give
##       line-for-line identical CSVs, i.e. results don't depend on workers.
##
## Criterion: identical() on the CSV lines. Run on a clean tree, so the v1
## CSVs in output/tables/ are the committed ones. Temporary outputs go to
## tempdir(). Takes about 10 minutes.
##
## Rscript R/13_verify_parallel.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

RSCRIPT <- file.path(R.home("bin"), "Rscript")
TAB_DIR <- file.path(PROJ, "output", "tables")
B_CHECK <- 1000L
WORKERS <- 7L

run_v2 <- function(script, rng, workers) {
  out <- file.path(tempdir(), sprintf("%s_%s_w%d", sub("\\.R$", "", script), rng, workers))
  t0 <- Sys.time()
  status <- system2(RSCRIPT, c(shQuote(file.path(PROJ, "R", script)), paste0("--B=", B_CHECK),
                               paste0("--rng=", rng), paste0("--workers=", workers),
                               paste0("--outdir=", shQuote(out))),
                    stdout = FALSE, stderr = FALSE)
  if (status != 0) stop(script, " failed with status ", status)
  csv <- list.files(file.path(out, "tables"), pattern = "\\.csv$", full.names = TRUE)
  list(csv = csv, sec = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

compare <- function(script, check, a, b, sec_a, sec_b) {
  la <- readLines(a); lb <- readLines(b)
  data.frame(script = script, check = check, lines = length(la),
             identical = identical(la, lb),
             differing_lines = if (length(la) == length(lb)) sum(la != lb) else NA,
             sec_a = sec_a, sec_b = sec_b)
}

checks <- list()
for (s in list(c("11_multiplicity_inflation_v2.R", "01_multiplicity_inflation.csv"),
               c("12_pvalue_uniformity_v2.R",      "02_pvalue_uniformity.csv"))) {
  leg <- run_v2(s[1], "legacy", WORKERS)
  seq <- run_v2(s[1], "streams", 1L)
  par <- run_v2(s[1], "streams", WORKERS)
  checks[[length(checks) + 1]] <- compare(s[1], sprintf("legacy w%d vs committed v1 %s", WORKERS, s[2]),
                                          leg$csv, file.path(TAB_DIR, s[2]), leg$sec, NA)
  checks[[length(checks) + 1]] <- compare(s[1], sprintf("streams w1 vs streams w%d", WORKERS),
                                          seq$csv, par$csv, seq$sec, par$sec)
}
res <- do.call(rbind, checks)

out_csv <- file.path(TAB_DIR, "13_parallel_verification.csv")
write.csv(res, out_csv, row.names = FALSE)
print(res, row.names = FALSE)
cat(if (all(res$identical)) "\nAll checks identical: v2 may be used for the final run.\n"
    else "\nMISMATCH: do not use v2 until resolved.\n")
cat("Written:", out_csv, "\n")
