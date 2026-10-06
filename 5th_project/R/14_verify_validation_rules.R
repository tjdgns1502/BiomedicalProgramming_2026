## 14_verify_validation_rules.R --------------------------------------------
## Mutation test for R/13_validate_sample.R: a validation rule that can never
## fail proves nothing. Each mutation corrupts one thing in a copy of the
## analytic sample; R/13 must stop, and on the rule written for it.
## The unmutated baseline must not stop. Outputs of these runs go to a temp
## folder, not to output/.
##
## Result (2026-10-07): each of the 7 mutations stopped on exactly its own
## step (5, 9, 16, 1, 6, 2, 20); baseline NO STOP. The first run showed
## step 16 erroring in every run: its expression used a global lookup vector
## that pointblank could not see; R/13 now writes the vector inline.
##
## Rscript R/14_verify_validation_rules.R   (from the 5th_project folder)
## ------------------------------------------------------------------------
src <- readLines("R/13_validate_sample.R")
d0 <- readRDS("data/processed/oral_htn_analytic.rds")
tmp <- file.path(tempdir(), "p13"); dir.create(file.path(tmp, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
muts <- list(
  dbp_zero      = function(d) { d$dbp[1] <- 0; d },
  skip_as_na    = function(d) { i <- which(d$BPQ020 == 2 & !d$htn_measured)[1]; d$htn[i] <- NA; d },
  oral_wrong    = function(d) { i <- which(d$ohq845_raw == 2)[1]; d$oral4[i] <- "Good"; d },
  dup_seqn      = function(d) rbind(d, d[1, ]),
  bpxo_column   = function(d) { d$BPXOSY1 <- 1; d },
  under30       = function(d) { d$age[1] <- 25; d },
  weight_wrong  = function(d) { d$wt_mec10[1] <- d$WTMEC2YR[1]; d })
for (m in names(muts)) {
  dm <- muts[[m]](d0)
  code <- sub('^d <- readRDS.*$', 'PROJ <- tmp; d <- dm', src)
  
  res <- tryCatch({ sink(tempfile()); eval(parse(text = code), envir = new.env()); "NO STOP" },
                  error = function(e) paste("stopped:", conditionMessage(e)),
                  finally = sink())
  cat(sprintf("%-13s %s\n", m, res))
}
cat("baseline (no mutation): "); dm <- d0; code <- sub("^d <- readRDS.*$", "PROJ <- tmp; d <- dm", src); cat(tryCatch({ sink(tempfile()); eval(parse(text = code), envir = new.env()); "NO STOP" }, error = function(e) conditionMessage(e), finally = sink()), "\n")
