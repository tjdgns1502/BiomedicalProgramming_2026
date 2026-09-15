# Step 1: Match N at every stage against the paper's flow chart
# Paper: 45,462 -> missing weight (2,976) -> missing WC (4,767) -> missing stroke (14,330) -> 23,389
# Quartile n should each be ~5,847; stroke events (Yes) should be 893.

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

n0 <- nrow(all_data)
cat(sprintf("Step 0 (raw pooled rows): %d  [paper: 45,462]\n", n0))

miss_wt <- is.na(all_data$BMXWT)
cat(sprintf("Missing weight: %d  [paper: 2,976]\n", sum(miss_wt)))
after_wt <- all_data[!miss_wt, ]

miss_wc <- is.na(after_wt$BMXWAIST)
cat(sprintf("Missing WC (among weight-complete): %d  [paper: 4,767]\n", sum(miss_wc)))
after_wc <- after_wt[!miss_wc, ]

miss_stroke <- !(after_wc$MCQ160F %in% c(1, 2))
cat(sprintf("Missing stroke (among weight+WC-complete): %d  [paper: 14,330]\n", sum(miss_stroke)))
final <- after_wc[!miss_stroke, ]

cat(sprintf("Final N: %d  [paper: 23,389]\n", nrow(final)))
cat(sprintf("Stroke Yes count: %d  [paper: 893]\n", sum(final$MCQ160F == 1)))
cat(sprintf("Stroke No count: %d\n", sum(final$MCQ160F == 2)))

wwi <- final$BMXWAIST / sqrt(final$BMXWt <- final$BMXWT)
qcuts <- quantile(wwi, probs = c(0.25, 0.5, 0.75))
q <- cut(wwi, breaks = c(-Inf, qcuts, Inf), labels = c("Q1", "Q2", "Q3", "Q4"))
cat("Quartile n:\n"); print(table(q))
cat("Quartile cutpoints:\n"); print(qcuts)

cat(sprintf("\nUnweighted overall age: %.2f +/- %.2f  [paper: 49.32 +/- 17.42]\n",
            mean(final$RIDAGEYR), sd(final$RIDAGEYR)))
cat(sprintf("Unweighted overall WWI: %.2f +/- %.2f  [paper: 11.09 +/- 0.86]\n",
            mean(wwi), sd(wwi)))
