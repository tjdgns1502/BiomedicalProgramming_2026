library(haven)

read_cycle <- function(cycle) {
  fn <- function(comp) {
    base <- if (cycle == "P") paste0("P_", comp) else paste0(comp, "_", cycle)
    file.path("data", paste0(base, ".XPT"))
  }
  demo <- read_xpt(fn("DEMO"))
  bmx  <- read_xpt(fn("BMX"))
  mcq  <- read_xpt(fn("MCQ"))
  d <- demo[, c("SEQN", "RIDAGEYR")]
  d <- merge(d, bmx[, c("SEQN", "BMXWT", "BMXWAIST")], by = "SEQN", all.x = TRUE)
  d <- merge(d, mcq[, c("SEQN", "MCQ160F")], by = "SEQN", all.x = TRUE)
  d$cycle <- cycle
  d
}

cycles <- c("G", "H", "I", "P")
all_data <- do.call(rbind, lapply(cycles, read_cycle))

after_wt <- all_data[!is.na(all_data$BMXWT), ]
after_wc <- after_wt[!is.na(after_wt$BMXWAIST), ]

cat("Among weight+WC-complete rows, MCQ160F distribution:\n")
print(table(after_wc$MCQ160F, useNA = "ifany"))

refused_or_dk <- after_wc[after_wc$MCQ160F %in% c(7, 9), ]
cat("\nRefused/DK rows with complete weight+WC:", nrow(refused_or_dk), "\n")

# What if we treat MCQ160F==9 (don't know) as missing but MCQ160F==7 differently, or vice versa?
# Try: keep both as missing (baseline, current approach)
n_base <- sum(after_wc$MCQ160F %in% c(1, 2))
cat("Baseline (7,9 excluded as missing): N =", n_base, "\n")

# Try: recode 7 and 9 both to "No"
n_alt1 <- nrow(after_wc)  # everyone with wt+wc, regardless of stroke code, if we never drop for missing stroke except true NA
cat("If only TRUE NA (not 7/9) treated as missing stroke: N =", n_alt1 - sum(is.na(after_wc$MCQ160F)), "\n")
