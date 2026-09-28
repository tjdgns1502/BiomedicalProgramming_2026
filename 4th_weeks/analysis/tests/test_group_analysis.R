source("analysis/src/group_analysis.R")
set.seed(723901)
d <- data.frame(FI=rep(seq(.02,.49,length.out=24),each=5))
for (m in markers) d[[m]] <- exp(rnorm(nrow(d),.4,.4))
g <- assign_fi_groups(d)
stopifnot(length(unique(g$data$FI_group))==4)
stopifnot(all(vapply(split(as.character(g$data$FI_group),g$data$FI),function(x) length(unique(x))==1,logical(1))))
a <- analyze_groups(d,make_plots=FALSE)
stopifnot(nrow(a$tables$pairwise)==24,nrow(a$tables$primary)==4,
  nrow(a$tables$tukey)==24,nrow(a$tables$trend)==4)
z <- a$tables$pairwise
stopifnot(all(z$p_bonferroni>=z$p-1e-14),all(z$p_BH>=z$p-1e-14))
expect <- mean(a$marker_results$NLR$data$y[a$marker_results$NLR$data$group=="Q4"])-
          mean(a$marker_results$NLR$data$y[a$marker_results$NLR$data$group=="Q1"])
stopifnot(isTRUE(all.equal(unname(expect),subset(z,marker=="NLR" & contrast=="Q4-Q1")$estimate)))
# Scalar rescaling should preserve Welch/KW p-values; effect estimates scale.
d2 <- d;d2$NLR <- d2$NLR*100
a2 <- analyze_groups(d2,make_plots=FALSE)
stopifnot(isTRUE(all.equal(a$tables$primary$p,a2$tables$primary$p,tolerance=1e-10)))
stopifnot(inherits(try(assign_fi_groups(transform(d,FI=.2)),silent=TRUE),"try-error"))
stopifnot(inherits(try(assign_fi_groups(transform(d,FI=2)),silent=TRUE),"try-error"))
# Missing marker values must not shift the reference FI cutpoints.
d3 <- d;d3$NLR[1:3] <- NA_real_
a3 <- analyze_groups(d3,make_plots=FALSE)
stopifnot(identical(a$grouped$cuts,a3$grouped$cuts),a3$marker_results$NLR$omnibus$n[1]==117)
cat("PASS: grouping, ties, invalid data, family size, sign, scale invariance, missingness\n")
cat("These tests use synthetic fixtures and are not NHANES results.\n")
