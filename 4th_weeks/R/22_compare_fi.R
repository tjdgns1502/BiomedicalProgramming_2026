## 22_compare_fi.R -------------------------------------------------------
## Compare the frailty index built by R/20_build_analytic_sample.R
## ("builder") with the independent build R/21_fi_independent.R
## ("independent", data/processed/fi_independent.csv).
##
## Builder item matrix: re-created by evaluating R/20's own FI section
## (from `fi <- data.frame(SEQN = full$SEQN)` to `full$frail_num`) on the
## saved pooled file, and checked to reproduce the saved fi_score exactly.
## Independent item matrix: R/21 is sourced in its own environment.
##
## Populations
##   A  age 50+ with an FI under each version's own completeness rule
##      (builder: >= 29/36 items answered; independent: its own file)
##   B  builder's analytic sample (N = 14054) that also has an independent FI
##
## Outputs (output/tables/)
##   22_fi_comparison_summary.csv   r, mean difference, limits of agreement,
##                                  FI > 0.3 agreement and kappa, prevalences
##   22_fi_item_agreement.csv       per item: prevalence in each version,
##                                  disagreements, one-sided missingness
##   22_fi_definition_differences.csv  every item whose rule differs, with
##                                  the number of people it changes
##
## Rscript R/22_compare_fi.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(survey))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")

## ========================================================================
## 1. Builder items, re-created from R/20's own code
## ========================================================================

full <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_pooled.rds"))
src  <- readLines(file.path(PROJ, "R", "20_build_analytic_sample.R"), encoding = "UTF-8")
yn01 <- eval(parse(text = grep("^yn01 <- function", src, value = TRUE)))
from <- grep("^fi <- data.frame\\(SEQN = full\\$SEQN\\)", src)
to   <- grep("^full\\$frail_num", src)
stopifnot(length(from) == 1, length(to) == 1, from < to)
b_env <- new.env()
b_env$full <- full; b_env$yn01 <- yn01
eval(parse(text = src[from:to]), envir = b_env)
stopifnot(identical(b_env$full$fi_score, full$fi_score))   # re-creation is exact

bi <- b_env$fi
b_items <- b_env$item_cols

## ========================================================================
## 2. Independent items
## ========================================================================

i_env <- new.env()
invisible(capture.output(sys.source(file.path(PROJ, "R", "21_fi_independent.R"), envir = i_env)))
ii <- i_env$all
i_items <- i_env$items36
ind_file <- read.csv(file.path(PROJ, "data", "processed", "fi_independent.csv"))
stopifnot(isTRUE(all.equal(ii$FI[match(ind_file$SEQN, ii$SEQN)], ind_file$FI)))

## Item names differ between the two scripts; pair them explicitly.
pairs <- data.frame(
  builder = c("angina","heart_att","chd","stroke","thyroid","cancer","arthritis","hbp",
              "diabetes","kidney","confusion","money","stoop","lift","walk_rooms",
              "stand_chair","bed","dress","grasp","social","health_gen","healthcare_use",
              "health_vs_yr","hosp_overnight","meds","pulse","sbp","pulse_pressure",
              "platelet","bun","bicarb","rdw","ldh","alp","uric_acid","calcium"),
  independent = c("angina","heart_attack","chd","stroke","thyroid","cancer","arthritis","hbp",
              "diabetes","kidney","confusion","money","stoop","lift","walk_rooms",
              "chair","bed","dress","grasp","social","srh","hc_use",
              "health_vs_1y","hosp","meds","pulse","sbp","pp",
              "platelet","bun","bicarb","rdw","ldh","alp","uric","calcium"),
  stringsAsFactors = FALSE)
stopifnot(setequal(pairs$builder, b_items), setequal(pairs$independent, i_items))

## ========================================================================
## 3. Populations
## ========================================================================

age50 <- full$SEQN[full$age >= 50]
b_ok  <- full$SEQN[full$age >= 50 & full$fi_n_available >= 29]
popA  <- intersect(b_ok, ind_file$SEQN)
popB  <- intersect(full$SEQN[full$analytic_sample], ind_file$SEQN)

fi_b <- setNames(full$fi_score, full$SEQN)
fi_i <- setNames(ind_file$FI, ind_file$SEQN)

kappa2 <- function(x, y) {
  po <- mean(x == y)
  pe <- mean(x) * mean(y) + (1 - mean(x)) * (1 - mean(y))
  (po - pe) / (1 - pe)
}

compare_pop <- function(label, ids) {
  b <- fi_b[as.character(ids)]; i <- fi_i[as.character(ids)]
  d <- i - b
  fb <- b > 0.3; fi <- i > 0.3
  data.frame(population = label, n = length(ids),
             pearson_r = cor(b, i), spearman_r = cor(b, i, method = "spearman"),
             mean_builder = mean(b), mean_independent = mean(i),
             mean_diff_ind_minus_builder = mean(d), sd_diff = sd(d),
             loa_lower = mean(d) - 1.96 * sd(d), loa_upper = mean(d) + 1.96 * sd(d),
             pct_identical_fi = mean(abs(d) < 1e-12) * 100,
             frail_both = sum(fb & fi), frail_builder_only = sum(fb & !fi),
             frail_independent_only = sum(!fb & fi), frail_neither = sum(!fb & !fi),
             frail_agreement_pct = mean(fb == fi) * 100, frail_kappa = kappa2(fb, fi),
             frail_prev_builder_unw = mean(fb) * 100, frail_prev_independent_unw = mean(fi) * 100)
}

summ <- rbind(
  compare_pop("A: age 50+, FI in both (each own completeness rule)", popA),
  compare_pop("B: builder analytic sample with independent FI", popB))

## Survey-weighted prevalence in the analytic sample (population B)
des <- readRDS(file.path(PROJ, "data", "processed", "frailty_cbc_svydesign.rds"))
des <- update(des, fi_ind = fi_i[as.character(SEQN)])
desB <- subset(des, !is.na(fi_ind))
w_b <- svymean(~ I(fi_score > 0.3), desB)
w_i <- svymean(~ I(fi_ind > 0.3), desB)
summ$frail_prev_builder_wtd <- c(NA, 100 * coef(w_b)[2])
summ$frail_prev_independent_wtd <- c(NA, 100 * coef(w_i)[2])
summ$frail_prev_builder_wtd_se <- c(NA, 100 * SE(w_b)[2])
summ$frail_prev_independent_wtd_se <- c(NA, 100 * SE(w_i)[2])

## Each version on its own full sample, unweighted, for context
own <- data.frame(
  version = c("builder analytic sample (R/20)", "independent, all age 50+ with FI (R/21)"),
  n = c(sum(full$analytic_sample), nrow(ind_file)),
  frail_prev_unw = c(mean(full$frail[full$analytic_sample]) * 100, mean(ind_file$FI > 0.3) * 100))

write.csv(summ, file.path(TAB_DIR, "22_fi_comparison_summary.csv"), row.names = FALSE)

## ========================================================================
## 4. Item-level agreement (population A)
## ========================================================================

bA <- bi[match(popA, bi$SEQN), ]
iA <- ii[match(popA, ii$SEQN), ]
item_tab <- do.call(rbind, lapply(seq_len(nrow(pairs)), function(k) {
  x <- bA[[pairs$builder[k]]]; y <- iA[[pairs$independent[k]]]
  both <- !is.na(x) & !is.na(y)
  data.frame(item = pairs$builder[k], independent_name = pairs$independent[k],
             prev_builder = round(100 * mean(x, na.rm = TRUE), 2),
             prev_independent = round(100 * mean(y, na.rm = TRUE), 2),
             n_both_answered = sum(both),
             n_disagree = sum(x[both] != y[both]),
             n_missing_builder_only = sum(is.na(x) & !is.na(y)),
             n_missing_independent_only = sum(!is.na(x) & is.na(y)))
}))
item_tab$differs <- item_tab$n_disagree > 0 | item_tab$n_missing_builder_only > 0 |
                    item_tab$n_missing_independent_only > 0
write.csv(item_tab, file.path(TAB_DIR, "22_fi_item_agreement.csv"), row.names = FALSE)

## ========================================================================
## 5. Definition differences (from reading both scripts), with counts
## ========================================================================

## Counts over all age 50+ (not only population A), so that people one
## version excludes are visible.
b50 <- bi[match(age50, bi$SEQN), ]; i50 <- ii[match(age50, ii$SEQN), ]
cnt <- function(bn, iname) {
  x <- b50[[bn]]; y <- i50[[iname]]
  c(disagree = sum(!is.na(x) & !is.na(y) & x != y),
    miss_b_only = sum(is.na(x) & !is.na(y)), miss_i_only = sum(!is.na(x) & is.na(y)))
}
defs <- data.frame(
  item = c("stoop, lift, walk_rooms, stand_chair, bed, dress, grasp, social, money (PFQ difficulty items)",
           "ldh", "alp", "thyroid", "meds"),
  builder_rule = c(
    "Item not asked (age 50-59, all limitation screeners negative) = missing; person then usually fails the >= 29/36 rule",
    "2001-2002: LBDSLDSI (L40_B uses the D prefix) - available",
    "2001-2002: LBDSAPSI (L40_B uses the D prefix) - available",
    "1999-2000: MCQ160I (other thyroid disease) only",
    "Max RXDCOUNT/RXD295 per SEQN; anyone without a count (non-users, refused/don't know, not in file) = 0 medications"),
  independent_rule = c(
    "Item not asked because every screener was negative = 0 (no difficulty); person keeps an FI",
    "Looks only for LBXSLDSI, so missing for all of 2001-2002",
    "Looks only for LBXSAPSI, so missing for all of 2001-2002",
    "1999-2000: MCQ160H (goiter) or MCQ160I = deficit",
    "RXD030/RXDUSE = 2 -> 0 medications; use = 1 -> count; refused/don't know -> missing"),
  correct_per_paper = c(
    "not stated in the paper; builder matches the paper's age profile (weighted median age 66 [61, 74] vs builder 67 [61, 74]), independent is the more defensible measurement",
    "builder: L40_B does contain LBDSLDSI (verified in data/raw/L40_B.rds)",
    "builder: L40_B does contain LBDSAPSI (verified in data/raw/L40_B.rds)",
    "not stated (Supplemental Table S1 says only 'Thyroid condition')",
    "not stated; builder counts refusals as 0 medications, independent as missing"))
mk <- function(bn, iname) cnt(bn, iname)
pfq_b <- c("stoop","lift","walk_rooms","stand_chair","bed","dress","grasp","social","money")
pfq_i <- c("stoop","lift","walk_rooms","chair","bed","dress","grasp","social","money")
pfq_cnt <- rowSums(sapply(seq_along(pfq_b), function(k) cnt(pfq_b[k], pfq_i[k])))
counts <- rbind(pfq_cnt, mk("ldh","ldh"), mk("alp","alp"), mk("thyroid","thyroid"), mk("meds","meds"))
defs <- cbind(defs, counts)
names(defs)[names(defs) == "disagree"]    <- "n_values_disagree_age50"
names(defs)[names(defs) == "miss_b_only"] <- "n_missing_builder_only_age50"
names(defs)[names(defs) == "miss_i_only"] <- "n_missing_independent_only_age50"
write.csv(defs, file.path(TAB_DIR, "22_fi_definition_differences.csv"), row.names = FALSE)

## Items that differ in the data but are not explained by the rules above
explained <- c(pfq_b, "ldh", "alp", "thyroid", "meds")
unexplained <- item_tab[item_tab$differs & !item_tab$item %in% explained, ]

## ========================================================================
## 6. Console
## ========================================================================

cat("Builder FI re-created exactly from R/20 code: TRUE\n\n")
show <- summ
num <- vapply(show, is.numeric, logical(1)); show[num] <- lapply(show[num], round, 4)
print(t(show))
cat("\nEach version on its own sample:\n"); print(own, row.names = FALSE, digits = 4)
cat("\nItems that differ (population A):\n")
print(item_tab[item_tab$differs, ], row.names = FALSE)
cat("\nDiffering items NOT explained by the documented rule differences:",
    if (nrow(unexplained)) paste(unexplained$item, collapse = ", ") else "none", "\n")
cat("\nDefinition differences (counts over age 50+):\n")
print(defs[, c("item", "n_values_disagree_age50", "n_missing_builder_only_age50",
               "n_missing_independent_only_age50")], row.names = FALSE)
