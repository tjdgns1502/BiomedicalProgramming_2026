source("R/00_setup.R")
source("R/01_generators.R")
source("R/02_tests_effects.R")

set.seed(config$seed + 500L)
z <- draw_pair(config$focal$n, "gamma", 4,
               config$focal$sd_ratio, "median")
tests <- all_tests(z$x, z$y)
diag <- population_diagnostics("gamma", 4,
                               config$focal$sd_ratio, "median")
out <- cbind(diag, as.data.frame(as.list(tests)))
write.csv(out, "results/tables/05_counterexample.csv", row.names = FALSE)
record_manifest("results/tables/05_counterexample.csv", "R/05_counterexample.R",
                "Equal population medians; unequal spread; WMW tests P(X<Y)=0.5")
