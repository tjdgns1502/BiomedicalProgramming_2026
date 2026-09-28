# Actual procedure simulation: all numeric inference calls comparison_core in group_analysis.R.
# Rscript analysis/src/procedure_simulation.R [output_dir] [B=2000] [seed=20260929]
procedure_dependencies <- function(core_path = "analysis/src/group_analysis.R", metric_path = "analysis/src/simulation.R") {
  env <- new.env(parent = globalenv())
  sys.source(core_path, envir = env)
  sys.source(metric_path, envir = env)
  stopifnot(is.function(env$comparison_core), is.function(env$mc_summary))
  env
}

procedure_design <- function() {
  data.frame(scenario_id = 1:4,
    scenario = c("normal_equal_null", "normal_hetero_equal_mean", "lognormal_identical_null", "normal_mean_alternative"),
    distribution = c("normal", "normal", "lognormal", "normal"),
    mean_parameters = c("0,0,0,0", "0,0,0,0", "logmean=0,0,0,0", "0,.2,.4,.6"),
    sd_parameters = c("1,1,1,1", "1,2,3,4", "logsd=1,1,1,1", "1,1,1,1"),
    equal_means = c(TRUE, TRUE, TRUE, FALSE),
    identical_distributions = c(TRUE, FALSE, TRUE, FALSE), n_per_group = 30L,
    stringsAsFactors = FALSE)
}

generate_procedure_data <- function(scenario_id, seed, n = 30L) {
  stopifnot(scenario_id %in% 1:4, n >= 2, n == as.integer(n))
  set.seed(seed)
  mu <- if (scenario_id == 4L) c(0, .2, .4, .6) else rep(0, 4)
  sig <- if (scenario_id == 2L) c(1, 2, 3, 4) else rep(1, 4)
  y <- rnorm(n * 4L, mean = rep(mu, each = n), sd = rep(sig, each = n))
  if (scenario_id == 3L) y <- exp(y)
  data.frame(y = y, group = factor(rep(paste0("Q", 1:4), each = n), levels = paste0("Q", 1:4)))
}

omnibus_interpretation <- function(scenario_id, method) {
  if (scenario_id == 4L) return("power_under_mean_and_distribution_alternative")
  if (scenario_id == 2L && method == "Kruskal-Wallis")
    return("rejection_frequency_different_distributions_NOT_null_size")
  if (method == "Kruskal-Wallis") return("size_under_identical_distribution_null")
  "size_under_equal_mean_null"
}

summarize_procedure <- function(omnibus_p, pairwise_p, design_row, env, alpha = .05) {
  B <- nrow(omnibus_p); id <- design_row$scenario_id
  methods <- colnames(omnibus_p)
  om <- do.call(rbind, lapply(methods, function(method) {
    values <- env$mc_summary(as.numeric(omnibus_p[, method] <= alpha), TRUE)
    data.frame(simulation = TRUE, scenario_id = id, scenario = design_row$scenario,
      B = B, n_per_group = 30L, method = method, endpoint = omnibus_interpretation(id, method),
      alpha = alpha, as.list(values), row.names = NULL)
  }))
  truth <- rep(id != 4L, ncol(pairwise_p))
  pairs <- do.call(rbind, lapply(c("unadjusted", "bonferroni", "BH"), function(method) {
    metrics <- env$error_metrics(env$rejections(pairwise_p, method, alpha), truth)
    fwer <- env$mc_summary(metrics$any_false, TRUE)
    fdr <- env$mc_summary(metrics$FDP, all(truth))
    power <- env$mc_summary(metrics$power)
    any_detection <- env$mc_summary(as.numeric(metrics$R > 0), TRUE)
    values <- c(setNames(fwer, paste0("FWER_", names(fwer))),
      setNames(fdr, paste0("FDR_", names(fdr))), setNames(power, paste0("power_", names(power))),
      setNames(any_detection, paste0("any_discovery_", names(any_detection))))
    data.frame(simulation = TRUE, scenario_id = id, scenario = design_row$scenario,
      B = B, method = method, family_size = 6L, m0 = sum(truth), m1 = sum(!truth), alpha = alpha,
      endpoint_note = if (all(truth)) "six_true_mean_nulls" else "all_six_mean_nulls_false_FWER_structurally_zero",
      as.list(values), row.names = NULL)
  }))
  list(omnibus = om, pairwise = pairs)
}

run_procedure_simulation <- function(outdir = "analysis/runs/M02-procedure", B = 2000L, seed = 20260929L,
    core_path = "analysis/src/group_analysis.R") {
  stopifnot(B >= 2, B == as.integer(B), seed > 0, seed == as.integer(seed))
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  logcon <- file(file.path(outdir, "execution.log"), "wt")
  sink(logcon, split = TRUE)
  warning_records <- character()
  on.exit({
    writeLines(if (length(warning_records)) warning_records else "No warnings.", file.path(outdir, "warnings.txt"))
    capture.output(sessionInfo(), file = file.path(outdir, "sessionInfo.txt"))
    cat("Finished:", format(Sys.time(), tz = "UTC"), "UTC\n")
    sink(); close(logcon)
  }, add = TRUE)
  withCallingHandlers({
    cat("SIMULATION ONLY. Actual comparison_core shared with group_analysis.R.\n")
    cat("Started:", format(Sys.time(), tz = "UTC"), "UTC; B=", B, "master seed=", seed, "\n")
    RNGkind("Mersenne-Twister", "Inversion", "Rejection")
    env <- procedure_dependencies(core_path)
    design <- procedure_design()
    write.csv(design, file.path(outdir, "design.csv"), row.names = FALSE)
    seed_grid <- expand.grid(replication = seq_len(B), scenario_id = design$scenario_id, KEEP.OUT.ATTRS = FALSE)
    seed_grid$seed <- seed + seed_grid$scenario_id * 100000L + seed_grid$replication
    stopifnot(!anyDuplicated(seed_grid$seed))
    write.csv(seed_grid, file.path(outdir, "replication_seeds.csv"), row.names = FALSE)
    writeLines(c("SIMULATION ONLY", paste0("B=", B), paste0("master_seed=", seed),
      "alpha=.05; four independent groups; n=30 each", "pairwise multiplicity family=6", "actual core source MD5 follows",
      capture.output(tools::md5sum(core_path)), capture.output(RNGkind())), file.path(outdir, "run_parameters.txt"))
    core_at_start <- readLines(core_path, warn = FALSE)
    writeLines(core_at_start, file.path(outdir, "group_analysis_core_snapshot.R"))
    cells <- Map(function(id, scenario) {
      cat("Scenario", id, scenario, "\n")
      seeds <- seed_grid$seed[seed_grid$scenario_id == id]
      omnibus_p <- matrix(NA_real_, B, 3L, dimnames = list(NULL, c("ANOVA", "Welch", "Kruskal-Wallis")))
      pairwise_p <- matrix(NA_real_, B, 6L)
      for (b in seq_len(B)) {
        dat <- generate_procedure_data(id, seeds[b])
        z <- env$comparison_core(dat, "simulation_marker")
        omnibus_p[b, ] <- z$omnibus$p[match(colnames(omnibus_p), z$omnibus$method)]
        pairwise_p[b, ] <- z$pairwise$p
        if (b == 1L) colnames(pairwise_p) <- z$pairwise$contrast
        if (b %% 500L == 0L) cat("  Completed", b, "of", B, "repetitions\n")
      }
      stopifnot(all(is.finite(omnibus_p)), all(is.finite(pairwise_p)))
      sums <- summarize_procedure(omnibus_p, pairwise_p, design[design$scenario_id == id, ], env)
      list(omnibus_p = omnibus_p, pairwise_p = pairwise_p, seeds = seeds, summaries = sums)
    }, design$scenario_id, design$scenario)
    omnibus <- do.call(rbind, lapply(cells, function(x) x$summaries$omnibus))
    pairwise <- do.call(rbind, lapply(cells, function(x) x$summaries$pairwise))
    write.csv(omnibus, file.path(outdir, "omnibus_summary.csv"), row.names = FALSE)
    write.csv(pairwise, file.path(outdir, "pairwise_summary.csv"), row.names = FALSE, na = "NA")
    saveRDS(list(simulation = TRUE, design = design, cells = cells, B = B, seed = seed), file.path(outdir, "procedure_replicates.rds"))
    cat("Omnibus results (KW heteroscedastic equal-mean scenario is NOT null size):\n")
    print(omnibus[, c("scenario", "method", "estimate", "mcse", "lower95", "upper95")])
    cat("Six-pair family summaries:\n")
    print(pairwise[, c("scenario", "method", "FWER_estimate", "FDR_estimate", "power_estimate")])
    cat("Completed actual shared-core simulation; no paper outcomes were used.\n")
    invisible(list(omnibus = omnibus, pairwise = pairwise))
  }, warning = function(w) {
    warning_records <<- c(warning_records, conditionMessage(w))
    cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning")
  })
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- if (length(args) >= 1L) args[1] else "analysis/runs/M02-procedure"
  B <- if (length(args) >= 2L) as.integer(args[2]) else 2000L
  seed <- if (length(args) >= 3L) as.integer(args[3]) else 20260929L
  run_procedure_simulation(out, B, seed)
}
