d <- readRDS(file.path("data", "analytic_sample.rds"))

cat("LBXTR (triglycerides) summary, unweighted, analytic sample:\n")
print(summary(d$LBXTR))
cat("N non-missing:", sum(!is.na(d$LBXTR)), "\n")
cat("Top 20 highest values:\n")
print(sort(d$LBXTR, decreasing = TRUE)[1:20])

cat("\nUnweighted mean/sd by quartile:\n")
print(aggregate(LBXTR ~ wwi_q, d, function(x) c(mean = mean(x), sd = sd(x))))

cat("\nLBDLDL summary:\n")
print(summary(d$LBDLDL))

cat("\n\n--- HDL / TCHOL for comparison (should already match paper closely) ---\n")
print(summary(d$LBDHDD))
print(summary(d$LBXTC))
