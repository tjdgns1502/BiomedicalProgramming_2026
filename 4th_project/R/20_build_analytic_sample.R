## 20_build_analytic_sample.R
##
## Phase 2 build: NHANES 1999-2016, age >= 50, CBC-derived inflammatory
## markers (NLR/MLR/SIRI/SII) x modified Rockwood frailty index, reproducing
## Han et al. BMC Public Health 2024;24:3408.
##
## Downloads all files listed in output/tables/nhanes_file_plan.csv (caching
## to data/raw/), merges on SEQN within cycle, pools 9 cycles (1999-2000
## through 2015-2016), builds the frailty index and CBC ratios, applies the
## Fig. 1 exclusion flow, and writes the analysis dataset plus the required
## bookkeeping tables (download_log.csv, exclusion_flow.csv,
## build_decisions.csv).
##
## Every unstated-in-the-paper rule is a deliberate, documented choice -
## see output/tables/build_decisions.csv. N is reported as-is; it is never
## adjusted to chase the paper's numbers.

suppressMessages(library(nhanesA))

raw_dir  <- "data/raw"
proc_dir <- "data/processed"
tab_dir  <- "output/tables"
dir.create(raw_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(proc_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tab_dir,  showWarnings = FALSE, recursive = TRUE)

## ---------------------------------------------------------------
## 0. Download helper (cache to data/raw/, log every call)
## ---------------------------------------------------------------
download_log <- list()

get_nhanes <- function(table_name, cycle, purpose) {
  if (is.na(table_name)) return(NULL)
  cache_path <- file.path(raw_dir, paste0(table_name, ".rds"))
  if (file.exists(cache_path)) {
    dat <- readRDS(cache_path)
    status <- "cached"
  } else {
    dat <- tryCatch(nhanesA::nhanes(table_name, translated = FALSE),
                     error = function(e) NULL)
    if (is.null(dat)) {
      status <- "download_failed"
    } else {
      saveRDS(dat, cache_path)
      status <- "downloaded"
    }
  }
  download_log[[length(download_log) + 1]] <<- data.frame(
    cycle = cycle, table_name = table_name, purpose = purpose,
    status = status,
    n_row = if (is.null(dat)) NA_integer_ else nrow(dat),
    n_col = if (is.null(dat)) NA_integer_ else ncol(dat),
    date = as.character(Sys.Date()),
    stringsAsFactors = FALSE
  )
  dat
}

## ---------------------------------------------------------------
## 1. Cycle metadata (file names per cycle, from nhanes_file_plan.csv)
## ---------------------------------------------------------------
cycles <- data.frame(
  cycle    = c("1999-2000","2001-2002","2003-2004","2005-2006","2007-2008",
               "2009-2010","2011-2012","2013-2014","2015-2016"),
  suf      = c("","_B","_C","_D","_E","_F","_G","_H","_I"),
  weight_era = c("4yr","4yr","2yr","2yr","2yr","2yr","2yr","2yr","2yr"),
  stringsAsFactors = FALSE
)
mk <- function(prefix) paste0(prefix, cycles$suf)

cycles$demo <- mk("DEMO")
cycles$bmx  <- mk("BMX")
cycles$bpx  <- mk("BPX")
cycles$cbc  <- c("LAB25","L25_B","L25_C","CBC_D","CBC_E","CBC_F","CBC_G","CBC_H","CBC_I")
cycles$bio  <- c("LAB18","L40_B","L40_C","BIOPRO_D","BIOPRO_E","BIOPRO_F","BIOPRO_G","BIOPRO_H","BIOPRO_I")
cycles$mcq  <- mk("MCQ")
cycles$diq  <- mk("DIQ")
cycles$bpq  <- mk("BPQ")
cycles$kiq  <- c("KIQ","KIQ_U_B","KIQ_U_C","KIQ_U_D","KIQ_U_E","KIQ_U_F","KIQ_U_G","KIQ_U_H","KIQ_U_I")
cycles$pfq  <- mk("PFQ")
cycles$huq  <- mk("HUQ")
cycles$rxq  <- mk("RXQ_RX")
cycles$smq  <- mk("SMQ")
cycles$alq  <- mk("ALQ")
cycles$paq  <- mk("PAQ")
cycles$dr1  <- c(NA, NA, "DR1TOT_C","DR1TOT_D","DR1TOT_E","DR1TOT_F","DR1TOT_G","DR1TOT_H","DR1TOT_I")
cycles$dr2  <- c(NA, NA, "DR2TOT_C","DR2TOT_D","DR2TOT_E","DR2TOT_F","DR2TOT_G","DR2TOT_H","DR2TOT_I")
cycles$drx  <- c("DRXTOT","DRXTOT_B", NA,NA,NA,NA,NA,NA,NA)

## helper: pick first existing column from a data.frame
pick <- function(df, ...) {
  cands <- c(...)
  for (nm in cands) if (nm %in% names(df)) return(df[[nm]])
  rep(NA_real_, nrow(df))
}
has <- function(df, nm) !is.null(df) && nm %in% names(df)

## recode a standard NHANES yes/no item (1=yes,2=no,7/9=missing) to 0/1
yn01 <- function(x) ifelse(x %in% 1, 1, ifelse(x %in% 2, 0, NA_real_))

## ---------------------------------------------------------------
## 2. Per-cycle download + standardize + merge
## ---------------------------------------------------------------
cycle_frames <- vector("list", nrow(cycles))

for (i in seq_len(nrow(cycles))) {
  cyc <- cycles$cycle[i]
  message("== ", cyc, " ==")

  demo <- get_nhanes(cycles$demo[i], cyc, "demographics")
  bmx  <- get_nhanes(cycles$bmx[i],  cyc, "BMI")
  bpx  <- get_nhanes(cycles$bpx[i],  cyc, "blood pressure/pulse")
  cbc  <- get_nhanes(cycles$cbc[i],  cyc, "CBC differential")
  bio  <- get_nhanes(cycles$bio[i],  cyc, "biochemistry profile")
  mcq  <- get_nhanes(cycles$mcq[i],  cyc, "medical conditions")
  diq  <- get_nhanes(cycles$diq[i],  cyc, "diabetes")
  bpq  <- get_nhanes(cycles$bpq[i],  cyc, "hypertension")
  kiq  <- get_nhanes(cycles$kiq[i],  cyc, "kidney")
  pfq  <- get_nhanes(cycles$pfq[i],  cyc, "physical function")
  huq  <- get_nhanes(cycles$huq[i],  cyc, "health status/use")
  rxq  <- get_nhanes(cycles$rxq[i],  cyc, "medications")
  smq  <- get_nhanes(cycles$smq[i],  cyc, "smoking")
  alq  <- get_nhanes(cycles$alq[i],  cyc, "alcohol")
  paq  <- get_nhanes(cycles$paq[i],  cyc, "physical activity")
  dr1  <- get_nhanes(cycles$dr1[i],  cyc, "dietary recall day 1")
  dr2  <- get_nhanes(cycles$dr2[i],  cyc, "dietary recall day 2")
  drx  <- get_nhanes(cycles$drx[i],  cyc, "dietary recall single day")

  if (is.null(demo)) stop("DEMO failed to download for ", cyc)

  d <- data.frame(SEQN = demo$SEQN, stringsAsFactors = FALSE)
  d$cycle    <- cyc
  d$age      <- demo$RIDAGEYR
  d$sex      <- demo$RIAGENDR
  d$race     <- demo$RIDRETH1
  d$pir      <- pick(demo, "INDFMPIR")
  d$educ     <- pick(demo, "DMDEDUC2")
  d$sdmvpsu  <- demo$SDMVPSU
  d$sdmvstra <- demo$SDMVSTRA

  ## ---- weight: coordinator's rule -------------------------------
  if (cycles$weight_era[i] == "4yr") {
    d$wt_mec_raw <- pick(demo, "WTMEC4YR")
    d$wt_pooled  <- d$wt_mec_raw * (2 / 9)
  } else {
    d$wt_mec_raw <- pick(demo, "WTMEC2YR")
    d$wt_pooled  <- d$wt_mec_raw * (1 / 9)
  }

  merge_in <- function(base, other, cols) {
    if (is.null(other)) {
      for (cn in cols) base[[cn]] <- NA_real_
      return(base)
    }
    keep <- c("SEQN", intersect(cols, names(other)))
    other_sub <- other[, keep, drop = FALSE]
    missing_cols <- setdiff(cols, names(other_sub))
    for (cn in missing_cols) other_sub[[cn]] <- NA_real_
    merge(base, other_sub, by = "SEQN", all.x = TRUE, sort = FALSE)
  }

  d <- merge_in(d, bmx, "BMXBMI")

  if (!is.null(bpx)) {
    sy_cols <- intersect(c("BPXSY1","BPXSY2","BPXSY3","BPXSY4"), names(bpx))
    di_cols <- intersect(c("BPXDI1","BPXDI2","BPXDI3","BPXDI4"), names(bpx))
    ## NHANES records a diastolic reading of 0 when the sound was inaudible;
    ## treat 0 as missing for that single reading before averaging, not as a
    ## true diastolic pressure of zero
    di_clean <- bpx[di_cols]
    di_clean[di_clean == 0] <- NA
    bpx$sbp_mean <- if (length(sy_cols)) rowMeans(bpx[sy_cols], na.rm = TRUE) else NA_real_
    bpx$dbp_mean <- if (length(di_cols)) rowMeans(di_clean, na.rm = TRUE) else NA_real_
    bpx$sbp_mean[is.nan(bpx$sbp_mean)] <- NA_real_
    bpx$dbp_mean[is.nan(bpx$dbp_mean)] <- NA_real_
    d <- merge_in(d, bpx, c("BPXPLS","sbp_mean","dbp_mean"))
  } else {
    d$BPXPLS <- NA_real_; d$sbp_mean <- NA_real_; d$dbp_mean <- NA_real_
  }

  d <- merge_in(d, cbc, c("LBDNENO","LBDLYMNO","LBDMONO","LBXPLTSI","LBXRDW"))
  ## L40_B (2001-2002 only) names ALP and LDH with a D prefix (LBDSAPSI,
  ## LBDSLDSI) instead of the X prefix used in every other cycle - resolved
  ## dynamically by column presence, not assumed from cycle
  if (!is.null(bio)) {
    bio$alp_var <- if (has(bio, "LBXSAPSI")) bio$LBXSAPSI else pick(bio, "LBDSAPSI")
    bio$ldh_var <- if (has(bio, "LBXSLDSI")) bio$LBXSLDSI else pick(bio, "LBDSLDSI")
  }
  d <- merge_in(d, bio, c("LBXSBU","LBXSC3SI","LBDSCASI","LBDSUASI","alp_var","ldh_var"))

  if (!is.null(mcq)) {
    mcq$thyroid <- if (has(mcq, "MCQ160M")) mcq$MCQ160M else pick(mcq, "MCQ160I")
    d <- merge_in(d, mcq, c("MCQ160A","MCQ160C","MCQ160D","MCQ160E","MCQ160F","MCQ220","thyroid"))
  } else {
    for (cn in c("MCQ160A","MCQ160C","MCQ160D","MCQ160E","MCQ160F","MCQ220","thyroid")) d[[cn]] <- NA_real_
  }

  d <- merge_in(d, diq, "DIQ010")
  d <- merge_in(d, bpq, "BPQ020")

  if (!is.null(kiq)) {
    kiq$kidney <- if (has(kiq, "KIQ022")) kiq$KIQ022 else pick(kiq, "KIQ020")
    d <- merge_in(d, kiq, "kidney")
  } else d$kidney <- NA_real_

  if (!is.null(pfq)) {
    pfq$confusion   <- if (has(pfq, "PFQ057")) pfq$PFQ057 else pick(pfq, "PFQ056")
    pfq$money       <- if (has(pfq, "PFQ061A")) pfq$PFQ061A else pick(pfq, "PFQ060A")
    pfq$stoop       <- if (has(pfq, "PFQ061D")) pfq$PFQ061D else pick(pfq, "PFQ060D")
    pfq$lift        <- if (has(pfq, "PFQ061E")) pfq$PFQ061E else pick(pfq, "PFQ060E")
    pfq$walk_rooms  <- if (has(pfq, "PFQ061H")) pfq$PFQ061H else pick(pfq, "PFQ060H")
    pfq$stand_chair <- if (has(pfq, "PFQ061I")) pfq$PFQ061I else pick(pfq, "PFQ060I")
    pfq$bed         <- if (has(pfq, "PFQ061J")) pfq$PFQ061J else pick(pfq, "PFQ060J")
    pfq$dress       <- if (has(pfq, "PFQ061L")) pfq$PFQ061L else pick(pfq, "PFQ060L")
    pfq$grasp       <- if (has(pfq, "PFQ061P")) pfq$PFQ061P else pick(pfq, "PFQ060P")
    pfq$social      <- if (has(pfq, "PFQ061R")) pfq$PFQ061R else pick(pfq, "PFQ060R")
    d <- merge_in(d, pfq, c("confusion","money","stoop","lift","walk_rooms","stand_chair","bed","dress","grasp","social"))
  } else {
    for (cn in c("confusion","money","stoop","lift","walk_rooms","stand_chair","bed","dress","grasp","social")) d[[cn]] <- NA_real_
  }

  if (!is.null(huq)) {
    ## healthcare_use_var records WHICH variable/bucket scheme was used
    ## (HUQ050 pre-2013 vs HUQ051 2013+) so the FI scoring step can apply the
    ## correct per-variable "10+ visits" cutoff later
    huq$healthcare_use <- if (has(huq, "HUQ051")) huq$HUQ051 else pick(huq, "HUQ050")
    huq$healthcare_use_var <- if (has(huq, "HUQ051")) "HUQ051" else "HUQ050"
    ## HUQ070 (1999-2000) / HUD070 (2001-2002, note the D) / HUQ071 (2003+)
    huq$hosp_overnight <- if (has(huq, "HUQ071")) huq$HUQ071
                           else if (has(huq, "HUQ070")) huq$HUQ070
                           else pick(huq, "HUD070")
    d <- merge_in(d, huq, c("HUQ010","HUQ020","healthcare_use","hosp_overnight"))
    d$healthcare_use_var <- unique(huq$healthcare_use_var)[1]
  } else {
    for (cn in c("HUQ010","HUQ020","healthcare_use","hosp_overnight")) d[[cn]] <- NA_real_
    d$healthcare_use_var <- NA_character_
  }

  ## medications: total count per SEQN from RXQ_RX (0 if not in file).
  ## RXQ_RX/RXQ_RX_B (1999-2002) have no RXDCOUNT - the per-person medication
  ## count there is RXD295 ("Number of prescription medicines taken"),
  ## repeated on every drug row for that person, same structure as RXDCOUNT
  ## in later cycles. Resolved dynamically by column presence.
  med_var <- if (!is.null(rxq) && "RXDCOUNT" %in% names(rxq)) "RXDCOUNT"
             else if (!is.null(rxq) && "RXD295" %in% names(rxq)) "RXD295"
             else NA_character_
  if (!is.null(rxq) && !is.na(med_var)) {
    rxq$med_var_tmp <- rxq[[med_var]]
    med_cnt <- aggregate(med_var_tmp ~ SEQN, data = rxq, FUN = function(x) max(x, na.rm = TRUE))
    names(med_cnt) <- c("SEQN", "meds_count")
    d <- merge(d, med_cnt, by = "SEQN", all.x = TRUE, sort = FALSE)
    d$meds_count[is.na(d$meds_count)] <- 0
  } else {
    d$meds_count <- NA_real_
  }

  d <- merge_in(d, smq, c("SMQ020"))

  ## alcohol: ALQ100 (1999-2000) vs ALQ101 (2001-2016) for past-year; ALQ110 lifetime (all cycles)
  if (!is.null(alq)) {
    alq$alq_pastyear <- if (has(alq, "ALQ101")) alq$ALQ101 else if (has(alq, "ALQ100")) alq$ALQ100 else pick(alq, "ALD100")
    d <- merge_in(d, alq, c("alq_pastyear","ALQ110"))
  } else {
    d$alq_pastyear <- NA_real_; d$ALQ110 <- NA_real_
  }

  ## physical activity: harmonize by era - determined by which columns the
  ## downloaded PAQ file actually has, not by assumed cycle cutoffs (GPAQ
  ## started in 2007-2008, NOT 2005-2006 - 2005-2006 (PAQ_D) still used the
  ## old PAQ180 instrument, confirmed by inspecting the raw column names)
  if (!is.null(paq) && has(paq, "PAQ180")) {
    d <- merge_in(d, paq, "PAQ180")
    d$PAQ605 <- NA_real_; d$PAQ620 <- NA_real_; d$PAQ650 <- NA_real_; d$PAQ665 <- NA_real_
  } else if (!is.null(paq) && has(paq, "PAQ605")) {
    d <- merge_in(d, paq, c("PAQ605","PAQ620","PAQ650","PAQ665"))
    d$PAQ180 <- NA_real_
  } else {
    d$PAQ180 <- NA_real_
    d$PAQ605 <- NA_real_; d$PAQ620 <- NA_real_; d$PAQ650 <- NA_real_; d$PAQ665 <- NA_real_
  }

  ## dietary energy intake
  if (i <= 2) {
    d <- merge_in(d, drx, "DRXTKCAL")
    d$kcal_day <- d$DRXTKCAL
    d$energy_ndays <- ifelse(is.na(d$DRXTKCAL), 0, 1)
  } else {
    d1 <- if (!is.null(dr1)) dr1[, intersect(c("SEQN","DR1TKCAL"), names(dr1)), drop = FALSE] else NULL
    d2 <- if (!is.null(dr2)) dr2[, intersect(c("SEQN","DR2TKCAL"), names(dr2)), drop = FALSE] else NULL
    d <- merge_in(d, d1, "DR1TKCAL")
    d <- merge_in(d, d2, "DR2TKCAL")
    d$kcal_day <- rowMeans(d[, c("DR1TKCAL","DR2TKCAL")], na.rm = TRUE)
    d$kcal_day[is.nan(d$kcal_day)] <- NA_real_
    d$energy_ndays <- rowSums(!is.na(d[, c("DR1TKCAL","DR2TKCAL")]))
  }

  cycle_frames[[i]] <- d
  message("   n = ", nrow(d))
}

## ---------------------------------------------------------------
## 3. Pool cycles
## ---------------------------------------------------------------
all_cols <- unique(unlist(lapply(cycle_frames, names)))
cycle_frames <- lapply(cycle_frames, function(d) {
  missing <- setdiff(all_cols, names(d))
  for (cn in missing) d[[cn]] <- NA
  d[all_cols]
})
full <- do.call(rbind, cycle_frames)
full$cycle <- factor(full$cycle, levels = cycles$cycle)
## strata must be unique across pooled cycles (SDMVSTRA numbering restarts each cycle)
full$sdmvstra_pooled <- paste(full$cycle, full$sdmvstra)

cat("Pooled full N (all ages, 9 cycles) =", nrow(full), "\n")

## ---------------------------------------------------------------
## 4. CBC-derived inflammatory markers
## ---------------------------------------------------------------
full$NLR  <- full$LBDNENO / full$LBDLYMNO
full$MLR  <- full$LBDMONO / full$LBDLYMNO
full$SIRI <- (full$LBDNENO * full$LBDMONO) / full$LBDLYMNO
full$SII  <- (full$LBXPLTSI * full$LBDNENO) / full$LBDLYMNO

## ---------------------------------------------------------------
## 5. Frailty index (36 items, binary 0/1 scoring throughout per the paper's
##    Methods: "scored 1 if criterion met, 0 if not" - see build_decisions.csv)
## ---------------------------------------------------------------
fi <- data.frame(SEQN = full$SEQN)

## -- self-report binary items (1=yes -> deficit 1, 2=no -> 0) --------------
fi$angina    <- yn01(full$MCQ160D)
fi$heart_att <- yn01(full$MCQ160E)
fi$chd       <- yn01(full$MCQ160C)
fi$stroke    <- yn01(full$MCQ160F)
fi$thyroid   <- yn01(full$thyroid)
fi$cancer    <- yn01(full$MCQ220)
fi$arthritis <- yn01(full$MCQ160A)
fi$hbp       <- yn01(full$BPQ020)
fi$kidney    <- yn01(full$kidney)
fi$confusion <- yn01(full$confusion)

## diabetes: yes=1, {no, borderline}=0 - binary per paper's Methods (criterion
## is "diabetes"; borderline does not meet that criterion)
fi$diabetes <- ifelse(full$DIQ010 %in% 1, 1,
                ifelse(full$DIQ010 %in% c(2,3), 0, NA_real_))

## PFQ difficulty items: 1=no difficulty->0; 2/3/4=any difficulty->1;
## 5="does not do this activity" -> NA (ambiguous, not a health assessment)
diff01 <- function(x) ifelse(x %in% 1, 0, ifelse(x %in% c(2,3,4), 1, NA_real_))
fi$money       <- diff01(full$money)
fi$stoop       <- diff01(full$stoop)
fi$lift        <- diff01(full$lift)
fi$walk_rooms  <- diff01(full$walk_rooms)
fi$stand_chair <- diff01(full$stand_chair)
fi$bed         <- diff01(full$bed)
fi$dress       <- diff01(full$dress)
fi$grasp       <- diff01(full$grasp)
fi$social      <- diff01(full$social)

## self-rated health: binary per paper's Methods - deficit (1) if fair or
## poor (HUQ010 4 or 5), else 0 (excellent/very good/good)
fi$health_gen <- ifelse(full$HUQ010 %in% c(4,5), 1, ifelse(full$HUQ010 %in% c(1,2,3), 0, NA_real_))

## health vs 1 year ago: 1=better,2=worse,3=same -> deficit if worse
fi$health_vs_yr <- ifelse(full$HUQ020 %in% 2, 1, ifelse(full$HUQ020 %in% c(1,3), 0, NA_real_))

## healthcare use: intended rule is "10+ visits/year" = high use (our choice,
## see build_decisions), but the two bucket-coded variables use DIFFERENT
## code schemes and the cutoff must be applied per variable:
##   HUQ050 (1999-2012): 0=None,1=1,2=2-3,3=4-9,4=10-12,5=13+  -> 10+ is code >=4
##   HUQ051 (2013-2016): 0=None,1=1,2=2-3,3=4-5,4=6-7,5=8-9,6=10-12,7=13-15,8=16+ -> 10+ is code >=6
## (an earlier build applied the HUQ051 cutoff of >=6 to both variables,
## which HUQ050 can never satisfy since it tops out at code 5)
huq050_hi <- full$healthcare_use_var %in% "HUQ050" & full$healthcare_use %in% 0:5 & full$healthcare_use >= 4
huq050_lo <- full$healthcare_use_var %in% "HUQ050" & full$healthcare_use %in% 0:5 & full$healthcare_use < 4
huq051_hi <- full$healthcare_use_var %in% "HUQ051" & full$healthcare_use %in% 0:8 & full$healthcare_use >= 6
huq051_lo <- full$healthcare_use_var %in% "HUQ051" & full$healthcare_use %in% 0:8 & full$healthcare_use < 6
fi$healthcare_use <- ifelse(huq050_hi | huq051_hi, 1, ifelse(huq050_lo | huq051_lo, 0, NA_real_))

## overnight hospital stay: 1=yes,2=no
fi$hosp_overnight <- yn01(full$hosp_overnight)

## medications: polypharmacy >=5 (our choice, see build_decisions); 0 meds is a valid 0, never missing
fi$meds <- ifelse(is.na(full$meds_count), NA_real_, ifelse(full$meds_count >= 5, 1, 0))

## -- lab items (deficit if outside Supplemental Table S1 range) ------------
fi$pulse    <- ifelse(is.na(full$BPXPLS), NA_real_, ifelse(full$BPXPLS < 60 | full$BPXPLS > 99, 1, 0))
fi$sbp      <- ifelse(is.na(full$sbp_mean), NA_real_, ifelse(full$sbp_mean < 90 | full$sbp_mean > 140, 1, 0))
pulse_press <- full$sbp_mean - full$dbp_mean
fi$pulse_pressure <- ifelse(is.na(pulse_press), NA_real_, ifelse(pulse_press < 30 | pulse_press > 60, 1, 0))
fi$platelet <- ifelse(is.na(full$LBXPLTSI), NA_real_, ifelse(full$LBXPLTSI < 150 | full$LBXPLTSI > 450, 1, 0))
fi$bun      <- ifelse(is.na(full$LBXSBU), NA_real_, ifelse(full$LBXSBU < 3 | full$LBXSBU > 20, 1, 0))
fi$bicarb   <- ifelse(is.na(full$LBXSC3SI), NA_real_, ifelse(full$LBXSC3SI > 28, 1, 0))
fi$rdw      <- ifelse(is.na(full$LBXRDW), NA_real_, ifelse(full$LBXRDW > 14.6, 1, 0))
fi$ldh      <- ifelse(is.na(full$ldh_var), NA_real_, ifelse(full$ldh_var > 190, 1, 0))
fi$alp      <- ifelse(is.na(full$alp_var), NA_real_, ifelse(full$alp_var > 115, 1, 0))
fi$uric_acid <- ifelse(is.na(full$LBDSUASI) | is.na(full$sex), NA_real_,
                 ifelse(full$sex == 1, ifelse(full$LBDSUASI < 240 | full$LBDSUASI > 510, 1, 0),
                        ifelse(full$LBDSUASI < 160 | full$LBDSUASI > 430, 1, 0)))
fi$calcium  <- ifelse(is.na(full$LBDSCASI), NA_real_, ifelse(full$LBDSCASI < 2.0 | full$LBDSCASI > 2.5, 1, 0))

item_cols <- setdiff(names(fi), "SEQN")
stopifnot(length(item_cols) == 36)

n_avail <- rowSums(!is.na(fi[item_cols]))
n_deficit <- rowSums(fi[item_cols], na.rm = TRUE)
FI <- n_deficit / n_avail
FI[n_avail == 0] <- NA_real_

full$fi_n_available <- n_avail
full$fi_score <- FI
full$frail <- ifelse(is.na(full$fi_score), NA, full$fi_score > 0.3)
full$frail_num <- as.numeric(full$frail)  # 0/1 numeric, for svymean()

## ---------------------------------------------------------------
## 6. Covariates
## ---------------------------------------------------------------
full$bmi <- full$BMXBMI
full$bmi_cat <- cut(full$bmi, breaks = c(-Inf, 25, 30, Inf),
                     labels = c("healthy(<=25)","overweight(25-<30)","obese(>=30)"), right = FALSE)

full$race_cat <- factor(full$race, levels = 1:5,
  labels = c("Mexican American","Other Hispanic","Non-Hispanic White","Non-Hispanic Black","Other race"))

full$educ_cat <- ifelse(full$educ %in% c(1,2), "less than high school",
                  ifelse(full$educ %in% 3, "high school graduate",
                  ifelse(full$educ %in% c(4,5), "college or higher", NA)))

full$pir_cat <- cut(full$pir, breaks = c(-Inf, 1.0, 3.0, Inf),
                     labels = c("<=1.0","1.1-3.0",">3.0"), right = TRUE)

full$smoker <- yn01(full$SMQ020)  # 1 = smoker (>=100 cigarettes lifetime), 0 = nonsmoker

## Drinker/non-drinker: two readings of the paper's wording were considered
## (see build_decisions.csv). USED reading, matched to paper Table 1's
## reported category counts (Yes 8386 / No 4494 / Missing 627): drinker =
## past-year variable (ALQ100/ALD100/ALQ101) == 1; non-drinker = that
## variable == 2 (ALQ110 lifetime not required); everything else = missing,
## RETAINED as its own category (not excluded at step 4).
full$drinker <- ifelse(full$alq_pastyear %in% 1, 1,
                 ifelse(full$alq_pastyear %in% 2, 0, NA_real_))
full$drinker_cat <- factor(
  ifelse(full$drinker %in% 1, "Yes", ifelse(full$drinker %in% 0, "No", "Missing data")),
  levels = c("Yes","No","Missing data"))
## alternative (NOT used): non-drinker requires BOTH past-year==No AND
## lifetime==No; kept only for the record in build_decisions.csv
full$drinker_alt_and_lifetime <- ifelse(full$alq_pastyear %in% 1, 1,
                 ifelse(full$alq_pastyear %in% 2 & full$ALQ110 %in% 2, 0, NA_real_))

full$hypertension <- yn01(full$BPQ020)
full$diabetes_cov <- ifelse(full$DIQ010 %in% 1, 1, ifelse(full$DIQ010 %in% c(2,3), 0, NA_real_))

## physical activity harmonized by era (pre-2007 PAQ180 vs 2007+ GPAQ)
pa_pre  <- ifelse(full$PAQ180 %in% 4, "active",
            ifelse(full$PAQ180 %in% 3, "moderate",
             ifelse(full$PAQ180 %in% c(1,2), "never", NA)))
## GPAQ refused (7) / don't know (9) must be treated as missing on that item,
## not as a "no" that could support a "never" classification
paq605c <- ifelse(full$PAQ605 %in% c(1,2), full$PAQ605, NA_real_)
paq620c <- ifelse(full$PAQ620 %in% c(1,2), full$PAQ620, NA_real_)
paq650c <- ifelse(full$PAQ650 %in% c(1,2), full$PAQ650, NA_real_)
paq665c <- ifelse(full$PAQ665 %in% c(1,2), full$PAQ665, NA_real_)
gpaq_any_answered <- rowSums(!is.na(cbind(paq605c, paq620c, paq650c, paq665c))) > 0
pa_post <- ifelse(paq605c %in% 1 | paq650c %in% 1, "active",
            ifelse(paq620c %in% 1 | paq665c %in% 1, "moderate",
             ifelse(gpaq_any_answered, "never", NA)))
## era is determined per cycle by which instrument actually has data in that
## cycle's downloaded file (GPAQ began in 2007-2008, not 2005-2006 - confirmed
## from raw column names, not assumed from the cycle label)
cycle_uses_paq180 <- tapply(!is.na(full$PAQ180), full$cycle, any)
full$pa_era <- ifelse(cycle_uses_paq180[as.character(full$cycle)], "pre-2007 (PAQ180)", "2007+ (GPAQ)")
full$pa_cat <- ifelse(full$pa_era == "pre-2007 (PAQ180)", pa_pre, pa_post)
full$pa_cat <- factor(full$pa_cat, levels = c("never","moderate","active"))

full$energy_kcal <- full$kcal_day

## ---------------------------------------------------------------
## 7. Exclusion flow (Fig. 1 order) - never tuned to match the paper
## ---------------------------------------------------------------
n0 <- nrow(full)

step1_pass <- !is.na(full$age) & full$age >= 50
n1_removed <- sum(!step1_pass)
n1 <- sum(step1_pass)

cbc_complete <- !is.na(full$LBDNENO) & !is.na(full$LBDLYMNO) & !is.na(full$LBDMONO) & !is.na(full$LBXPLTSI)
step2_pass <- step1_pass & cbc_complete
n2_removed <- sum(step1_pass) - sum(step2_pass)
n2 <- sum(step2_pass)

frailty_complete <- full$fi_n_available >= ceiling(0.8 * length(item_cols))
step3_pass <- step2_pass & frailty_complete
n3_removed <- sum(step2_pass) - sum(step3_pass)
n3 <- sum(step3_pass)

## The PFQ difficulty-with-activity battery (money/stooping/lifting/etc.) is
## only fielded in NHANES to respondents aged 60+, or to 20-59 year-olds who
## first screen positive on a limitation question (PFQ010/PFQ020-family) -
## most healthy 50-59 year-olds are skipped past it entirely and so fall
## below the 29/36 completeness threshold at step 3. This is NOT changed
## (kept as-is, per instruction) but is quantified here for transparency.
age_grp <- ifelse(full$age >= 60, "60+", ifelse(full$age >= 50, "50-59", NA))
fi_completeness_by_age <- data.frame(
  age_group = c("50-59","60+"),
  n_step2_pass = c(sum(step2_pass & age_grp == "50-59", na.rm = TRUE),
                   sum(step2_pass & age_grp == "60+", na.rm = TRUE)),
  n_step3_pass = c(sum(step3_pass & age_grp == "50-59", na.rm = TRUE),
                   sum(step3_pass & age_grp == "60+", na.rm = TRUE)),
  stringsAsFactors = FALSE
)
fi_completeness_by_age$pct_retained <- round(100 * fi_completeness_by_age$n_step3_pass /
                                                fi_completeness_by_age$n_step2_pass, 1)
write.csv(fi_completeness_by_age, file.path(tab_dir, "fi_completeness_by_age.csv"), row.names = FALSE)
print(fi_completeness_by_age)

## "drinker" deliberately excluded from this list: the paper's Table 1 shows
## "missing data" as a retained category for drinking status (627 of 13507),
## so a missing drinker value must not cause exclusion at this step.
covar_needed <- c("age","sex","cycle","race_cat","educ_cat","pir_cat","bmi_cat",
                   "pa_cat","energy_kcal","smoker","diabetes_cov","hypertension")
covar_complete <- Reduce(`&`, lapply(covar_needed, function(cn) !is.na(full[[cn]])))
step4_pass <- step3_pass & covar_complete
n4_removed <- sum(step3_pass) - sum(step4_pass)
n4 <- sum(step4_pass)

full$analytic_sample <- step4_pass

exclusion_flow <- data.frame(
  step = c("0_start","1_age_lt_50","2_cbc_incomplete","3_frailty_insufficient","4_covariates_missing"),
  description = c(
    "NHANES 1999-2016, all ages, 9 cycles pooled",
    "excluded: age < 50 years",
    "excluded: missing >=1 of LBDNENO/LBDLYMNO/LBDMONO/LBXPLTSI (cannot compute NLR/MLR/SIRI/SII)",
    "excluded: fewer than 80% (29/36) of frailty-index items answered",
    "excluded: missing >=1 Model-2 covariate (age/sex/cycle/race/education/PIR/BMI/PA/energy/smoking/diabetes/hypertension); drinking status excluded from this rule because 'missing data' is itself a retained category in the paper's Table 1"
  ),
  n_removed = c(NA, n1_removed, n2_removed, n3_removed, n4_removed),
  n_remaining = c(n0, n1, n2, n3, n4),
  ## paper's remaining N after step 3 is 19162-5503=13659, NOT 13507 (13507 is
  ## only reached after step 4's additional 152 removed for missing
  ## covariates); an earlier build wrongly repeated 13507 at step 3 too
  paper_n = c(92062, 21670, 19162, 13659, 13507),
  paper_removed = c(NA, 70392, 2508, 5503, 152),
  stringsAsFactors = FALSE
)
write.csv(exclusion_flow, file.path(tab_dir, "exclusion_flow.csv"), row.names = FALSE)
print(exclusion_flow)

## ---------------------------------------------------------------
## 8. Survey design on FULL data, then subset (per skill instructions)
## ---------------------------------------------------------------
if (requireNamespace("survey", quietly = TRUE)) {
  suppressMessages(library(survey))
  des_full <- svydesign(ids = ~sdmvpsu, strata = ~sdmvstra_pooled,
                         weights = ~wt_pooled, nest = TRUE, data = full)
  des_analytic <- subset(des_full, analytic_sample)
  saveRDS(des_analytic, file.path(proc_dir, "frailty_cbc_svydesign.rds"))
  cat("Survey design built on full data (N=", nrow(full), "), subset to analytic sample (N=",
      sum(full$analytic_sample), ")\n")
  frail_weighted_pct <- as.numeric(coef(survey::svymean(~frail_num, des_analytic, na.rm = TRUE))["frail_num"]) * 100
} else {
  message("survey package not installed - skipping svydesign build (data still saved).")
  frail_weighted_pct <- NA_real_
}

## ---------------------------------------------------------------
## 9. Physical-activity category counts by era (visibility on the PAQ break)
## ---------------------------------------------------------------
pa_by_era <- as.data.frame.matrix(table(full$pa_era[full$analytic_sample], full$pa_cat[full$analytic_sample]))
pa_by_era$era <- rownames(pa_by_era)
write.csv(pa_by_era, file.path(tab_dir, "pa_category_counts_by_era.csv"), row.names = FALSE)
print(pa_by_era)

## our unweighted overall distribution vs the paper's correct reference
## (Table 1, p.5: never 6519 / moderate 4717 / active 2271 of 13507 -
## Supplemental Table S2 swaps the never/active labels and should not be used)
pa_overall <- as.data.frame(table(full$pa_cat[full$analytic_sample]))
names(pa_overall) <- c("category", "n_unweighted")
pa_overall$paper_table1_n <- c(6519, 4717, 2271)[match(pa_overall$category, c("never","moderate","active"))]
write.csv(pa_overall, file.path(tab_dir, "pa_category_counts_overall.csv"), row.names = FALSE)
print(pa_overall)

## ---------------------------------------------------------------
## 9b. Drinking-status category counts in the analytic sample vs paper's
##     Table 1 (Yes 8386 / No 4494 / Missing data 627)
## ---------------------------------------------------------------
drink_counts <- as.data.frame(table(full$drinker_cat[full$analytic_sample]))
names(drink_counts) <- c("category", "n")
drink_counts$paper_table1_n <- c(8386, 4494, 627)[match(drink_counts$category, c("Yes","No","Missing data"))]
write.csv(drink_counts, file.path(tab_dir, "drinking_category_counts.csv"), row.names = FALSE)
print(drink_counts)

## ---------------------------------------------------------------
## 10. Save datasets
## ---------------------------------------------------------------
saveRDS(full, file.path(proc_dir, "frailty_cbc_pooled.rds"))
saveRDS(full[full$analytic_sample, ], file.path(proc_dir, "frailty_cbc_analytic.rds"))

## ---------------------------------------------------------------
## 11. download_log.csv
## ---------------------------------------------------------------
dl_df <- do.call(rbind, download_log)
write.csv(dl_df, file.path(raw_dir, "download_log.csv"), row.names = FALSE)

## ---------------------------------------------------------------
## 12. build_decisions.csv
## ---------------------------------------------------------------
bd <- list()
add_bd <- function(item, choice, reason, paper_says) {
  bd[[length(bd) + 1]] <<- data.frame(item = item, choice = choice, reason = reason,
                                       paper_says = paper_says, stringsAsFactors = FALSE)
}

add_bd("Cycles pooled", "1999-2000 through 2015-2016, 9 cycles",
       "matches paper's stated cycle list", "1999-2000, ..., 2015-2016 (stated)")

add_bd("Weight - 1999-2002", "WTMEC4YR * 2/9",
       "1999-2000 and 2001-2002 2-year weights are calibrated to different census bases; NHANES analytic guidance requires the 4-year weight for this span when pooling with later cycles",
       "not stated (no weight variable named anywhere in the paper)")

add_bd("Weight - 2003-2016", "WTMEC2YR * 1/9",
       "7 remaining 2-year cycles, each contributing 1/9 of the pooled 18-year span; MEC weight chosen because CBC and biochemistry-profile labs require at least the MEC subsample",
       "not stated")

add_bd("Pooled strata", "interaction(cycle, SDMVSTRA) used as the survey stratum",
       "SDMVSTRA codes are only unique within a cycle; without combining with cycle, pooled variance estimation would incorrectly treat different cycles' strata as identical",
       "not stated (design/weighting not described at all in Methods)")

add_bd("Energy intake source", "mean of available recall day(s): 2003-2016 mean(DR1TKCAL,DR2TKCAL) when both present else day 1; 1999-2002 single day (DRXTKCAL)",
       "1999-2000 and 2001-2002 NHANES only fielded a single 24-hr recall; a true 2-day mean is impossible for those cycles",
       "paper states 'mean of two days' uniformly; not achievable pre-2003 - recorded deviation")

add_bd("Energy intake weight", "MEC weight (wt_pooled) retained, not a dietary-specific weight",
       "instructed by coordinator; dietary day-2 subsample weights not introduced to avoid a second weighting scheme",
       "not stated")

add_bd("FI item count", "36 items, all present - 'Difficulty managing money' IS available and is included",
       "CORRECTED: an earlier build mistakenly dropped this item after misreading the truncated English question text of PFQ061A/PFQ060A as a battery lead-in sentence. Checking the SAS Label instead (via nhanesA::nhanesCodebook(), e.g. nhanesCodebook('PFQ_D','PFQ061A') -> SAS Label 'Managing money difficulty') confirms letter A is itself the first scored activity item ('difficulty managing money'), present with this exact label in every cycle (PFQ060A in PFQ/PFQ_B for 1999-2002, PFQ061A in PFQ_C..PFQ_I for 2003-2016). Scored identically to the other 8 PFQ difficulty items (0=no difficulty, 1=some/much/unable, NA if missing or 'does not do this activity')",
       "Supplemental Table S1 lists it as item 12 of 36 - now correctly matched to an NHANES variable; the item count matches the paper's 36")

add_bd("FI completeness rule", ">=80% of 36 items answered (>=29/36, i.e. ceiling(0.8*36)) required to compute FI; else FI=NA and excluded at step 3",
       "standard Rockwood/Searle-style completeness convention used in the frailty-index literature the paper cites (refs 21-23)",
       "not stated - paper only reports the excluded N (5503), not the rule")

add_bd("FI denominator when computable", "sum(deficits present) / n_items_answered (proportional scoring), not divided by fixed 36",
       "standard Rockwood frailty-index convention; keeps the index in the intended 0-1 range regardless of a few missing items",
       "not stated")

add_bd("PFQ skip pattern and step-3 age composition", "NO RULE CHANGE - kept as-is. The 9-item PFQ difficulty battery (money/stooping/lifting/walking rooms/standing from chair/bed/dressing/grasping/social events) is only administered by NHANES to respondents aged 60+, or to 20-59 year-olds who first screen positive on a preceding limitation question (PFQ010-family) - most healthy, unscreened 50-59 year-olds are skipped past the whole battery and therefore cannot reach 29/36 answered items. See output/tables/fi_completeness_by_age.csv for step-3 retention by age group (50-59 vs 60+)",
       "this is an NHANES questionnaire design feature, not a bug in this build; its effect is to disproportionately exclude healthy 50-59 year-olds at step 3, biasing the retained step-3+ sample toward older and toward the age-60+-screened-positive (i.e. more likely frail) part of the 50-59 group. The paper's own reported weighted median age of 66 [61,74] (well above the population median for a 50+ sample) is consistent with the same skip pattern being present, unacknowledged, in the paper's pipeline",
       "not stated - the paper does not mention the PFQ age/screener skip pattern or its effect on who can be assessed for frailty at all")

add_bd("Diabetes - FI item", "CORRECTED to binary: yes=1, {no, borderline}=0 (borderline no longer scored 0.5)",
       "paper's Methods (paper_methods.csv row 22) state items are scored 1 if the criterion is met, 0 if not - a half-point graded score for borderline is inconsistent with that binary rule; 'borderline diabetes' does not meet the criterion 'diabetes'",
       "row 22: 'scored as 1 point if criterion met, 0 points if not' - graded scoring contradicted this and has been removed")

add_bd("Diabetes - covariate", "binary: definite yes=1, {no, borderline}=0",
       "the covariate concept ('self-reported diabetes') is treated as a simple binary in the paper's covariate table; now identical in logic to the FI item (both binary, borderline=0)",
       "not stated how borderline is handled for the covariate")

add_bd("Self-rated health - FI item", "CORRECTED to binary: deficit (1) if fair or poor (HUQ010 in {4,5}); 0 if excellent/very good/good (no longer graded 0/.25/.5/.75/1)",
       "paper's Methods state binary 1/0 scoring for all FI items (paper_methods.csv row 22); fair-or-poor is the conventional binary cut for a 5-level self-rated-health item in the frailty-index literature",
       "row 22: 'scored as 1 point if criterion met, 0 points if not' - the earlier graded 5-level coding contradicted this and has been removed")

add_bd("PFQ difficulty items - 'does not do this activity' (code 5)", "treated as missing (NA), not as 0 or 1",
       "this response reflects non-exposure/relevance, not a health assessment, so scoring it either way would misrepresent the deficit",
       "not stated")

add_bd("Healthcare-use high-use cutoff", "CORRECTED to be applied per variable, since HUQ050 and HUQ051 use different bucket codes: HUQ050 (1999-2012, codes 0=None,1=1,2=2-3,3=4-9,4=10-12,5=13+) -> '10+ visits' is code >=4; HUQ051 (2013-2016, codes 0=None,1=1,2=2-3,3=4-5,4=6-7,5=8-9,6=10-12,7=13-15,8=16+) -> '10+ visits' is code >=6",
       "10+ visits/year is the threshold commonly used for 'high health-care utilization' in the aging/frailty literature that the cited NHANES FI papers (refs 21-23) draw from; an earlier build applied the HUQ051 cutoff of >=6 uniformly to both variables, which HUQ050 (max code 5) could never satisfy, silently scoring this item as 0 for every respondent in 1999-2012",
       "not stated")

add_bd("Polypharmacy cutoff (Medications FI item)", ">=5 concurrent medications; from RXQ_RX RXDCOUNT (2003-2016) or RXD295 'Number of prescription medicines taken' (1999-2002, where RXDCOUNT does not exist), chosen dynamically by column presence",
       "conventional polypharmacy threshold widely used in geriatric/frailty literature; RXD295 is the 1999-2002 equivalent of RXDCOUNT (same per-person total, repeated on every drug row) - an earlier build only looked for RXDCOUNT and so scored this item as entirely missing for 1999-2002",
       "not stated - Supplemental Table S1 names the item with no cutoff given")

add_bd("Thyroid condition variable", "MCQ160I (1999-2002) / MCQ160M (2003-2016), chosen dynamically per cycle by column presence",
       "NHANES renamed and restructured this item mid-series; MCQ160M is the closest continuation of 'another thyroid problem' wording used post-2003",
       "not stated (S1 gives item name only, not NHANES variable)")

add_bd("Kidney item variable", "KIQ020 (1999-2000, file KIQ) / KIQ022 (2001-2016, file KIQ_U_x), chosen dynamically",
       "file and variable both renamed after 1999-2000; same underlying question",
       "not stated")

add_bd("Confusion/memory item variable", "PFQ056 (1999-2002) / PFQ057 (2003-2016), chosen dynamically",
       "variable renumbered mid-series; same underlying question text",
       "not stated")

add_bd("PFQ letter-to-activity mapping", "CORRECTED to use each variable's SAS Label (via nhanesCodebook()), not the truncated English question text: A=managing money, D=stooping/crouching/kneeling, E=lifting/carrying, H=walking room to room, I=standing from armless chair, J=getting in/out of bed, L=dressing, P=grasping small objects, R=attending social events (identical letters in both PFQ060[1999-2002] and PFQ061[2003-2016] eras)",
       "an earlier build read only the first ~150 characters of the English Text field for letter A, which happens to start with the battery's shared lead-in sentence ('The next questions ask about difficulties...'), and wrongly concluded A was not a scored item; nhanesCodebook()'s SAS Label field ('Managing money difficulty') removes that ambiguity and was checked for every letter A-T to confirm no other mismatches exist",
       "not stated - S1 supplement does not name NHANES variables at all")

add_bd("Healthcare-use / hospital-stay variable renaming", "CORRECTED: HUQ050->HUQ051 at 2013-2014 (HUQ_H); overnight-hospital item is HUQ070 (1999-2000) -> HUD070 (2001-2002 ONLY, note the D) -> HUQ071 (2003-2016); all chosen dynamically by column presence per cycle",
       "confirmed directly from each cycle's downloaded column names rather than assumed; an earlier build only checked for HUQ070/HUQ071 and missed the irregular 2001-2002 'HUD070' name entirely, scoring this item as missing for all of 2001-2002",
       "not stated")

add_bd("ALP / LDH lab variable naming (2001-2002)", "L40_B (2001-2002 only) names alkaline phosphatase and LDH with a D prefix - LBDSAPSI and LBDSLDSI - instead of the LBXSAPSI/LBXSLDSI used in every other cycle; resolved dynamically by column presence",
       "confirmed by inspecting L40_B's actual downloaded column names; an earlier build only looked for the X-prefixed names and so scored both the ALP and LDH frailty-index lab items as missing for all of 2001-2002",
       "not stated - NHANES's own naming inconsistency, not addressed by the paper")

add_bd("Alcohol - past-year variable", "ALQ100 (1999-2000) / ALD100 (2001-2002, note the D) / ALQ101 (2003-2016), chosen dynamically by column presence",
       "NHANES used three different variable names for the same past-year drinking question across the series, including an irregular 'ALD100' in 2001-2002 only; confirmed by inspecting each cycle's actual downloaded column names",
       "not stated")

add_bd("Drinker/non-drinker definition", "CORRECTED, USED reading: drinker = past-year variable (ALQ100/ALD100/ALQ101) == 1; non-drinker = that variable == 2, regardless of ALQ110 lifetime response; everything else (missing/refused/DK on the past-year item) = 'Missing data', a RETAINED category, not excluded at step 4. Alternative reading considered but NOT used: non-drinker requires BOTH past-year==No AND lifetime==No (ALQ110==2) - this stricter AND rule left ~3646 people (past-year=No, lifetime=Yes) unclassified as neither drinker nor non-drinker and does not reproduce the paper's reported category sizes",
       "the paper's Methods sentence ('non-drinkers... had not consumed a minimum of 12... in the past year OR throughout their lifetime') is genuinely ambiguous on its own, but Table 1 (p.5) reports exactly 3 categories - Yes 8386 / No 4494 / Missing data 627 - which only matches a rule based on the past-year question alone with an explicit retained missing category, not the stricter AND-of-two-questions rule; see output/tables/drinking_category_counts.csv for our counts against these figures",
       "Methods text wording is asymmetric/ambiguous (row 31 of paper_methods.csv) but Table 1's reported N's for Yes/No/Missing settle which operational rule was actually used")

add_bd("Physical activity harmonization", "NO RULE CHANGE. pre-GPAQ era (PAQ180, cycles 1999-2000 through 2005-2006): active=PAQ180==4(heavy work), moderate=PAQ180==3(light loads/stairs), never=PAQ180 in {1,2}(sit/stand-walk only). GPAQ era (cycles 2007-2008 through 2015-2016): active=vigorous work OR vigorous recreation (PAQ605==1 | PAQ650==1); moderate=moderate work OR moderate recreation and not active (PAQ620==1 | PAQ665==1); never=none of the 4 gateway items answered 'yes', provided at least one of the 4 was validly answered. CORRECTED: GPAQ codes 7 (refused) and 9 (don't know) are now recoded to missing before this logic runs, so they can no longer be counted as a 'validly answered no' supporting a 'never' classification. Era is assigned per cycle by which instrument's columns actually contain data",
       "NHANES redesigned the physical-activity questionnaire starting in 2007-2008, not 2005-2006 as initially assumed; an earlier build treated GPAQ codes 7/9 as ordinary non-missing values, which could inflate the 'never' count with people who actually refused or didn't know",
       "not stated - Methods text gives only the 3 label names, no operational definition, and does not acknowledge the 2007 instrument change")

add_bd("Physical activity - correct paper reference", "Our unweighted category counts are compared to paper Table 1 (p.5): never 6519 / moderate 4717 / active 2271 of 13507 - see output/tables/pa_category_counts_overall.csv",
       "Supplemental Table S2 lists physical-activity category sizes with the never/active labels SWAPPED relative to Table 1 and must not be used as the reference; Table 1 is the correct source",
       "not stated which of the two paper tables is authoritative; Table 1 is used here because it is the main-text descriptive table")

add_bd("BMI cutoffs used", "Methods-text version: healthy<=25.0, overweight 25.0-<30.0, obese>=30.0",
       "paper gives two different cutoff sets (Methods text vs Table 2 footnote: <25.0/25.0-29.9/>29.9); we follow the Methods narrative as the primary stated rule",
       "Methods text and Table 2 footnote disagree (see paper_methods.csv rows 26 and 28) - both recorded, Methods version used")

add_bd("Race categories", "RIDRETH1 5-level (Mexican American, Other Hispanic, Non-Hispanic White, Non-Hispanic Black, Other Race)",
       "RIDRETH1 already matches the paper's 5 stated categories exactly across all 9 cycles",
       "5 categories stated in Methods; matches directly")

add_bd("CBC-incomplete definition (exclusion step 2)", "missing any of LBDNENO/LBDLYMNO/LBDMONO/LBXPLTSI",
       "these are exactly the four raw counts needed to compute all of NLR, MLR, SIRI, SII",
       "not stated how 'lacked sufficient information on complete blood cell' is operationalized")

add_bd("Exclusion-flow paper_n at step 3 (frailty)", "CORRECTED: paper's remaining N after step 3 is 19162-5503=13659, not 13507; 13507 is only reached after step 4 additionally removes 152 for missing covariates",
       "an earlier build repeated 13507 at both step 3 and step 4 in exclusion_flow.csv; the paper's own Fig. 1 numbers (19162 -> remove 5503 -> remove 152 -> 13507) imply an intermediate value of 13659 that was never displayed as such",
       "Fig. 1 gives the two removal counts (5503, 152) and the final N (13507) but never states the intermediate 13659 explicitly - it is arithmetic from the paper's own reported numbers, not an assumption")

add_bd("Covariate-completeness set (exclusion step 4)", "CORRECTED: Model-2 covariate set minus drinking status: age, sex, cycle, race, education, PIR, BMI category, physical activity category, energy intake, smoking, diabetes, hypertension. Drinking status is deliberately NOT part of this completeness check",
       "matches the paper's fully-adjusted Model 2 specification for every covariate except drinking; drinking is excluded from this rule because the paper's own Table 1 reports 'Missing data' (n=627) as a retained level of the drinking-status variable in the final analytic sample, proving a missing drinking response does not cause exclusion in the paper's own pipeline",
       "not stated which covariate set defines this exclusion step, but Table 1's explicit 'Missing data' row for drinking status is direct evidence that this one variable is handled differently from the others")

add_bd("Diastolic BP = 0 handling", "CORRECTED: a diastolic reading of exactly 0 is recoded to missing for that single reading before averaging; if all of a person's diastolic readings are 0/missing, dbp_mean (and therefore pulse pressure) is missing for them",
       "NHANES records a diastolic BP of 0 when the 5th Korotkoff sound was inaudible - it is a data-collection code, not a true diastolic pressure of zero; averaging it in as a real value would badly bias dbp_mean and pulse_pressure downward for anyone with even one inaudible reading",
       "not stated")

add_bd("BP reading aggregation", "mean of available (non-zero-diastolic) BPXSY1-4 / BPXDI1-4 replicate readings per person",
       "NHANES takes up to 4 BP readings per exam; averaging non-missing readings is the standard analytic convention",
       "not stated whether first reading or an average of replicates is used")

bd_df <- do.call(rbind, bd)
write.csv(bd_df, file.path(tab_dir, "build_decisions.csv"), row.names = FALSE)

cat("\n=== DONE ===\n")
cat("Full pooled N   :", nrow(full), "\n")
cat("Analytic sample N:", sum(full$analytic_sample), "\n")
cat("Frailty prevalence in analytic sample (unweighted):",
    round(mean(full$frail[full$analytic_sample], na.rm = TRUE) * 100, 1), "%\n")
cat("Frailty prevalence in analytic sample (survey-weighted):",
    round(frail_weighted_pct, 1), "%\n")
