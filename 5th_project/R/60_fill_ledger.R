## 60_fill_ledger.R -------------------------------------------------------
## Fills ours / abs_diff / tolerance / status / cause / evidence in
## output/tables/ledger.csv (paper-reproduction-ledger skill). Targets are
## never edited.
##
## CSV repair: 24 abstract/text rows were written by the extractor with an
## unquoted comma inside the target ("1.13 (95% CI, 1.02-1.27)"), which split
## them into 13 fields. The two halves are joined back into the printed value
## and the row is written quoted; the evidence column says so.
##
## Our value per target:
##   Table 1 categorical    R/20 n (unweighted) and weighted %; p = first-order
##                          Rao-Scott (svychisq "Chisq", the SAS SURVEYFREQ
##                          default), other variants in evidence
##   Table 1 continuous     R/20 svymean / SE / svyttest, MEC weight row
##   Tables 2/3 Model k     R/30 OR (the point estimate is compared; CI in
##                          evidence); Cases/total compares the total
##   P-trend                R/30 p_trend of the same stratum and model
##   P-interaction          R/30 Model 3 (fully adjusted; the paper prints one
##                          value per block without the model), M1/M2 in evidence
##   abstract / text        the table cell they quote (Model 3)
##   exclusions             exclusion_flow.csv
##
## Tolerance: half a unit of the last digit shown; for "< 0.001" ours must be
## below 0.001.
##
## Cause rules, fixed before looking at the statuses:
##   1. Table 2 Model 1 oral-health cells of the two smoking strata ->
##      paper typo (swapped strata): the paper's own Cases/total give crude
##      ORs that rank the strata the other way (R/02), and the swapped values
##      match ours within 0.04 (R/34).
##   2. Table 2 non-smoking oral-health Model 3 P-trend 0.032 -> paper typo:
##      the paper's own CIs imply level p of 4e-6 (Fair) and 4e-4 (Poor),
##      with monotone ORs (R/00, A14).
##   3. Alcohol "No drinks" / "Missing" -> variable definition: the paper put
##      lifetime abstainers (skip-pattern NA) under Missing; No drinks +
##      Missing agrees with the paper's (29.55% non-HTN) within 0.1 point
##      while each part differs by 20+ points (R/20).
##   4. ORs within 0.05 of the paper, Table 1 % within 0.5 percentage point,
##      counts within 5%, means within 2 SE -> sample exclusion: our sample
##      is 383 smaller (exclusion_flow.csv), everything else per the methods.
##   5. Exclusion-step counts -> sample exclusion (A1: the paper's steps add
##      to 42,288, which is not the 2009-2018 age >= 30 population).
##   6. Anything else outside tolerance -> open.
##
## Rscript R/60_fill_ledger.R
## ------------------------------------------------------------------------

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB <- file.path(PROJ, "output", "tables")
rd <- function(f) read.csv(file.path(TAB, f), stringsAsFactors = FALSE, check.names = FALSE)

## --- read the ledger, repairing split rows --------------------------------
lines <- readLines(file.path(TAB, "ledger.csv"), encoding = "UTF-8")
## header via read.csv: after a first run write.csv has quoted it
hdr <- names(read.csv(text = lines[1], check.names = FALSE))
parse_line <- function(s) {
  x <- read.csv(text = s, header = FALSE, colClasses = "character",
                na.strings = character(0), quote = "\"")
  x <- unname(unlist(x[1, ]))
  repaired <- FALSE
  if (length(x) == length(hdr) + 1) {
    x <- c(x[1:4], paste0(x[5], ",", x[6]), x[7:length(x)])
    repaired <- TRUE
  }
  length(x) <- length(hdr)
  x[is.na(x)] <- ""
  ## a row repaired on an earlier run is already quoted: still flag it, so
  ## reruns give the same evidence text
  if (grepl("\\(95% CI\\s*,", x[5])) repaired <- TRUE    # paper prints "CI ," twice
  c(x, repaired = repaired)
}
L <- as.data.frame(do.call(rbind, lapply(lines[-1], parse_line)), stringsAsFactors = FALSE)
names(L) <- c(hdr, "repaired")
L$repaired <- L$repaired == "TRUE"

## --- our results ------------------------------------------------------------
t1c <- rd("20_table1_categorical.csv"); t1t <- rd("20_table1_tests.csv")
t1n <- rd("20_table1_continuous.csv"); t1n <- t1n[t1n$weight == "WTMEC2YR/5", ]
mod <- rd("30_models.csv"); trd <- rd("30_ptrend.csv"); itr <- rd("30_pinteraction.csv")
flow <- rd("exclusion_flow_v2.csv")                  # sample build v2 (CHANGES_v2.md)
swp <- rd("34_swap_test.csv")

num <- function(s) as.numeric(gsub("[,%= ]", "", s))
or_of <- function(s) as.numeric(sub("^\\s*([0-9.]+).*$", "\\1", s))

## --- maps from ledger labels to ours ---------------------------------------
T1_VAR <- c("Sex" = "Sex", "Race" = "Race", "Smoking" = "Smoking",
            "Periodontal disease" = "Periodontal", "Oral Health" = "Oral",
            "Education" = "Education", "BMI" = "BMI", "Sleep duration" = "Sleep",
            "Alcohol" = "Alcohol", "Physical activity" = "Physical activity",
            "History of CVD" = "History of CVD", "Diabetes" = "Diabetes")
T1_HEAD <- c("Sex" = "Sex", "Race/ethnicity" = "Race", "Smoking" = "Smoking",
             "Periodontal disease" = "Periodontal", "Oral Health" = "Oral",
             "Education" = "Education", "BMI" = "BMI", "Sleep duration" = "Sleep",
             "Alcohol consumption" = "Alcohol", "Physical activity" = "Physical activity",
             "History of CVD" = "History of CVD", "Diabetes" = "Diabetes")
lvl_clean <- function(s) {
  s <- sub(" \\(as printed.*\\)$", "", s)
  s <- gsub(" ~ ", "-", s); s <- gsub("< ", "<", s); s <- gsub("> ", ">", s)
  s <- gsub("≥ ", ">=", s); s <- gsub("≤ ", "<=", s)
  s <- sub("^Other Race-Including Multi-Racial$", "Other/Multi-racial", s)
  s
}
T1_CONT <- c("Age y" = "Age", "Total cholesterol mg/dl" = "Total cholesterol",
             "Triglyceride mg/dl" = "Triglyceride", "Creatinine mg/dl" = "Creatinine",
             "HDL mg/dl" = "HDL", "HbA1c (unit printed as mg/dl)" = "HbA1c",
             "Sodium mg" = "Sodium", "Fat g" = "Fat")

## "Overall Oral health: Good" -> list(table, stratum, exposure, level)
cell_key <- function(table, row) {
  if (table == "Table 2") {
    st <- if (startsWith(row, "Overall")) "all" else if (startsWith(row, "Non-Smoking"))
      "nonsmoking" else if (startsWith(row, "Smoking")) "smoking" else NA
  } else {
    st <- if (grepl("Age < 45", row)) "age<45" else if (grepl("Age > = 45", row)) "age>=45" else NA
  }
  ex <- if (grepl("Oral health", row)) "oral" else if (grepl("Periodontal", row)) "perio" else NA
  lv <- sub("^.*: ", "", row)
  list(table = table, stratum = st, exposure = ex, level = lv)
}
## abstract / text rows -> the Table 2/3 cell they quote (Model 3)
text_key <- function(row) {
  ex <- if (grepl("oral health", row, ignore.case = TRUE)) "oral" else
        if (grepl("periodontal", row, ignore.case = TRUE)) "perio" else NA
  tb <- if (grepl("^Age", row)) "Table 3" else "Table 2"
  st <- if (grepl("^Age < 45", row)) "age<45" else if (grepl("^Age > 45", row)) "age>=45" else
        if (grepl("^Non-smoking", row)) "nonsmoking" else if (grepl("^Smoking group", row)) "smoking" else "all"
  lv <- if (ex == "perio") "Yes" else {
    m <- regmatches(row, regexpr("(Good|Fair|Poor)", row)); if (length(m)) m else NA }
  list(table = tb, stratum = st, exposure = ex, level = lv)
}

## --- fill -------------------------------------------------------------------
set_row <- function(i, ours, tol, status, cause = "", evidence = "") {
  L$ours[i] <<- if (is.na(ours)) "" else format(ours, digits = 10)
  L$abs_diff[i] <<- ""; L$tolerance[i] <<- if (is.na(tol)) "" else format(tol)
  L$status[i] <<- status; L$cause[i] <<- cause
  L$evidence[i] <<- paste0(evidence, if (L$repaired[i])
    " | CSV row repaired: unquoted comma in the target had split it (R/60)" else "")
}
judge <- function(i, ours, target_txt, digits, rule4_ok, rule4_ev, special = NULL,
                  ev = "") {
  t <- trimws(target_txt)
  if (grepl("^<", t)) {                       # "< 0.001"
    lim <- num(sub("<", "", t))
    ok <- !is.na(ours) && ours < lim
    set_row(i, ours, NA, if (ok) "match" else "", "", ev)
    L$abs_diff[i] <<- ""
  } else {
    tv <- num(t); tol <- 0.5 * 10^-digits
    d <- abs(ours - tv)
    set_row(i, ours, tol, "", "", ev)
    L$abs_diff[i] <<- format(d, digits = 10)
    ok <- !is.na(d) && d <= tol + 1e-12
    if (ok) L$status[i] <<- "match"
  }
  if (L$status[i] == "match") return(invisible())
  if (!is.null(special)) {
    L$status[i] <<- "mismatch"; L$cause[i] <<- special$cause
    L$evidence[i] <<- paste(special$evidence, L$evidence[i], sep = " | ")
  } else if (isTRUE(rule4_ok)) {
    L$status[i] <<- "mismatch"; L$cause[i] <<- "sample exclusion"
    L$evidence[i] <<- paste(rule4_ev, L$evidence[i], sep = " | ")
  } else {
    L$status[i] <<- "open"
  }
}

## sample sizes from the outputs, not typed in
sex <- t1c[t1c$variable == "Sex", ]
N_GRP <- c(non = sum(sex$n_non), htn = sum(sex$n_htn))       # domain, HTN known
N_DOM <- sum(N_GRP)
N_AN  <- flow$n_remaining[flow$step == 3]                    # analytic sample
EV_N <- sprintf(paste("our N %s (%s with HTN known) vs 21,800; %d fewer removed at the",
                      "missing-data step, %d fewer cases (exclusion_flow_v2.csv)"),
                format(N_AN, big.mark = ","), format(N_DOM, big.mark = ","),
                1090L - flow$n_removed[flow$step == 3], 11017L - N_GRP[["htn"]])
SWAP <- list(cause = "paper typo", evidence = paste(
  "Model 1 oral-health cells printed under the other smoking stratum: swapped they match ours",
  "within 0.04 (34_swap_test.csv); the paper's own Cases/total give crude ORs ranking the",
  "strata the other way (02_crude_tests.csv)"))
A14 <- list(cause = "paper typo", evidence = paste(
  "the paper's own CIs imply Wald p 4e-6 (Fair 1.49, 1.26-1.77) and 4e-4 (Poor 1.62,",
  "1.24-2.12) with monotone ORs; a trend p of 0.032 is incompatible (00_paper_consistency.csv)"))
alc <- t1c[t1c$variable == "Alcohol" & t1c$level %in% c("No drinks", "Missing"), ]
ALC <- list(cause = "variable definition", evidence = sprintf(paste(
  "paper's Missing holds lifetime abstainers (skip-pattern NA): No drinks + Missing =",
  "%.2f%% / %.2f%% ours vs 29.55%% / 36.71%% paper (non-HTN / HTN), while each part",
  "differs by 20+ points (20_table1_categorical.csv)"),
  sum(alc$pct_non), sum(alc$pct_htn)))

for (i in seq_len(nrow(L))) {
  tb <- L$table[i]; rw <- L$row[i]; cl <- L$col[i]; tg <- L$target[i]
  dg <- suppressWarnings(as.integer(L$digits_shown[i])); if (is.na(dg)) dg <- 2L

  if (tb %in% c("Table 1", "Table 1 (continued)")) {
    grp <- if (startsWith(cl, "Non-hypertension")) "non" else "htn"
    if (rw == "No. of participants") {
      ours <- if (grepl("N$", cl)) N_GRP[[grp]] else 100 * N_GRP[[grp]] / N_DOM
      judge(i, ours, tg, dg, TRUE, EV_N)
    } else if (grepl(": ", rw)) {
      v <- T1_VAR[[sub(": .*$", "", rw)]]; lv <- lvl_clean(sub("^[^:]*: ", "", rw))
      r <- t1c[t1c$variable == v & t1c$level == lv, ]
      if (!nrow(r)) { set_row(i, NA, NA, "not reproduced", "", "level not in our table"); next }
      if (grepl("N$", cl)) {
        ours <- r[[paste0("n_", grp)]]; tv <- num(tg)
        ok4 <- abs(ours - tv) <= 0.05 * tv
      } else {
        ours <- r[[paste0("pct_", grp)]]; ok4 <- abs(ours - num(tg)) <= 0.5
      }
      sp <- if (v == "Alcohol" && lv %in% c("No drinks", "Missing")) ALC else NULL
      judge(i, ours, tg, dg, ok4, EV_N, sp, sprintf("R/20: %s %s", v, lv))
    } else if (rw %in% names(T1_HEAD) && cl == "p-value") {
      tt <- t1t[t1t$variable == T1_HEAD[[rw]], ]
      ev <- paste(sprintf("%s p=%.3g", tt$method, tt$p), collapse = "; ")
      judge(i, tt$p[tt$method == "rao_scott_1"], tg, dg, FALSE, "", NULL,
            paste("ours = rao_scott_1 (SAS default);", ev))
    } else if (rw %in% names(T1_CONT)) {
      r <- t1n[t1n$variable == T1_CONT[[rw]], ]
      if (cl == "p-value") {
        judge(i, r$p, tg, dg, FALSE, "", NULL, "svyttest, MEC weight")
      } else {
        ours <- if (grepl("mean", cl)) r[[paste0("mean_", grp)]] else r[[paste0("se_", grp)]]
        se <- r[[paste0("se_", grp)]]
        ok4 <- if (grepl("mean", cl)) abs(ours - num(tg)) <= 2 * se else abs(ours - num(tg)) <= 0.5 * se + 0.01
        ev <- if (rw == "Triglyceride mg/dl")
          "non-fasting LBXSTR (fasting LBXTR gives 115.4 / 139.1, see 20_table1_continuous.csv)" else ""
        judge(i, ours, tg, dg, ok4, EV_N, NULL, ev)
      }
    } else set_row(i, NA, NA, "not reproduced", "", "no mapping")

  } else if (tb %in% c("Table 2", "Table 3")) {
    if (grepl(" x ", rw)) {                                   # P-interaction
      ex <- if (grepl("^Oral", rw)) "oral" else "perio"
      r <- itr[itr$table == tb & itr$exposure == ex, ]
      ev <- paste(sprintf("M%s p=%.3g", r$model, r$p), collapse = "; ")
      judge(i, r$p[r$model == 3], tg, 3L, FALSE, "", NULL,
            paste("regTermTest of the product terms;", ev, "(30_pinteraction.csv)"))
      next
    }
    k <- cell_key(tb, rw)
    if (k$level == "P-trend") {
      m <- as.integer(sub("Model ", "", cl))
      r <- trd[trd$table == tb & trd$exposure == k$exposure & trd$stratum == k$stratum &
               trd$model == m, ]
      sp <- if (tb == "Table 2" && k$stratum == "nonsmoking" && k$exposure == "oral" && m == 3) A14 else NULL
      judge(i, r$p_trend, tg, max(dg, 3L), FALSE, "", sp, "30_ptrend.csv")
      next
    }
    r <- mod[mod$table == tb & mod$exposure == k$exposure & mod$stratum == k$stratum &
             mod$level == k$level, ]
    if (cl == "Cases/total") {
      rr <- r[r$model == 1, ]
      tot <- as.numeric(sub("^.*/", "", gsub(",", "", tg)))
      judge(i, rr$total, as.character(tot), 0L, abs(rr$total - tot) <= 0.05 * tot, EV_N, NULL,
            sprintf("ours %d/%d (cases/total), compared on the total", rr$cases, rr$total))
    } else {
      m <- as.integer(sub("Model ", "", cl)); rr <- r[r$model == m, ]
      ours <- rr$or; tv <- or_of(tg)
      sp <- if (tb == "Table 2" && m == 1 && k$exposure == "oral" &&
                k$stratum %in% c("nonsmoking", "smoking") && k$level != "Excellent/Very good") SWAP else NULL
      ev <- if (is.na(rr$lo)) "reference" else sprintf("ours %.3f (%.3f-%.3f)", ours, rr$lo, rr$hi)
      judge(i, ours, sprintf("%.2f", tv), 2L, abs(ours - tv) <= 0.05, EV_N, sp, ev)
    }

  } else {                                                     # abstract / text
    if (grepl("^Exclusion|^Final sample", rw)) {
      ours <- switch(rw,
        "Exclusion: no blood pressure" = flow$n_removed[flow$step == 2],
        "Exclusion: missing smoking/oral health/periodontal disease" = flow$n_removed[flow$step == 3],
        "Final sample" = flow$n_remaining[flow$step == 3])
      judge(i, ours, tg, 0L, TRUE, paste("A1: the paper's steps sum to 42,288;", EV_N))
    } else if (cl %in% c("N analysed", "Total participants")) {
      judge(i, N_AN, tg, 0L, TRUE, EV_N)
    } else if (cl == "Age restriction") {
      set_row(i, 30, 0, "match", "", "age >= 30 applied (R/11)"); L$abs_diff[i] <- "0"
    } else if (grepl("N \\(%\\)", cl)) {
      n <- if (grepl("^Hyper|^Hypertension", rw) || grepl("^Hypertension", cl)) N_GRP[["htn"]] else N_GRP[["non"]]
      judge(i, n, sub(" \\(.*$", "", tg), 0L, TRUE, EV_N,
            NULL, sprintf("ours %d (%.2f%%)", n, 100 * n / N_DOM))
    } else if (cl %in% c("Male %", "Female %")) {
      s <- sex[sex$level == sub(" %$", "", cl), ]
      ours <- 100 * (s$n_non + s$n_htn) / N_DOM
      judge(i, ours, tg, 2L, abs(ours - num(tg)) <= 0.5, EV_N, NULL, "unweighted, as the paper's 48.40")
    } else if (grepl("Interaction", rw)) {
      ex <- if (grepl("oral health", rw)) "oral" else "perio"
      tb2 <- if (grepl("age", rw)) "Table 3" else "Table 2"
      r <- itr[itr$table == tb2 & itr$exposure == ex, ]
      judge(i, r$p[r$model == 3], tg, 3L, FALSE, "", NULL,
            paste(sprintf("M%s p=%.3g", r$model, r$p), collapse = "; "))
    } else {
      k <- text_key(rw)
      if (cl == "p for trend") {
        r <- trd[trd$table == k$table & trd$exposure == k$exposure & trd$stratum == k$stratum &
                 trd$model == 3, ]
        sp <- if (k$table == "Table 2" && k$stratum == "nonsmoking" && k$exposure == "oral") A14 else NULL
        judge(i, r$p_trend, sub("^= ", "", tg), 3L, FALSE, "", sp, "Model 3, 30_ptrend.csv")
      } else {
        r <- mod[mod$table == k$table & mod$exposure == k$exposure & mod$stratum == k$stratum &
                 mod$level == k$level & mod$model == 3, ]
        tv <- or_of(tg)
        judge(i, r$or, sprintf("%.2f", tv), 2L, abs(r$or - tv) <= 0.05, EV_N, NULL,
              sprintf("Model 3 of %s %s; ours %.3f (%.3f-%.3f)", k$table, k$stratum,
                      r$or, r$lo, r$hi))
      }
    }
  }
}

## PLAN.md section 4 judged ORs at +/- 0.03; the ledger status uses the
## skill's stricter half-unit rule. Flag OR rows that pass the plan's rule
## (audit finding 1) without changing their status.
is_or <- grepl("^Model [123]$|^OR \\(95% CI\\)$", L$col) & L$status != "match" &
         L$abs_diff != "" & !grepl("P-trend", L$row)
plan_ok <- is_or & suppressWarnings(as.numeric(L$abs_diff)) <= 0.03 + 1e-12
L$evidence[plan_ok] <- paste(L$evidence[plan_ok], "| within PLAN section 4 (OR +/- 0.03)")

out <- L[, hdr]
write.csv(out, file.path(TAB, "ledger.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("ledger rows:", nrow(out), " repaired:", sum(L$repaired), "\n")
print(table(factor(out$status, levels = c("match", "mismatch", "not reproduced", "open", ""))))
cat("\nby cause (non-match):\n"); print(table(out$cause[out$status != "match"]))
cat(sprintf("\nOR rows outside the ledger tolerance but within PLAN section 4 (+/- 0.03): %d\n",
            sum(plan_ok)))
cat("\nopen rows:\n")
print(out[out$status == "open", c("table", "row", "col", "target", "ours")], row.names = FALSE)
