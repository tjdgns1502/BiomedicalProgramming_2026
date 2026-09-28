# Meaningful base-R checks for the simulation generator and definitions.
args <- commandArgs(trailingOnly = TRUE)
src <- if (length(args) >= 1L) args[1L] else "analysis/src/simulation.R"
source(src)
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
cat("SIMULATION TESTS ONLY; fixed test seeds 431, 432, 433, 434, 435.\n")

# Known test statistics must map to valid one-sided normal probabilities.
stopifnot(isTRUE(all.equal(pnorm(c(0, qnorm(.95)), lower.tail = FALSE), c(.5, .05))))
set.seed(431)
g0 <- simulate_z(50000, 3, rho = 0)
stopifnot(all(g0$p >= 0 & g0$p <= 1), max(abs(colMeans(g0$z))) < .025,
          max(abs(apply(g0$z, 2, var) - 1)) < .04,
          max(abs(cor(g0$z)[upper.tri(cor(g0$z))])) < .02,
          abs(mean(g0$p <= .05) - .05) < .004)
set.seed(432)
g5 <- simulate_z(50000, 3, rho = .5)
stopifnot(max(abs(cor(g5$z)[upper.tri(cor(g5$z))] - .5)) < .02,
          abs(mean(g5$p <= .05) - .05) < .004)
# rho=1 must produce identical null statistics and remove multiplicity inflation.
set.seed(433)
g1 <- simulate_z(1000, 4, rho = 1)
stopifnot(identical(g1$z[, 1], g1$z[, 4]), identical(g1$p[, 1], g1$p[, 4]))
# Mean shifts and n scaling use the same RNG stream for an exact comparison.
set.seed(434); null <- simulate_z(50, 2, delta = c(0, 0))
set.seed(434); alt <- simulate_z(50, 2, delta = c(.5, 0))
stopifnot(isTRUE(all.equal(alt$z[, 1] - null$z[, 1], rep(sqrt(30) * .5, 50))),
          identical(alt$p[, 2], null$p[, 2]))

# Hand-worked example separates V/R from S/m1 and handles R=0 as FDP=0.
rej <- matrix(c(TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, TRUE), nrow = 3, byrow = TRUE)
x <- error_metrics(rej, c(TRUE, TRUE, FALSE, FALSE))
stopifnot(identical(x$V, c(2, 0, 1)), identical(x$R, c(3, 0, 3)),
          isTRUE(all.equal(x$FDP, c(2/3, 0, 1/3))),
          isTRUE(all.equal(x$power, c(.5, 0, 1))))
allnull <- error_metrics(rej, rep(TRUE, 4))
stopifnot(identical(as.numeric(allnull$FDP), as.numeric(allnull$any_false)), all(is.na(allnull$power)))
p <- rbind(c(.01, .02, .20), c(.04, .05, .06))
stopifnot(identical(rejections(p, "bonferroni"), p <= .05/3),
          identical(unname(rejections(p, "BH")[1, ]), c(TRUE, TRUE, FALSE)),
          !any(rejections(p, "BH")[2, ]))
# k=1 is an important dimension edge case; all adjustments are equivalent.
one <- matrix(c(.01, .06, .2), ncol = 1)
stopifnot(identical(rejections(one, "BH"), rejections(one, "unadjusted")),
          identical(rejections(one, "bonferroni"), rejections(one, "unadjusted")))
stopifnot(nrow(simulation_design()) == 22L,
          all(simulation_design()$seed == 20260928L + seq_len(22)))
ci <- mc_summary(rep(0, 100), TRUE)
stopifnot(ci["lower95"] >= 0, ci["upper95"] > 0, ci["upper95"] < .05)

# Pre-fixed stochastic smoke check: 6 theoretical SE tolerance; not a proof.
# No changing seeds when observations miss a tolerance or a 95% interval.
cell <- run_cell(10, 0, "global_null", seed = 435, design_id = 1, B = 10000)
s <- cell$summary
raw <- s[s$method == "unadjusted", ]
theory <- 1 - .95^10
tol <- 6 * sqrt(theory * (1 - theory) / 10000)
stopifnot(abs(raw$FWER_estimate - theory) < tol,
          all(s$FWER_estimate == s$FDR_estimate),
          s$FWER_estimate[s$method == "bonferroni"] <= .05 + 6 * sqrt(.05*.95/10000),
          s$FDR_estimate[s$method == "BH"] <= .05 + 6 * sqrt(.05*.95/10000))
cat("All generator, adjustment, metric, edge-case and fixed-seed theory checks passed.\n")
cat("Probabilistic tolerances diagnose gross errors; they do not establish exact error control.\n")
print(sessionInfo())
