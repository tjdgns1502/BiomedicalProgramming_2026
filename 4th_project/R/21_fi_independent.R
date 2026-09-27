## 21_fi_independent.R --------------------------------------------------
## Independent 36-item frailty index, written by a separate general-purpose
## subagent that was given ONLY the paper's Methods text on frailty
## assessment (with refs 21-23), the list of data/raw/*.rds files, and the
## output path. It was forbidden to read R/20_build_analytic_sample.R, its
## item plan, decision log, processed data, the paper folder or git history.
## Copied verbatim from its scratch script; compared with R/20 in
## R/22_compare_fi.R. Output: data/processed/fi_independent.csv (SEQN, FI).
## ------------------------------------------------------------------------
# Independent 36-item frailty index (Jayanama et al. 2018/2021 NHANES FI =
# 46-item Blodgett/Theou FI minus 10 nutrition-related items), NHANES 1999-2016, age 50+.
proj <- "C:/Users/tjdgn/OneDrive/바탕 화면/4-2/의생명과학프로그래밍/R project/4th_project"
raw  <- file.path(proj, "data/raw")
ld   <- function(f) readRDS(file.path(raw, paste0(f, ".rds")))
suf  <- c("", "_B", "_C", "_D", "_E", "_F", "_G", "_H", "_I")

# helpers -------------------------------------------------------------------
yn   <- function(x) ifelse(x == 1, 1, ifelse(x == 2, 0, NA))          # 1=yes,2=no, 7/9 -> NA
outside <- function(x, lo, hi) ifelse(is.na(x), NA, as.numeric(x < lo | x > hi))
above   <- function(x, hi) ifelse(is.na(x), NA, as.numeric(x > hi))
col  <- function(d, v) if (v %in% names(d)) d[[v]] else rep(NA_real_, nrow(d))

one_cycle <- function(i) {
  s <- suf[i]
  demo <- ld(paste0("DEMO", s))[, c("SEQN", "RIDAGEYR", "RIAGENDR")]
  demo <- demo[!is.na(demo$RIDAGEYR) & demo$RIDAGEYR >= 50, ]
  demo$cycle <- i

  # --- MCQ comorbidities
  m <- ld(paste0("MCQ", s))
  thy <- if (i == 1) {                      # 1999-2000: goiter (H) or other thyroid disease (I)
    h <- yn(m$MCQ160H); t <- yn(m$MCQ160I)
    ifelse(h %in% 1 | t %in% 1, 1, ifelse(h %in% 0 & t %in% 0, 0, NA))
  } else if ("MCQ160M" %in% names(m)) yn(m$MCQ160M) else NA   # 2001-02: not asked
  mq <- data.frame(SEQN = m$SEQN,
    angina = yn(m$MCQ160D), heart_attack = yn(m$MCQ160E), chd = yn(m$MCQ160C),
    stroke = yn(m$MCQ160F), thyroid = thy, cancer = yn(m$MCQ220), arthritis = yn(m$MCQ160A))

  bp <- ld(paste0("BPQ", s)); bq <- data.frame(SEQN = bp$SEQN, hbp = yn(bp$BPQ020))
  di <- ld(paste0("DIQ", s))
  dq <- data.frame(SEQN = di$SEQN, diabetes = ifelse(di$DIQ010 == 1, 1, ifelse(di$DIQ010 %in% 2:3, 0, NA)))
  ki <- ld(if (i == 1) "KIQ" else paste0("KIQ_U", s))
  kq <- data.frame(SEQN = ki$SEQN, kidney = yn(if (i == 1) ki$KIQ020 else ki$KIQ022))

  # --- PFQ: confusion + 9 difficulty items (same letters in PFQ060x [1999-02] and PFQ061x [2003+])
  p <- ld(paste0("PFQ", s))
  pre <- if (i <= 2) "PFQ060" else "PFQ061"
  conf <- yn(if (i <= 2) p$PFQ056 else p$PFQ057)
  scr  <- if (i <= 2) c("PFQ048", "PFQ050", "PFQ055", "PFQ056", "PFQ059") else
                      c("PFQ049", "PFQ051", "PFQ054", "PFQ057", "PFQ059")
  anyscr <- rowSums(sapply(scr, function(v) col(p, v) %in% 1)) > 0
  pq <- data.frame(SEQN = p$SEQN, confusion = conf)
  items <- c(money = "A", stoop = "D", lift = "E", walk_rooms = "H", chair = "I",
             bed = "J", dress = "L", grasp = "P", social = "R")
  for (nm in names(items)) {
    x <- col(p, paste0(pre, items[[nm]]))
    v <- ifelse(x == 1, 0, ifelse(x %in% 2:4, 1, NA))    # 5 = "do not do", 7/9 -> NA
    pq[[nm]] <- v
    pq[[paste0(nm, "_raw")]] <- x
  }
  pq$anyscr <- anyscr

  # --- HUQ
  h <- ld(paste0("HUQ", s))
  hosp <- if (i == 1) h$HUQ070 else if (i == 2) h$HUD070 else h$HUQ071
  hc <- if ("HUQ050" %in% names(h)) ifelse(h$HUQ050 %in% 0:5, as.numeric(h$HUQ050 >= 4), NA) else
                                    ifelse(h$HUQ051 %in% 0:8, as.numeric(h$HUQ051 >= 6), NA)   # >=10 visits
  hq <- data.frame(SEQN = h$SEQN,
    srh = ifelse(h$HUQ010 %in% 1:5, as.numeric(h$HUQ010 >= 4), NA),
    hc_use = hc,
    health_vs_1y = ifelse(h$HUQ020 %in% 1:3, as.numeric(h$HUQ020 == 2), NA),
    hosp = yn(hosp))

  # --- Rx count (long file: one row per drug)
  r <- ld(paste0("RXQ_RX", s))
  use <- if (i <= 2) r$RXD030 else r$RXDUSE
  cnt <- if (i <= 2) r$RXD295 else r$RXDCOUNT
  n <- ifelse(use == 2, 0, ifelse(use == 1, cnt, NA))
  rq <- aggregate(n ~ SEQN, data = data.frame(SEQN = r$SEQN, n = n), FUN = max, na.action = na.pass)
  rq$meds <- ifelse(is.na(rq$n), NA, as.numeric(rq$n >= 5)); rq$n <- NULL

  # --- BPX
  b <- ld(paste0("BPX", s))
  sy <- as.matrix(b[, paste0("BPXSY", 1:4)]); dia <- as.matrix(b[, paste0("BPXDI", 1:4)])
  dia[!is.na(dia) & dia == 0] <- NA                       # DBP 0 = not measurable, dropped
  msys <- rowMeans(sy, na.rm = TRUE); mdia <- rowMeans(dia, na.rm = TRUE)
  msys[is.nan(msys)] <- NA; mdia[is.nan(mdia)] <- NA
  vq <- data.frame(SEQN = b$SEQN, pulse = outside(b$BPXPLS, 60, 99),
                   sbp = outside(msys, 90, 140), pp = outside(msys - mdia, 30, 60))

  # --- labs
  bio <- ld(c("LAB18", "L40_B", "L40_C", paste0("BIOPRO", suf[4:9]))[i])
  cbc <- ld(c("LAB25", "L25_B", "L25_C", paste0("CBC", suf[4:9]))[i])
  lq <- data.frame(SEQN = bio$SEQN,
    bun = outside(bio$LBXSBU, 3, 20), bicarb = above(bio$LBXSC3SI, 28),
    ldh = above(col(bio, "LBXSLDSI"), 190), alp = above(col(bio, "LBXSAPSI"), 115),
    uric_si = bio$LBDSUASI, calcium = outside(bio$LBDSCASI, 2.0, 2.5))
  cq <- data.frame(SEQN = cbc$SEQN, platelet = outside(cbc$LBXPLTSI, 150, 450), rdw = above(cbc$LBXRDW, 14.6))

  d <- Reduce(function(a, b) merge(a, b, by = "SEQN", all.x = TRUE),
              list(demo, mq, bq, dq, kq, pq, hq, rq, vq, lq, cq))
  d$uric <- ifelse(is.na(d$uric_si), NA,
            ifelse(d$RIAGENDR == 1, as.numeric(d$uric_si < 240 | d$uric_si > 510),
                                    as.numeric(d$uric_si < 160 | d$uric_si > 430)))
  d
}

all <- do.call(rbind, lapply(1:9, one_cycle))

# PFQ skip pattern: difficulty items asked only of age >= 60 or anyone endorsing a screener.
# Age 50-59 with an answered PFQ interview, no screener endorsed and item not asked -> no difficulty (0).
adl <- c("money", "stoop", "lift", "walk_rooms", "chair", "bed", "dress", "grasp", "social")
skipped <- all$RIDAGEYR < 60 & !is.na(all$confusion) & !all$anyscr
cat("Age 50-59 skip check (screener-negative): n =", sum(skipped),
    "; any difficulty item answered among them:",
    sum(rowSums(!is.na(all[skipped, paste0(adl, "_raw")])) > 0), "\n")
for (v in adl) all[[v]][skipped & is.na(all[[paste0(v, "_raw")]])] <- 0

items36 <- c("angina", "heart_attack", "chd", "stroke", "thyroid", "cancer", "arthritis",
             "hbp", "diabetes", "kidney", "confusion", "money", "stoop", "lift", "walk_rooms",
             "chair", "bed", "dress", "grasp", "social", "srh", "hc_use", "health_vs_1y",
             "hosp", "meds", "pulse", "sbp", "pp", "platelet", "bun", "bicarb", "rdw",
             "ldh", "alp", "uric", "calcium")
stopifnot(length(items36) == 36)
X <- as.matrix(all[, items36])
stopifnot(all(X %in% c(0, 1, NA)))
nobs <- rowSums(!is.na(X))
all$n_items <- nobs
all$FI <- rowSums(X, na.rm = TRUE) / nobs
keep <- nobs >= 29          # missing <= 7 of 36 (< 20%)

cat("Age 50+ total:", nrow(all), " with FI:", sum(keep), "\n")
print(table(cycle = all$cycle, has_FI = keep))
cat("Item missingness among age 50+ (%):\n"); print(round(colMeans(is.na(X)) * 100, 1))
cat("Item prevalence among FI rows (%):\n"); print(round(colMeans(X[keep, ], na.rm = TRUE) * 100, 1))
out <- all[keep, c("SEQN", "FI")]
cat("N =", nrow(out), " mean FI =", round(mean(out$FI), 4), " sd =", round(sd(out$FI), 4),
    " P(FI>0.3) =", round(mean(out$FI > 0.3), 4), "\n")
print(tapply(all$FI[keep], all$cycle[keep], mean))
stopifnot(!anyDuplicated(out$SEQN))
write.csv(out, file.path(proj, "data/processed/fi_independent.csv"), row.names = FALSE)
