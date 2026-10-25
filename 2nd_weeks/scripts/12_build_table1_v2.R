# v2 of 02_build_table1.R - supersedes it for final results.
# Keeps 02_build_table1.R untouched (v1, first pass) so the revision from v1
# to v2 stays visible as a diff between two files, not a silent in-place edit.
# See 2nd_weeks/README.md for what changed and why (teammate cross-check).
#
# Reproduce Table 1 of Ye et al. 2023 (BMC Public Health) using NHANES 2011-2020
# Cycles combined: 2011-2012 (G), 2013-2014 (H), 2015-2016 (I), 2017-Mar2020 pre-pandemic (P)

library(haven)
library(survey)

data_dir <- "data"

read_cycle <- function(cycle) {
  fn <- function(comp) {
    base <- if (cycle == "P") paste0("P_", comp) else paste0(comp, "_", cycle)
    file.path(data_dir, paste0(base, ".XPT"))
  }
  demo  <- read_xpt(fn("DEMO"))
  bmx   <- read_xpt(fn("BMX"))
  smq   <- read_xpt(fn("SMQ"))
  diq   <- read_xpt(fn("DIQ"))
  bpq   <- read_xpt(fn("BPQ"))
  mcq   <- read_xpt(fn("MCQ"))
  alq   <- read_xpt(fn("ALQ"))
  tchol <- read_xpt(fn("TCHOL"))
  hdl   <- read_xpt(fn("HDL"))
  trig  <- read_xpt(fn("TRIGLY"))

  # NOTE: interview weight (WTINT2YR/WTINTPRP), not the MEC exam weight, per
  # the finding documented below at WTCOMB.
  wt_var <- if (cycle == "P") "WTINTPRP" else "WTINT2YR"

  d <- demo[, c("SEQN", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
                "INDFMPIR", "SDMVPSU", "SDMVSTRA", wt_var)]
  names(d)[names(d) == wt_var] <- "WT2YR"

  d <- merge(d, bmx[, c("SEQN", "BMXWT", "BMXWAIST", "BMXBMI")], by = "SEQN", all.x = TRUE)
  d <- merge(d, smq[, c("SEQN", "SMQ020")], by = "SEQN", all.x = TRUE)
  d <- merge(d, diq[, c("SEQN", "DIQ010")], by = "SEQN", all.x = TRUE)
  d <- merge(d, bpq[, c("SEQN", "BPQ020")], by = "SEQN", all.x = TRUE)
  d <- merge(d, mcq[, c("SEQN", "MCQ160C", "MCQ160F", "MCQ220")], by = "SEQN", all.x = TRUE)

  alq_sub <- if (cycle == "P") {
    alq[, c("SEQN", "ALQ121", "ALQ130")]
  } else {
    alq[, c("SEQN", "ALQ101", "ALQ130")]
  }
  d <- merge(d, alq_sub, by = "SEQN", all.x = TRUE)

  d <- merge(d, tchol[, c("SEQN", "LBXTC")], by = "SEQN", all.x = TRUE)
  d <- merge(d, hdl[, c("SEQN", "LBDHDD")], by = "SEQN", all.x = TRUE)
  d <- merge(d, trig[, c("SEQN", "LBXTR", "LBDLDL")], by = "SEQN", all.x = TRUE)

  # Average alcohol consumption past 12 months = raw ALQ130 (drinks/day),
  # taken AS-IS: no 0-imputation for non-drinkers, no filtering of the
  # 777 (refused) / 999 (don't know) skip codes.
  # Tested three cleaner alternatives (0-impute non-drinkers; drop non-drinkers
  # as NA; filter 777/999) against the paper's characteristic Q1-Q4 pattern of
  # a modest mean (~3-4) with an enormous SD (~19-40): every cleaned version
  # collapses the SD to ~2-2.5, but leaving 777/999 as literal numeric values
  # reproduces the paper's mean AND its inflated SD almost exactly (e.g. Q2:
  # 4.47+-42.31 here vs 4.29+-39.96 in the paper). This indicates the paper's
  # own alcohol variable was NOT cleaned of these placeholder codes before
  # averaging - we replicate that (undocumented) choice here to match it,
  # even though it is not the statistically correct way to handle ALQ130.
  d$ALCOHOL <- d$ALQ130
  d$ALQ101 <- NULL
  d$ALQ121 <- NULL
  d$ALQ130 <- NULL

  d$cycle <- cycle
  d
}

cycles <- c("G", "H", "I", "P")
all_data <- do.call(rbind, lapply(cycles, read_cycle))

# ---- Combined weight (CHANGED IN v2) ----
# v1 (02_build_table1.R) used the statistically-correct MEC exam weight
# (WTMEC2YR/WTMECPRP), rescaled per cycle by its share of the pooled span
# (2011-12/13-14/15-16 = 2 yrs each, 2017-Mar2020 pre-pandemic = 3.2 yrs,
# total 9.2 yrs): WTMEC2YR*(2/9.2) or WTMECPRP*(3.2/9.2).
#
# A teammate's independent reproduction (Teammate_analysis/R/06_diagnose_discrepancies.R,
# "검정 A") grid-searched weight schemes against all 132 cells of the paper's
# Table 1 and found the paper instead used the INTERVIEW weight (WTINT2YR/
# WTINTPRP) taken RAW, with no cycle-span rescaling at all (score dropped from
# 13.57 to 1.0 on their metric). We adopt that here to match the paper, even
# though it is not the statistically correct way to pool MEC-measured variables
# (weight/WC/labs) across cycles - see 02_build_table1.R for the v1 version.
all_data$WTCOMB <- all_data$WT2YR

# Nest PSU/strata by cycle for valid multi-cycle variance estimation
all_data$psu_c <- paste(all_data$cycle, all_data$SDMVPSU)
all_data$strata_c <- paste(all_data$cycle, all_data$SDMVSTRA)

# ---- Derived / recoded variables ----
d <- all_data
d$WWI <- d$BMXWAIST / sqrt(d$BMXWT)

d$sex <- factor(d$RIAGENDR, levels = c(1, 2), labels = c("Male", "Female"))

d$race <- factor(
  ifelse(d$RIDRETH1 == 3, "Non-Hispanic White",
  ifelse(d$RIDRETH1 == 4, "Non-Hispanic Black",
  ifelse(d$RIDRETH1 == 1, "Mexican American",
  ifelse(d$RIDRETH1 %in% c(2, 5), "Other race/multiracial", NA)))),
  levels = c("Non-Hispanic White", "Non-Hispanic Black", "Mexican American", "Other race/multiracial")
)

d$education <- factor(
  ifelse(d$DMDEDUC2 %in% c(1, 2), "Less than high school",
  ifelse(d$DMDEDUC2 == 3, "High school",
  ifelse(d$DMDEDUC2 %in% c(4, 5), "More than high school", NA))),
  levels = c("Less than high school", "High school", "More than high school")
)

d$smoking <- factor(
  ifelse(d$SMQ020 == 1, "Ever", ifelse(d$SMQ020 == 2, "Never", NA)),
  levels = c("Ever", "Never")
)

# NOTE: DIQ010==3 ("borderline") is grouped into "Yes" together with diagnosed
# diabetes (==1). Tested against the paper's Q1-Q4 Yes% (3.01/8.60/14.85/26.76):
# Yes={1} vs No={2} alone gives 2.01/7.13/11.93/24.38 (too low); folding
# borderline into Yes gives 3.05/8.77/15.06/26.94, matching the paper almost
# exactly (and matching a teammate's independent reproduction exactly).
d$diabetes <- factor(
  ifelse(d$DIQ010 %in% c(1, 3), "Yes", ifelse(d$DIQ010 == 2, "No", NA)),
  levels = c("Yes", "No")
)

d$hbp <- factor(
  ifelse(d$BPQ020 == 1, "Yes", ifelse(d$BPQ020 == 2, "No", NA)),
  levels = c("Yes", "No")
)

d$chd <- factor(
  ifelse(d$MCQ160C == 1, "Yes", ifelse(d$MCQ160C == 2, "No", NA)),
  levels = c("Yes", "No")
)

d$cancer <- factor(
  ifelse(d$MCQ220 == 1, "Yes", ifelse(d$MCQ220 == 2, "No", NA)),
  levels = c("Yes", "No")
)

# NOTE: MCQ160F==9 ("don't know", 22 cases with complete weight+WC) is coded
# as "No", not missing. Verified against the paper's flow chart: treating only
# true skip-pattern NAs as "missing stroke" reproduces the paper's exclusion
# count exactly (n=14,330 missing -> final N=23,389), whereas excluding code 9
# as missing undercounts the paper's final N by 22.
d$stroke <- factor(
  ifelse(d$MCQ160F == 1, "Yes", ifelse(d$MCQ160F %in% c(2, 9), "No", NA)),
  levels = c("Yes", "No")
)

# ---- Exclusions: complete weight, waist circumference, and stroke status ----
before_n <- nrow(d)
d <- d[!is.na(d$BMXWT) & !is.na(d$BMXWAIST) & !is.na(d$stroke) & !is.na(d$WTCOMB) & d$WTCOMB > 0, ]
message(sprintf("N before exclusion: %d | N after exclusion: %d", before_n, nrow(d)))

# ---- WWI quartiles (unweighted cut points, as is standard practice) ----
# CHANGED IN v2: right = FALSE ([a,b) intervals) instead of v1's default
# right = TRUE ((a,b] intervals). A value exactly at a cutpoint now falls in
# the HIGHER quartile, reproducing the paper's exact per-quartile n pattern
# (5,847/5,847/5,847/5,848, extra person in Q4); v1's right=TRUE put the extra
# person in Q1 instead (5,848/5,847/5,847/5,847).
qcuts <- quantile(d$WWI, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
d$wwi_q <- cut(d$WWI, breaks = c(-Inf, qcuts, Inf),
               labels = c("Q1", "Q2", "Q3", "Q4"), right = FALSE)
print(qcuts)
print(table(d$wwi_q))

saveRDS(d, file.path("data", "analytic_sample_v2.rds"))
message("Saved analytic_sample_v2.rds")
