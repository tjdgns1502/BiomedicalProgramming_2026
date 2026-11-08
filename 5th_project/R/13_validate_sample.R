## 13_validate_sample.R ---------------------------------------------------
## Rule-based validation of the analytic sample built by R/11, with the
## pointblank package, before any analysis reads it (plan step B).
##
## Two kinds of steps:
##   hard  a failure is a build error -> the script stops after writing the
##         report (stop_at = 1 failing row)
##   soft  a known or expected gap from the paper (N, cases, HTN NA) ->
##         warning only, recorded in the report
##
## Hard rules (each traces to the plan / plan_revision.md item):
##   SEQN unique; age >= 30; cycle in the 5 cycles 2009-2018
##   sbp > 0 and not NA; dbp > 0 where present (DBP 0 must have been set to
##     NA before the mean, so a 0 here is an error; NA is allowed: people
##     whose DBP readings were all 0 keep their SBP - revision item 5,
##     plan step B "NA 허용"; v1 of this rule required DBP, see CHANGES_v2.md)
##   no BPXO* columns (oscillometric never mixed in; item 6)
##   htn_measured == (sbp >= 140 | dbp >= 90), a missing DBP counting as < 90
##   htn == (htn_measured | htn_diagnosed) where htn is not NA
##   skip pattern: BPQ020 == 2 and BP below cut-offs -> htn == 0, never NA
##     (BPQ050A is asked only after BPQ040A == 1; item 4)
##   exposures and smoking present, raw codes in range, oral4 / perio /
##     smoke agree with their raw codes
##   wt_mec10 == WTMEC2YR / 5 and > 0; PSU and stratum present
## Soft rules:
##   row count == 21,800; HTN cases == 11,017; htn not NA
##
## Outputs:
##   output/report/13_validation.html     pointblank agent report
##   output/tables/13_validation_steps.csv  one row per step: step, type,
##                                          rule, columns, n, n_failed,
##                                          f_failed, warn, stop
##
## Rscript R/13_validate_sample.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(pointblank))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

d <- readRDS(file.path(PROJ, "data", "processed", "oral_htn_analytic_v2.rds"))

CYCLES <- c("2009-2010", "2011-2012", "2013-2014", "2015-2016", "2017-2018")
hard <- action_levels(stop_at = 1)
soft <- action_levels(warn_at = 1)

agent <- create_agent(tbl = d, tbl_name = "oral_htn_analytic_v2",
                      label = "Week 5 analytic sample (R/11_v2)") |>
  ## identity and scope
  rows_distinct(columns = vars(SEQN), actions = hard, label = "hard: SEQN unique") |>
  col_vals_gte(columns = vars(age), value = 30, actions = hard, label = "hard: age >= 30") |>
  col_vals_in_set(columns = vars(cycle), set = CYCLES, actions = hard,
                  label = "hard: cycle 2009-2018") |>
  ## blood pressure
  col_vals_gt(columns = vars(sbp), value = 0, na_pass = FALSE, actions = hard,
              label = "hard: mean SBP > 0, not NA") |>
  col_vals_gt(columns = vars(dbp), value = 0, na_pass = TRUE, actions = hard,
              label = "hard: mean DBP > 0 where present (NA allowed)") |>
  specially(fn = function(x) !any(grepl("^BPXO", names(x))), actions = hard,
            label = "hard: no oscillometric BPXO columns") |>
  col_vals_expr(expr = ~ htn_measured == (sbp >= 140 | (!is.na(dbp) & dbp >= 90)),
                actions = hard,
                label = "hard: htn_measured = SBP>=140 or DBP>=90") |>
  col_vals_expr(expr = ~ htn == as.numeric(htn_measured | htn_diagnosed),
                preconditions = ~ . %>% dplyr::filter(!is.na(htn)), actions = hard,
                label = "hard: htn = measured or diagnosed") |>
  col_vals_equal(columns = vars(htn), value = 0, na_pass = FALSE,
                 preconditions = ~ . %>% dplyr::filter(BPQ020 == 2, !htn_measured),
                 actions = hard,
                 label = "hard: BPQ020=2 and normal BP -> htn 0 (skip NA not missing)") |>
  ## exposures and smoking
  col_vals_not_null(columns = vars(oral4, perio, smoke), actions = hard,
                    label = "hard: oral4, perio, smoke present") |>
  col_vals_in_set(columns = vars(ohq845_raw), set = 1:5, actions = hard,
                  label = "hard: OHQ845 in 1-5") |>
  col_vals_in_set(columns = vars(ohq835_raw, SMQ020), set = 1:2, actions = hard,
                  label = "hard: OHQ835, SMQ020 in 1-2") |>
  ## lookup vector written inline: pointblank evaluates the expression
  ## against the table, and a global (e.g. ORAL4) is not reliably in scope
  col_vals_expr(expr = ~ as.character(oral4) == c("Excellent/Very good",
                  "Excellent/Very good", "Good", "Fair", "Poor")[ohq845_raw],
                actions = hard,
                label = "hard: oral4 matches OHQ845 (1-2 combined)") |>
  col_vals_expr(expr = ~ (perio == "Yes") == (ohq835_raw == 1), actions = hard,
                label = "hard: perio matches OHQ835") |>
  col_vals_expr(expr = ~ (smoke == "Yes") == (SMQ020 == 1), actions = hard,
                label = "hard: smoke matches SMQ020") |>
  ## design
  col_vals_gt(columns = vars(wt_mec10), value = 0, actions = hard,
              label = "hard: wt_mec10 > 0") |>
  col_vals_expr(expr = ~ abs(wt_mec10 - WTMEC2YR / 5) < 1e-6, actions = hard,
                label = "hard: wt_mec10 = WTMEC2YR / 5") |>
  col_vals_not_null(columns = vars(SDMVPSU, SDMVSTRA), actions = hard,
                    label = "hard: PSU and stratum present") |>
  ## expected gaps from the paper
  row_count_match(count = 21800L, actions = soft, label = "soft: N = 21,800 (paper)") |>
  specially(fn = function(x) sum(x$htn == 1, na.rm = TRUE) == 11017L, actions = soft,
            label = "soft: HTN cases = 11,017 (paper)") |>
  col_vals_not_null(columns = vars(htn), actions = soft, label = "soft: htn not NA") |>
  interrogate(progress = FALSE)

## report + step table
dir.create(file.path(PROJ, "output", "report"), showWarnings = FALSE)
export_report(agent, filename = file.path(PROJ, "output", "report", "13_validation.html"),
              quiet = TRUE)

xl <- get_agent_x_list(agent)
na_false <- function(v) { v <- as.logical(v); v[is.na(v)] <- FALSE; v }
steps <- data.frame(
  step = xl$i, type = sub(":.*", "", agent$validation_set$label),
  rule = sub("^[a-z]+: ", "", agent$validation_set$label),
  fn = xl$type,
  columns = vapply(xl$columns, function(c) paste(unlist(c), collapse = ","), ""),
  n = xl$n, n_failed = xl$n_failed, f_failed = round(xl$f_failed, 5),
  eval_error = na_false(xl$eval_error),
  warn = na_false(xl$warn), stop = na_false(xl$stop))
write.csv(steps, file.path(PROJ, "output", "tables", "13_validation_steps.csv"),
          row.names = FALSE)

print(steps[, c("step", "rule", "n", "n_failed", "warn", "stop", "eval_error")],
      row.names = FALSE, right = FALSE)
bad <- steps$stop | steps$eval_error
if (any(bad))
  stop(sprintf("%d hard validation step(s) failed or errored: %s",
               sum(bad), paste(steps$step[bad], collapse = ", ")))
cat("\nAll hard rules passed; soft warnings:", sum(steps$warn), "\n")
