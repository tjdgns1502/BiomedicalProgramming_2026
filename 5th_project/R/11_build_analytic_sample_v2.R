## 11_build_analytic_sample_v2.R ------------------------------------------
## Li et al. 2023 (oral health / periodontal disease and hypertension),
## NHANES 2009-2018, adults >= 30.
##
## v2 of R/11 (see CHANGES_v2.md). One change, found by the ai-error-auditor:
## v1 required a non-NA mean DBP, so the 59 sample participants whose DBP
## readings were ALL 0 (set to NA, correctly) were dropped as "without blood
## pressure" although they have SBP. In v2 blood pressure is present when
## mean SBP is; a missing DBP cannot reach 90, so htn_measured uses SBP alone
## for them. Everything else is v1 unchanged.
##
## NOTE: the plan's separate 10_download_data.R is folded into this script:
## download (cached in data/raw/*.rds) + merge + coding + exclusions + save.
##
## Outputs (v2 names; v1 files stay as committed)
##   data/raw/<TABLE>_<suffix>.rds            cached raw files (raw codes, translated = FALSE)
##   data/raw/download_log.csv
##   data/processed/oral_htn_full_v2.rds      ALL DEMO participants, column in_sample
##   data/processed/oral_htn_analytic_v2.rds  in_sample rows only
##   output/tables/exclusion_flow_v2.csv
##   output/tables/build_decisions_v2.csv
##   output/tables/build_2x2_check_v2.csv     oral4 x HTN, perio x HTN vs paper
## Build the survey design on the FULL file and subset(in_sample) afterwards.

suppressPackageStartupMessages({ library(nhanesA); library(dplyr); library(purrr) })

root <- normalizePath(".", winslash = "/")
dir.create("data/raw", FALSE, TRUE); dir.create("data/processed", FALSE, TRUE)
dir.create("output/tables", FALSE, TRUE)

## ---- 1. file mapping ------------------------------------------------------
cycles <- data.frame(suffix = c("F", "G", "H", "I", "J"),
                     cycle  = c("2009-2010", "2011-2012", "2013-2014",
                                "2015-2016", "2017-2018"))
tables <- c("DEMO", "BPX", "BPQ", "OHQ", "SMQ", "ALQ", "PAQ", "SLQ", "BMX",
            "TCHOL", "HDL", "TRIGLY", "GHB", "BIOPRO", "DR1TOT", "MCQ", "DIQ")
## variables kept per file (names differ by cycle where noted: any_of)
keep <- list(
  DEMO   = c("SEQN", "SDDSRVYR", "RIDSTATR", "RIAGENDR", "RIDAGEYR", "RIDRETH1",
             "DMDEDUC2", "SDMVPSU", "SDMVSTRA", "WTINT2YR", "WTMEC2YR"),
  BPX    = c("SEQN", paste0("BPXSY", 1:4), paste0("BPXDI", 1:4)),
  BPQ    = c("SEQN", "BPQ020", "BPQ040A", "BPQ050A"),
  OHQ    = c("SEQN", "OHQ845", "OHQ835"),
  SMQ    = c("SEQN", "SMQ020"),
  ALQ    = c("SEQN", "ALQ101", "ALQ110", "ALQ111", "ALQ120Q", "ALQ120U", "ALQ121"),
  PAQ    = c("SEQN", "PAQ605", "PAQ620", "PAQ650", "PAQ665"),
  SLQ    = c("SEQN", "SLD010H", "SLD012"),
  BMX    = c("SEQN", "BMXBMI"),
  TCHOL  = c("SEQN", "LBXTC"),
  HDL    = c("SEQN", "LBDHDD"),
  TRIGLY = c("SEQN", "LBXTR", "WTSAF2YR"),
  GHB    = c("SEQN", "LBXGH"),
  BIOPRO = c("SEQN", "LBXSCR"),
  DR1TOT = c("SEQN", "DR1TSODI", "DR1TTFAT", "WTDRD1"),
  MCQ    = c("SEQN", paste0("MCQ160", c("B", "C", "D", "E", "F"))),
  DIQ    = c("SEQN", "DIQ010"))

## ---- 2. download (cached) + log ---------------------------------------------
log_rows <- list()
get_tab <- function(tb, sfx) {
  nm <- paste0(tb, "_", sfx); f <- file.path("data/raw", paste0(nm, ".rds"))
  status <- "cached"
  if (!file.exists(f)) {
    d <- nhanes(nm, translated = FALSE)       # raw numeric codes, not labels
    if (is.null(d)) stop("download failed: ", nm)
    saveRDS(d, f); status <- "downloaded"
  }
  d <- readRDS(f)
  log_rows[[length(log_rows) + 1]] <<- data.frame(
    table = tb, suffix = sfx, file_name = nm, local_file = f,
    date = as.character(as.Date(file.mtime(f))), status = status,
    n_rows = nrow(d), n_cols = ncol(d),
    nhanesA_version = as.character(packageVersion("nhanesA")))
  d
}
raw <- list()
for (i in seq_len(nrow(cycles))) for (tb in tables)
  raw[[paste(tb, cycles$suffix[i])]] <- get_tab(tb, cycles$suffix[i])
write.csv(bind_rows(log_rows), "data/raw/download_log.csv", row.names = FALSE)

## ---- 3. merge (left join onto ALL DEMO participants) --------------------------
build_cycle <- function(i) {
  sfx <- cycles$suffix[i]
  parts <- lapply(tables, function(tb) {
    d <- raw[[paste(tb, sfx)]]
    d <- d[, intersect(keep[[tb]], names(d)), drop = FALSE]
    d[] <- lapply(d, as.numeric); d
  })
  names(parts) <- tables
  out <- parts$DEMO
  for (tb in setdiff(tables, "DEMO")) {
    stopifnot(!anyDuplicated(parts[[tb]]$SEQN))
    out <- left_join(out, parts[[tb]], by = "SEQN")
  }
  out$cycle <- cycles$cycle[i]; out$suffix <- sfx
  out
}
dat <- bind_rows(lapply(seq_len(nrow(cycles)), build_cycle))
for (v in c("ALQ111", "ALQ121", "SLD010H", "SLD012", "ALQ101", "ALQ110",
            "ALQ120Q", "ALQ120U"))
  if (!v %in% names(dat)) dat[[v]] <- NA_real_
stopifnot(!anyDuplicated(dat$SEQN))
cat("Merged DEMO participants:", nrow(dat), "\n")

## ---- 4. coding ----------------------------------------------------------------
na79 <- function(x) { x[x %in% c(7, 9)] <- NA; x }        # refused / don't know
anyyes_noall <- function(m) {  # any 1 -> 1; else any 2 -> 0; else NA
  yes <- rowSums(m == 1, na.rm = TRUE) > 0; no <- rowSums(m == 2, na.rm = TRUE) > 0
  ifelse(yes, 1, ifelse(no, 0, NA_real_))
}

## 4a. blood pressure: DBP 0 -> NA BEFORE averaging
sy <- as.matrix(dat[paste0("BPXSY", 1:4)]); di <- as.matrix(dat[paste0("BPXDI", 1:4)])
n_di0 <- sum(di == 0, na.rm = TRUE); n_sy0 <- sum(sy == 0, na.rm = TRUE)
di[di == 0] <- NA
dat$sbp <- ifelse(rowSums(!is.na(sy)) > 0, rowMeans(sy, na.rm = TRUE), NA_real_)
dat$dbp <- ifelse(rowSums(!is.na(di)) > 0, rowMeans(di, na.rm = TRUE), NA_real_)
## v2: BP present = mean SBP present. DBP may be NA (all readings 0).
dat$bp_valid <- !is.na(dat$sbp)
n_dbp_na_valid <- sum(dat$bp_valid & is.na(dat$dbp) & dat$RIDAGEYR >= 30)

## 4b. hypertension (components kept)
## v2: a missing DBP is not >= 90, so it cannot make htn_measured NA
dat$htn_measured <- ifelse(dat$bp_valid,
                           dat$sbp >= 140 | (!is.na(dat$dbp) & dat$dbp >= 90), NA)
## BPQ050A is asked only if BPQ040A == 1 (itself only if BPQ020 == 1): skip NA = not taking.
## Anyone with BPQ050A answered has BPQ020 == 1, so BPQ050A never changes the result;
## it is coded explicitly anyway. Only BPQ020 / BPQ050A 7 or 9 is true non-response.
q20 <- dat$BPQ020; q50 <- dat$BPQ050A
yes20 <- q20 %in% 1; yes50 <- q50 %in% 1
no20  <- q20 %in% 2
skip50 <- is.na(q50) & (no20 | yes20)       # structural skip, not missing
dat$htn_diagnosed <- ifelse(yes20 | yes50, TRUE,
                     ifelse(no20, FALSE, NA))   # BPQ020 NA/7/9 and no yes -> unknown
dat$htn <- ifelse(dat$htn_measured %in% TRUE | dat$htn_diagnosed %in% TRUE, 1,
           ifelse(dat$htn_measured %in% FALSE & dat$htn_diagnosed %in% FALSE, 0, NA_real_))
n_q50_nonresp <- sum(q50 %in% c(7, 9)); n_q20_nonresp <- sum(q20 %in% c(7, 9))

## 4c. exposures
dat$ohq845_raw <- dat$OHQ845; dat$ohq835_raw <- dat$OHQ835
o <- na79(dat$OHQ845)
dat$oral4 <- factor(ifelse(o %in% 1:2, 1, o), levels = c(1, 3, 4, 5),
                    labels = c("Excellent/Very good", "Good", "Fair", "Poor"))
p <- na79(dat$OHQ835)
dat$perio <- factor(p, levels = c(2, 1), labels = c("No", "Yes"))

## 4d. smoking (ever >= 100 cigarettes)
s <- na79(dat$SMQ020)
dat$smoke <- factor(s, levels = c(2, 1), labels = c("No", "Yes"))

## 4e. covariates
dat$age <- dat$RIDAGEYR
dat$sex <- factor(dat$RIAGENDR, 1:2, c("Male", "Female"))
dat$race <- factor(dat$RIDRETH1, 1:5, c("Mexican American", "Other Hispanic",
  "Non-Hispanic White", "Non-Hispanic Black", "Other/multi-racial"))
e <- na79(dat$DMDEDUC2)
dat$edu <- factor(ifelse(e %in% 1:2, "<HS", ifelse(e == 3, "HS", ifelse(e %in% 4:5, ">HS", NA))),
                  levels = c("<HS", "HS", ">HS"))
dat$bmi <- dat$BMXBMI
dat$bmi_cat <- cut(dat$BMXBMI, c(-Inf, 18.5, 25, 30, Inf), right = FALSE,
                   labels = c("<18.5", "18.5-24.9", "25-29.9", ">=30"))

## alcohol: drinking days per week (frequency proxy; no drinks-per-day item used)
q <- dat$ALQ120Q; q[q %in% c(777, 999)] <- NA
u <- dat$ALQ120U; u[u %in% c(7, 9)] <- NA
dpw_old <- ifelse(u == 1, q, ifelse(u == 2, q * 12 / 52, ifelse(u == 3, q / 52, NA)))
dpw_old[q %in% 0] <- 0
a121 <- dat$ALQ121; a121[a121 %in% c(77, 99)] <- NA
map121 <- c(`0` = 0, `1` = 7, `2` = 6, `3` = 3.5, `4` = 2, `5` = 1, `6` = 2.5 * 12 / 52,
            `7` = 12 / 52, `8` = 9 / 52, `9` = 4.5 / 52, `10` = 1.5 / 52)
dpw_new <- unname(map121[as.character(a121)])
dat$alc_days_wk <- ifelse(dat$suffix == "J", dpw_new, dpw_old)   # ALQ121 exists only in 2017-18 (J)
## lifetime abstainers skip the frequency item -> no drinks
abst <- (dat$ALQ101 %in% 2 & dat$ALQ110 %in% 2) | dat$ALQ111 %in% 2
dat$alc_days_wk[is.na(dat$alc_days_wk) & abst] <- 0
dat$alcohol <- factor(ifelse(is.na(dat$alc_days_wk), NA,
                      ifelse(dat$alc_days_wk == 0, "No drinks",
                      ifelse(dat$alc_days_wk <= 1, "<=1 drink/week", ">1 drink/week"))),
                      levels = c("No drinks", "<=1 drink/week", ">1 drink/week"))

pa <- anyyes_noall(na79(as.matrix(dat[c("PAQ605", "PAQ620", "PAQ650", "PAQ665")])))
dat$pa <- factor(pa, c(0, 1), c("Inactive", "Active"))

dat$sleep_h <- ifelse(dat$suffix %in% c("I", "J"), dat$SLD012,
                      ifelse(dat$SLD010H %in% c(77, 99), NA, dat$SLD010H))
dat$sleep_cat <- factor(ifelse(is.na(dat$sleep_h), NA,
                        ifelse(dat$sleep_h < 7, "<7 h", ifelse(dat$sleep_h <= 9, "7-9 h", ">9 h"))),
                        levels = c("<7 h", "7-9 h", ">9 h"))

dat$cvd <- factor(anyyes_noall(na79(as.matrix(dat[paste0("MCQ160", c("B", "C", "D", "E", "F"))]))),
                  c(0, 1), c("No", "Yes"))
dat$diq010_raw <- dat$DIQ010
dm <- na79(dat$DIQ010)
dat$diabetes <- factor(ifelse(dm == 1, 1, ifelse(dm %in% c(2, 3), 0, NA)), c(0, 1), c("No", "Yes"))

## weights
dat$wt_mec10 <- dat$WTMEC2YR / 5
dat$wt_dr10  <- dat$WTDRD1 / 5

## ---- 5. exclusion flow -----------------------------------------------------
dat$step_age  <- dat$RIDAGEYR >= 30
dat$step_bp   <- dat$step_age & dat$bp_valid
dat$in_sample <- dat$step_bp & !is.na(dat$smoke) & !is.na(dat$ohq845_raw + 0) &
                 !is.na(dat$oral4) & !is.na(dat$perio)
n0 <- nrow(dat); n1 <- sum(dat$step_age); n2 <- sum(dat$step_bp); n3 <- sum(dat$in_sample)
flow <- data.frame(
  step = 0:3,
  description = c("All DEMO participants, cycles F-J (2009-2018)",
                  "Age >= 30",
                  "Has mean SBP (DBP may be NA when all readings were 0) (without BP excluded)",
                  "Non-missing smoking, OHQ845 (oral health) and OHQ835 (periodontal); final sample"),
  n_removed = c(NA, n0 - n1, n1 - n2, n2 - n3),
  n_remaining = c(n0, n1, n2, n3),
  paper_n = c(NA, NA, 19398, 1090),
  paper_n_remaining = c(NA, NA, NA, 21800))
flow$diff_removed_vs_paper <- flow$n_removed - flow$paper_n
flow$diff_remaining_vs_paper <- flow$n_remaining - flow$paper_n_remaining
write.csv(flow, "output/tables/exclusion_flow_v2.csv", row.names = FALSE, na = "")
print(flow)

## ---- 6. save (full file, then analytic subset) --------------------------------
dat$htn_measured <- as.logical(dat$htn_measured); dat$htn_diagnosed <- as.logical(dat$htn_diagnosed)
front <- c("SEQN", "cycle", "SDMVPSU", "SDMVSTRA", "WTMEC2YR", "WTDRD1", "WTSAF2YR",
           "wt_mec10", "wt_dr10", "in_sample")
dat <- dat[, c(front, setdiff(names(dat), front))]
saveRDS(dat, "data/processed/oral_htn_full_v2.rds")
saveRDS(dat[dat$in_sample, ], "data/processed/oral_htn_analytic_v2.rds")

## ---- 7. 2x2 checks vs paper ------------------------------------------------------
an <- dat[dat$in_sample, ]
cat("\nHTN in sample: n =", nrow(an), " htn=1:", sum(an$htn == 1, na.rm = TRUE),
    " htn=0:", sum(an$htn == 0, na.rm = TRUE), " htn NA:", sum(is.na(an$htn)), "\n")
mk <- function(var, lev, paper) {
  d <- an[!is.na(an$htn), ]
  data.frame(exposure = var, level = lev,
             our_htn = sapply(lev, function(l) sum(d[[var]] == l & d$htn == 1)),
             our_total = sapply(lev, function(l) sum(an[[var]] == l)),
             paper_htn = paper[, 1], paper_total = paper[, 2], row.names = NULL)
}
chk <- rbind(
  mk("oral4", levels(an$oral4), cbind(c(3185, 3757, 2620, 1455), c(6769, 7536, 4994, 2501))),
  mk("perio", levels(an$perio), cbind(c(8839, 2178), c(17717, 4083))))
chk$diff_htn <- chk$our_htn - chk$paper_htn; chk$diff_total <- chk$our_total - chk$paper_total
write.csv(chk, "output/tables/build_2x2_check_v2.csv", row.names = FALSE)
print(chk)
cat("Total HTN cases:", sum(an$htn == 1, na.rm = TRUE), "(paper 11017)\n")

## ---- 8. build_decisions.csv ------------------------------------------------------------
D <- function(item, choice, reason, paper_says) data.frame(item, choice, reason, paper_says)
dec <- bind_rows(
 D("cycles", "F, G, H, I, J (2009-2018)", "paper uses five cycles 2009-2018", "2009-2018 five cycles"),
 D("files", paste0(paste(tables, collapse = ", "), " with cycle suffix _F.._J; BPX_J (auscultatory) used in 2017-18, never BPXO_J"),
   "mapping table in script; raw codes via nhanes(translated = FALSE)", "NHANES; BP by mercury sphygmomanometer"),
 D("starting population", "All DEMO participants of the 5 cycles (all ages, incl. interview-only)", "design built on full file, subset later", "not stated"),
 D("exclusion order", "age>=30 -> mean SBP present (v2) -> non-missing smoking, OHQ845, OHQ835 (sequential)",
   "assigned by requester; paper order of its two steps is not explicit",
   "n=19,398 without BP; n=1,090 missing smoking/oral/perio; final 21,800; paper figures sum to 42,288 (plan A1)"),
 D("weight (main)", "wt_mec10 = WTMEC2YR / 5", "labs are MEC-based; 5 cycles pooled; lipids/GHB/BIOPRO need MEC weight at least",
   "not stated (weights created by NCHS)"),
 D("weight (alternatives kept)", "wt_dr10 = WTDRD1 / 5; WTSAF2YR kept unscaled (from TRIGLY, fasting subsample)", "diet items use day-1 dietary weight; sensitivity use", "not stated"),
 D("blood pressure mean", sprintf("BPXDI1-4 == 0 set to NA before averaging (%d zeros set to NA); BPXSY zeros left (found %d); mean of available readings of the 4 BPXSY and 4 BPXDI; first reading not dropped; v2: valid = >=1 SBP reading (DBP may be NA: %d people aged >=30 have SBP but all DBP 0/NA)", n_di0, n_sy0, n_dbp_na_valid),
   "DBP 0 is a device artefact, not a pressure", "average of measurements; whether first reading dropped: not stated"),
 D("htn_measured", "mean SBP >= 140 | mean DBP >= 90; v2: DBP NA counts as not >= 90", "paper cut-offs", "SBP>=140 and/or DBP>=90"),
 D("htn_diagnosed", "BPQ020 == 1 | BPQ050A == 1; TRUE if either yes, FALSE if BPQ020 == 2, NA if BPQ020 is NA/7/9 with no yes",
   "BPQ050A skip-pattern NA (BPQ040A not 1 / BPQ020 not 1) = not taking, never missing; BPQ050A cannot add cases beyond BPQ020 because it is asked only of BPQ020==1",
   "ever told hypertension; taking prescribed BP medicine"),
 D("htn (outcome)", sprintf("1 if htn_measured or htn_diagnosed TRUE; 0 if both FALSE; NA if measured FALSE and BPQ020 is 7/9/NA. 7/9 on BPQ020 (n=%d) / BPQ050A (n=%d) = true non-response, not counted as affirmative; such people are NOT excluded from the sample (htn NA n=%d in sample)",
   n_q20_nonresp, n_q50_nonresp, sum(is.na(an$htn))),
   "exclusion steps in the request do not include outcome missingness", "any affirmative answer"),
 D("oral4", "OHQ845: 1-2 = Excellent/Very good (reference), 3 Good, 4 Fair, 5 Poor; 7/9 and NA = missing; raw kept as ohq845_raw",
   "paper table grouping", "Excellent/Very good, Good, Fair, Poor"),
 D("perio", "OHQ835: 1 = Yes, 2 = No (reference); 7/9 = missing; raw kept as ohq835_raw", "self-reported gum disease", "yes/no; reference No"),
 D("smoking", "SMQ020 == 1 (>=100 cigarettes in life) = Yes, 2 = No; 7/9 = missing", "ever-smoker definition chosen", "yes/no; definition not stated"),
 D("age", "RIDAGEYR continuous; sample age >= 30", "paper", ">= 30 years"),
 D("sex", "RIAGENDR 1 Male, 2 Female", "", "not stated (Male/Female in Table 1)"),
 D("race", "RIDRETH1 five groups", "paper's five groups match RIDRETH1, not RIDRETH3", "5 groups"),
 D("education", "DMDEDUC2: 1-2 <HS, 3 HS, 4-5 >HS, 7/9 and NA = NA (missing category made at modelling stage)", "paper categories", "<HS, HS, >HS (+Missing in Table 1)"),
 D("BMI", "BMXBMI continuous (bmi) and categories [<18.5), [18.5,25), [25,30), >=30; NA stays NA", "paper cut-offs; 24.9-25 gap closed by half-open intervals", "<18.5, 18.5~24.9, 25~29.9, >=30"),
 D("alcohol", "Drinking DAYS per week from the past-12-month frequency item, as a proxy for drinks/week: F-I ALQ120Q x ALQ120U (week; month x12/52; year /52); J ALQ121 category midpoints (0 never; 1 every day=7; 2=6; 3-4/wk=3.5; 2/wk=2; 1/wk=1; 2-3/month=2.5*12/52; 1/month=12/52; 7-11/yr=9/52; 3-6/yr=4.5/52; 1-2/yr=1.5/52). Lifetime abstainers (ALQ101==2 & ALQ110==2, or ALQ111==2) who skip the item = 0. 0 = No drinks, (0,1] = <=1/week, >1 = >1/week. Missing if frequency 777/999/NA and not an abstainer",
   "no drinks-per-day (ALQ130) used because the paper gives no volume rule; ALQ121 replaces ALQ120Q/U only in 2017-18 (cycle I still has ALQ120Q/U; plan A4)", "no drinks, <=1 drink/week, >1 drink/week; unit not stated"),
 D("physical activity", "Active if any of PAQ605, PAQ620, PAQ650, PAQ665 == 1; Inactive if no yes and at least one answered 2; NA if none answered (7/9 treated as unanswered)",
   "work + recreation vigorous/moderate items", "active or inactive; definition not stated"),
 D("sleep", "F-H SLD010H (77/99 NA), I-J SLD012; <7, 7-9 inclusive, >9 hours", "variable renamed in 2015", "<7, 7 to 9, >9 h"),
 D("continuous labs", "LBXTC (TCHOL), LBDHDD (HDL), LBXTR (TRIGLY), LBXGH (GHB), LBXSCR (BIOPRO) kept as raw conventional units, no transformation", "paper lists them without transformation", "continuous, not stated"),
 D("diet", "DR1TSODI (mg), DR1TTFAT (g), day-1 recall; no transformation", "", "sodium, fat; not stated"),
 D("CVD", "Yes if any of MCQ160B/C/D/E/F == 1; No if no yes and at least one 2; NA otherwise (7/9 unanswered)", "CHF, CHD, angina, MI, stroke", "yes/no; definition not stated"),
 D("diabetes", "DIQ010 1 = Yes; 2 and 3 (borderline) = No; 7/9 = NA; raw kept as diq010_raw", "borderline is not diagnosed diabetes; raw lets a 3-level version be rebuilt (plan A2)", "yes/no; definition not stated"),
 D("covariate missing", "No exclusion on covariates; missing left as NA, 'Missing' category / indicator to be created at modelling", "paper uses missing categories", "additional missing categories + dummy indicators"),
 D("saved files", "oral_htn_full_v2.rds (all DEMO, in_sample flag) and oral_htn_analytic_v2.rds (in_sample rows)", "build svydesign on full, subset() after", "not stated"))
write.csv(dec, "output/tables/build_decisions_v2.csv", row.names = FALSE)
cat("done\n")
