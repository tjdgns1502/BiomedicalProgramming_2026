source("analysis/src/simulation.R")
out <- "analysis/runs/M01-simulation"
cat("Post-run audit, prompted by above-.05 corrected FWER at k=100. Same original seed; no new simulation seed.\n")
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(20260934)
p <- simulate_z(10000, 100, rho=0)$p
bonf_event_direct <- apply(p, 1, min) <= .05/100
bh_event_direct <- apply(p, 1, function(x) any(sort(x) <= .05*seq_along(x)/length(x)))
stopifnot(identical(unname(bonf_event_direct), unname(rowSums(rejections(p,"bonferroni"))>0)),
          identical(unname(bh_event_direct), unname(rowSums(rejections(p,"BH"))>0)))
cat("Exact event agreement: p.adjust Bonferroni versus min-p cutoff; p.adjust BH versus sorted-step-up cutoff.\n")
for (method in c("bonferroni", "BH")) {
  x <- if (method=="bonferroni") bonf_event_direct else bh_event_direct
  exact <- if (method=="bonferroni") 1-(1-.05/100)^100 else .05
  cat(method, "observed=",mean(x),"theory=",exact,"theoretical_SE=",sqrt(exact*(1-exact)/length(x)),
      "z=",(mean(x)-exact)/sqrt(exact*(1-exact)/length(x)),"\n")
  print(mc_summary(as.numeric(x), TRUE))
}
results <- read.csv(file.path(out,"simulation_summary.csv"))
save_plot_pair(out,"mixed_fdr_power",function() plot_mixed(results, 10000))
cat("Redrew mixed FDR/power figure to move legend clear of curves. No result values changed.\n")
cat("Interpretation: this fixed Monte Carlo run has above-target estimates; retain and report them without seed selection.\n")
