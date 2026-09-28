source("analysis/src/procedure_simulation.R")
e <- procedure_dependencies()
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
cat("M02 unit tests, fixed seeds 702 and 703; no paper numeric outputs.\n")
d0 <- generate_procedure_data(1, 702)
dh <- generate_procedure_data(2, 702)
da <- generate_procedure_data(4, 702)
dl <- generate_procedure_data(3, 702)
stopifnot(all(table(d0$group) == 30), nrow(d0) == 120,
  isTRUE(all.equal(dh$y, d0$y * rep(1:4, each=30))),
  isTRUE(all.equal(da$y - d0$y, rep(c(0,.2,.4,.6), each=30))),
  isTRUE(all.equal(dl$y, exp(d0$y))), all(dl$y > 0))
# Sourceable API: no simulation files or run started by source above.
# Wrapper and core must produce exactly identical inference on valid biomarker input.
x <- generate_procedure_data(3, 703)
x$score <- as.numeric(x$group)/10
core <- e$comparison_core(x, "NLR")
wrapper_dat <- data.frame(NLR=x$y, FI_group=x$group, FI_score=x$score)
wrapped <- e$compare_marker(wrapper_dat, "NLR")
stopifnot(identical(core$omnibus, wrapped$omnibus), identical(core$pairwise, wrapped$pairwise),
          isTRUE(all.equal(core$omnibus$p[2], oneway.test(y~group,x,var.equal=FALSE)$p.value)))
# First contrast is Q2-Q1; verify orientation and Welch degrees of freedom.
tt <- t.test(x$y[x$group=="Q2"], x$y[x$group=="Q1"], var.equal=FALSE)
stopifnot(core$pairwise$contrast[1] == "Q2-Q1", isTRUE(all.equal(core$pairwise$p[1],tt$p.value)),
          isTRUE(all.equal(core$pairwise$df[1],unname(tt$parameter))),
          isTRUE(all.equal(core$pairwise$estimate[1],mean(x$y[x$group=="Q2"])-mean(x$y[x$group=="Q1"]))))
stopifnot(grepl("NOT_null_size", omnibus_interpretation(2, "Kruskal-Wallis")),
          omnibus_interpretation(2,"Welch") == "size_under_equal_mean_null")
# Hand-selected probabilities verify all-null and all-alternative metric denominators.
om <- matrix(.5, 2, 3, dimnames=list(NULL,c("ANOVA","Welch","Kruskal-Wallis")))
pa <- rbind(c(.001,.002,.003,.004,.005,.006),rep(.9,6))
nullsum <- summarize_procedure(om, pa, procedure_design()[1,], e)$pairwise
altsum <- summarize_procedure(om, pa, procedure_design()[4,], e)$pairwise
stopifnot(all(nullsum$FWER_estimate==.5), all(nullsum$FDR_estimate==.5), all(is.na(nullsum$power_estimate)),
          all(altsum$FWER_estimate==0), all(altsum$FDR_estimate==0), all(altsum$power_estimate==.5))
cat("All generation, shared-core/wrapper equality, contrast, truth-label and metric tests passed.\n")
print(sessionInfo())
