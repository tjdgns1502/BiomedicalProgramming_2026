Sys.setlocale('LC_ALL', 'English_United States.utf8')
# R-REPAIR-003, accepted plan 1.5. NEW immutable run; never modifies E1/cache.
# Rscript analysis/src/repair_harmonization.R . E2-20261004 --input-extended-run=E1-20261004
# --candidate=both|A|B (default both); --complete-case=true|false (default false).
# Frozen, hash-verified E1 core/extension functions are sourced without their main.
# Recompute every Model3/trend/interaction and changed laboratory Table1 rows.
# Reuse Model1/2 and unaffected descriptive rows with explicit E1 provenance.

repair_cli <- function(args) {
  positional <- args[!startsWith(args, '--')]
  if (length(positional) > 2L) stop('Arguments: project_root and NEW run_id.')
  opts <- list(root = if (length(positional)) positional[[1L]] else '.',
    run_id = if (length(positional) >= 2L) positional[[2L]] else paste0('E2-', format(Sys.time(), '%Y%m%dT%H%M%SZ', tz = 'UTC')),
    input_extended_run = NULL, candidate = 'both', complete_case = FALSE, stage = 'repair-model3')
  for (arg in args[startsWith(args, '--')]) {
    pair <- strsplit(sub('^--', '', arg), '=', fixed = TRUE)[[1L]]
    if (length(pair) != 2L || !pair[[1L]] %in% c('input-extended-run', 'candidate', 'complete-case'))
      stop('Unsupported repair option: ', arg)
    opts[[gsub('-', '_', pair[[1L]], fixed = TRUE)]] <- pair[[2L]]
  }
  if (is.null(opts$input_extended_run)) stop('--input-extended-run=successful-E1-run is required.')
  for (id in c(opts$run_id, opts$input_extended_run))
    if (!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$', id) || id %in% c('.', '..'))
      stop('Run IDs must be safe ASCII directory names.')
  if (!opts$candidate %in% c('A', 'B', 'both')) stop('candidate must be A, B, or both.')
  if (!tolower(as.character(opts$complete_case)) %in% c('true', 'false'))
    stop('complete-case must be true or false.')
  opts$complete_case <- tolower(as.character(opts$complete_case)) == 'true'
  opts$root <- normalizePath(opts$root, winslash = '/', mustWork = TRUE)
  opts$input_run <- opts$input_extended_run
  opts
}

verify_extended_input <- function(opts) {
  path <- file.path(opts$root, 'analysis', 'runs', opts$input_extended_run)
  required <- c('status.json', 'report.json', 'artifact_hashes.csv', 'sources_manifest.csv',
    'derived/master.rds', 'executed_script.R', 'core_script_snapshot.R', 'definitions.json',
    'tables/all_model_coefficients.csv', 'tables/model_sample_counts_formulas.csv',
    'tables/oral_trend_tests.csv', 'tables/interaction_joint_wald.csv', 'tables/interaction_coefficients.csv',
    'models/model_metadata.json', 'tables/continuous_missing_indicators.csv')
  absent <- required[!file.exists(file.path(path, required))]
  if (length(absent)) stop('Extended input is incomplete: ', paste(absent, collapse = ', '))
  status <- jsonlite::read_json(file.path(path, 'status.json'), simplifyVector = TRUE)
  if (!identical(status$status, 'success')) stop('Extended input must be success; do not reuse a running E1.')
  report <- jsonlite::read_json(file.path(path, 'report.json'), simplifyVector = FALSE)
  if (!identical(report$revision, '1.4')) stop('Repair expects frozen extended revision1.4.')
  manifest <- utils::read.csv(file.path(path, 'artifact_hashes.csv'), stringsAsFactors = FALSE)
  if (!all(c('file', 'sha256') %in% names(manifest)) || anyDuplicated(manifest$file))
    stop('Invalid extended artifact manifest.')
  missing_manifest <- setdiff(setdiff(required, 'artifact_hashes.csv'), manifest$file)
  if (length(missing_manifest)) stop('Required inputs are not hash-bound: ', paste(missing_manifest, collapse = ', '))
  base <- paste0(normalizePath(path, winslash = '/', mustWork = TRUE), '/')
  sha <- function(file) digest::digest(file = file, algo = 'sha256', serialize = FALSE)
  checks <- lapply(seq_len(nrow(manifest)), function(i) {
    file <- file.path(path, manifest$file[[i]])
    resolved <- normalizePath(file, winslash = '/', mustWork = FALSE)
    inside <- startsWith(tolower(resolved), tolower(base))
    actual <- if (inside && file.exists(file)) sha(file) else NA_character_
    data.frame(file = manifest$file[[i]], expected_sha256 = manifest$sha256[[i]],
      actual_sha256 = actual, matches = !is.na(actual) && identical(tolower(actual), tolower(manifest$sha256[[i]])))
  })
  checks <- do.call(rbind, checks)
  if (!all(checks$matches)) stop('Extended input artifact hash mismatch: ', paste(checks$file[!checks$matches], collapse = ', '))
  sources <- utils::read.csv(file.path(path, 'sources_manifest.csv'), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(sources)))
    if (!file.exists(sources$file[[i]]) || !identical(sha(sources$file[[i]]), sources$sha256[[i]]))
      stop('Immutable raw/codebook cache hash differs: ', sources$file[[i]])
  plan_path <- file.path(opts$root, 'analysis', 'config', 'plan-v1.5.json')
  if (!file.exists(plan_path)) stop('Accepted plan-v1.5.json is required.')
  plan <- jsonlite::read_json(plan_path, simplifyVector = TRUE)
  if (!identical(plan$version, '1.5')) stop('Plan file version must be1.5.')
  list(path = path, report = report, manifest = manifest, checks = checks, sources = sources,
       master_sha256 = sha(file.path(path, 'derived', 'master.rds')),
       artifact_manifest_sha256 = sha(file.path(path, 'artifact_hashes.csv')),
       report_sha256 = sha(file.path(path, 'report.json')), plan_path = plan_path, plan_sha256 = sha(plan_path))
}

repair_definitions <- function(upstream) {
  list(task = 'R-REPAIR-003', revision = '1.5', status = 'primary candidate with partial recomputation',
    inherited = 'All accepted1.4 population, outcome, categorical, weights, Model1/2 and inference definitions retained.',
    source = 'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm',
    purpose = 'CDC-recommended backward assay harmonization when pooling2017-2018 with earlier cycles.',
    equations = list(creatinine = '2017-2018 only:1.051*LBXSCR-0.06945 mg/dL',
      triglycerides = '2017-2018 only:0.9655*LBXSTR-7.020 mg/dL'),
    raw_preservation = 'Original LBXSCR/LBXSTR and separate assay_raw/before_harmonization columns are preserved. Cache never changes.',
    imputation = 'Apply equations before primary-domain median imputation; retain missing indicators. Recompute medians for the two changed labs.',
    nonfasting = 'BIOPRO LBXSTR biochemical-profile candidate remains distinct from CDC reference fasting LBXTR.',
    candidate_A = 'Same MEC/5 weights and core domain; harmonization revises A, not a third candidate.',
    candidate_B = 'Same dietary-weight sensitivity domain/weights; harmonization also revises B. Table1/2 only.',
    mandatory_recomputed = c('All Model3 oral/perio/trend fits in A Table2/Table3/SupI/SupII and B Table2',
      'A smoking/age and B smoking Model3 joint interactions',
      'Changed laboratory continuous Table1 rows/tests and all Model1-3 forest figures'),
    permitted_reuse = 'E1 Model1/2, their trends, sample counts/formulas and unaffected descriptive rows; explicit source-run/hash/row provenance.',
    stale_policy = 'No unharmonized E1 Model3 coefficient/trend/interaction/forest is copied into current primary outputs.',
    complete_case = 'Optional flag recomputes A-only common Model3 complete-case sensitivity; default false.',
    upstream_data_version = upstream$report$data_version, upstream_master_sha256 = upstream$master_sha256,
    plan_file = basename(upstream$plan_path), plan_sha256 = upstream$plan_sha256,
    exposure_audit = 'Published results visible during source review; this repair follows CDC assay documentation, without target matching.')
}

harmonize_master <- function(ctx, original) {
  master <- original
  if (any(c('creatinine_before_harmonization', 'triglycerides_biopro_before_harmonization') %in% names(master)))
    stop('Input already contains harmonization columns; refusing to double-adjust.')
  late <- master$cycle_start == 2017
  master$creatinine_assay_raw <- finite_numeric(numeric_col(master, 'LBXSCR'))
  master$triglycerides_biopro_assay_raw <- finite_numeric(numeric_col(master, 'LBXSTR'))
  master$creatinine_before_harmonization <- master$creatinine
  master$triglycerides_biopro_before_harmonization <- master$triglycerides_biopro
  master$creatinine <- master$creatinine_assay_raw
  master$triglycerides_biopro <- master$triglycerides_biopro_assay_raw
  master$creatinine[late] <- 1.051 * master$creatinine_assay_raw[late] - 0.06945
  master$triglycerides_biopro[late] <- 0.9655 * master$triglycerides_biopro_assay_raw[late] - 7.020
  master$creatinine_backward_harmonized_J <- late & !is.na(master$creatinine_assay_raw)
  master$triglycerides_backward_harmonized_J <- late & !is.na(master$triglycerides_biopro_assay_raw)
  master$data_version <- ctx$data_version
  changed <- c('creatinine', 'triglycerides_biopro')
  imputation <- list()
  for (variable in changed) {
    value <- master[[variable]]
    donor <- value[master$analysis_domain & !is.na(value)]
    if (!length(donor)) stop('No observed primary donor for ', variable)
    median <- stats::median(donor)
    filled <- value
    filled[is.na(value)] <- median
    master[[paste0(variable, '_filled')]] <- filled
    master[[paste0(variable, '_missing')]] <- as.integer(is.na(value))
    assert_invariant(ctx, paste0(variable, '_missingness_unchanged'),
      identical(is.na(value), is.na(original[[variable]])))
    assert_invariant(ctx, paste0(variable, '_finite_filled'), all(is.finite(filled)))
    assert_invariant(ctx, paste0(variable, '_pre2017_unchanged'),
      identical(value[!late], original[[variable]][!late]))
    imputation[[length(imputation) + 1L]] <- data.frame(variable = variable,
      raw_variable = if (variable == 'creatinine') 'LBXSCR' else 'LBXSTR',
      median_value = median, observed_primary_n = length(donor),
      missing_primary_n = sum(is.na(value) & master$analysis_domain),
      strategy = 'Primary-domain median after CDC J backward harmonization plus missing indicator')
  }
  excluded <- c('data_version', changed, paste0(changed, '_filled'), paste0(changed, '_missing'))
  unaffected <- setdiff(names(original), excluded)
  assert_invariant(ctx, 'all_unaffected_original_columns_identical',
    identical(master[, unaffected, drop = FALSE], original[, unaffected, drop = FALSE]))
  assert_invariant(ctx, 'raw_assay_columns_unchanged',
    identical(master$LBXSCR, original$LBXSCR) && identical(master$LBXSTR, original$LBXSTR))
  assert_invariant(ctx, 'primary_and_dietary_domains_unchanged',
    identical(master$analysis_domain, original$analysis_domain) &&
      identical(master$dietary_sensitivity_domain, original$dietary_sensitivity_domain))
  summary <- list()
  for (variable in changed) for (cycle in unique(master$cycle)) {
    keep <- master$cycle == cycle
    before <- original[[variable]][keep]; after <- master[[variable]][keep]
    observed <- !is.na(after)
    summary[[length(summary) + 1L]] <- data.frame(variable = variable, cycle = cycle,
      n = sum(keep), observed_n = sum(observed), changed_n = sum(before != after, na.rm = TRUE),
      mean_before = mean(before, na.rm = TRUE), mean_after = mean(after, na.rm = TRUE),
      median_before = stats::median(before, na.rm = TRUE), median_after = stats::median(after, na.rm = TRUE),
      min_after = min(after, na.rm = TRUE), max_after = max(after, na.rm = TRUE),
      missingness_matches = identical(is.na(before), is.na(after)))
  }
  write_csv(do.call(rbind, summary), file.path(ctx$run_dir, 'tables', 'harmonization_cycle_summary.csv'))
  write_csv(master[late, c('SEQN', 'cycle', 'creatinine_assay_raw', 'creatinine',
    'triglycerides_biopro_assay_raw', 'triglycerides_biopro', 'analysis_domain', 'dietary_sensitivity_domain')],
    file.path(ctx$run_dir, 'tables', 'harmonization_J_records.csv'))
  list(master = master, changed_imputation = do.call(rbind, imputation))
}

bind_rows_aligned <- function(parts) {
  columns <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    for (column in setdiff(columns, names(x))) x[[column]] <- NA
    x[, columns, drop = FALSE]
  })
  do.call(rbind, parts)
}
repair_family_scope <- function(candidate) {
  if (candidate == 'B') return(c(table2 = 'hypertension_code'))
  c(table2 = 'hypertension_code', table3 = 'hypertension_code',
    supplement_measured = 'measured_htn', supplement_diagnosed_treated = 'diagnosed_or_treated_htn')
}
repair_m3_suite <- function(ctx, design, candidate, family, outcome) {
  if (startsWith(family, 'supplement')) {
    diagnosed <- design$variables$diagnosed_or_treated_htn
    keep <- if (family == 'supplement_measured') !is.na(diagnosed) & diagnosed == 0L else
      (!is.na(diagnosed) & diagnosed == 1L) | design$variables$hypertension_code == 0L
    design <- design[keep, ]
  }
  groups <- if (family == 'table3') c('30-44', '45+') else if (startsWith(family, 'supplement')) 'Overall' else c('Overall', 'No', 'Yes')
  rows <- list(); counts <- list(); trends <- list(); metadata <- list()
  for (group in groups) {
    d <- design
    if (group != 'Overall') {
      keep <- if (family == 'table3') d$variables$age_group == group else d$variables$smoking == group
      d <- d[!is.na(keep) & keep, ]
    }
    d <- d[!is.na(d$variables[[outcome]]), ]
    if (!nrow(d$variables) || length(unique(d$variables[[outcome]])) < 2L)
      stop('Insufficient Model3 outcome variation: ', candidate, family, group, outcome)
    registry_family <- if (family == 'table3') 'table3' else if (startsWith(family, 'supplement')) 'supplement' else 'table2'
    covariates <- extension_models(registry_family,
      smoking_stratum = family != 'table3' && group != 'Overall')$Model3
    for (exposure in c('periodontal', 'oral_health')) {
      fit <- fit_extended(ctx, d, exposure, covariates, outcome, family, group, 'Model3', candidate)
      fit$metadata$calculation_status <- 'recomputed_after_CDC_J_backward_harmonization'
      fit$metadata$effective_data_version <- ctx$data_version
      rows[[length(rows) + 1L]] <- fit$coefficients
      metadata[[paste(group, 'Model3', exposure, sep = '_')]] <- fit$metadata
      counts[[length(counts) + 1L]] <- data.frame(candidate = candidate, family = family,
        outcome = outcome, subgroup = group, model = 'Model3', exposure = exposure,
        n = nrow(d$variables), cases_n = sum(d$variables[[outcome]] == 1L),
        controls_n = sum(d$variables[[outcome]] == 0L), design_df = survey::degf(d),
        model_residual_df = fit$metadata$residual_df, formula = fit$metadata$formula)
    }
    fit <- fit_extended(ctx, d, 'oral_score', covariates, outcome, family, group, 'Model3', candidate)
    trend <- fit$coefficients[fit$coefficients$term == 'oral_score', , drop = FALSE]
    trend$score_rule <- 'Excellent/Very good0;Good1;Fair2;Poor3'
    trends[[length(trends) + 1L]] <- trend
    fit$metadata$calculation_status <- 'recomputed_after_CDC_J_backward_harmonization'
    fit$metadata$effective_data_version <- ctx$data_version
    metadata[[paste(group, 'Model3', 'oral_trend', sep = '_')]] <- fit$metadata
  }
  list(coefficients = do.call(rbind, rows), counts = do.call(rbind, counts),
    trends = do.call(rbind, trends), metadata = metadata)
}

add_row_provenance <- function(ctx, rows) {
  recomputed <- rows$model == 'Model3'
  rows$provenance_run <- ifelse(recomputed, ctx$options$run_id, ctx$options$input_extended_run)
  rows$calculation_status <- ifelse(recomputed, 'recomputed_harmonized_J', 'reused_unaffected_Model1_or_Model2')
  rows$source_data_version <- ifelse(recomputed, ctx$data_version, ctx$upstream$report$data_version)
  rows$effective_data_version <- ctx$data_version
  rows
}
row_key <- function(x, columns) do.call(paste, c(x[, columns, drop = FALSE], sep = '|'))

check_model_coverage <- function(ctx, coefficients, counts, trends) {
  candidates <- ctx$candidates
  for (candidate in candidates) {
    scope <- repair_family_scope(candidate)
    for (family in names(scope)) {
      groups <- if (family == 'table3') c('30-44', '45+') else if (startsWith(family, 'supplement')) 'Overall' else c('Overall', 'No', 'Yes')
      for (group in groups) for (model in c('Model1', 'Model2', 'Model3')) {
        crows <- counts[counts$candidate == candidate & counts$family == family & counts$subgroup == group & counts$model == model, ]
        assert_invariant(ctx, paste(candidate, family, group, model, 'two_exposure_models_present', sep = '_'),
          nrow(crows) == 2L && setequal(crows$exposure, c('periodontal', 'oral_health')))
        for (exposure in c('periodontal', 'oral_health')) {
          rows <- coefficients[coefficients$candidate == candidate & coefficients$family == family &
            coefficients$subgroup == group & coefficients$model == model & coefficients$exposure == exposure & coefficients$is_exposure, ]
          assert_invariant(ctx, paste(candidate, family, group, model, exposure, 'effects_present', sep = '_'),
            nrow(rows) == if (exposure == 'periodontal') 1L else 3L)
        }
        trows <- trends[trends$candidate == candidate & trends$family == family & trends$subgroup == group & trends$model == model, ]
        assert_invariant(ctx, paste(candidate, family, group, model, 'one_oral_trend_present', sep = '_'), nrow(trows) == 1L)
      }
    }
  }
  key <- row_key(coefficients, c('candidate', 'family', 'subgroup', 'model', 'exposure', 'outcome', 'term'))
  assert_invariant(ctx, 'merged_coefficient_keys_unique', !anyDuplicated(key))
}

copy_unaffected <- function(ctx) {
  upstream <- ctx$upstream
  relative <- upstream$manifest$file
  skip_tables <- c('all_model_coefficients.csv', 'model_sample_counts_formulas.csv', 'oral_trend_tests.csv',
    'interaction_joint_wald.csv', 'interaction_coefficients.csv', 'continuous_missing_indicators.csv', 'invariants.csv')
  table_candidates <- startsWith(relative, 'tables/') & !basename(relative) %in% skip_tables &
    !grepl('table1_continuous|exposure_or|common_complete_case', basename(relative))
  model_candidates <- startsWith(relative, 'models/') & grepl('_Model[12]_', basename(relative))
  keep <- table_candidates | model_candidates
  # Only selected candidate-prefixed tables/models are reused.
  for (candidate in setdiff(c('A', 'B'), ctx$candidates))
    keep <- keep & !startsWith(basename(relative), paste0(candidate, '_'))
  copied <- list()
  for (file in relative[keep]) {
    source <- file.path(upstream$path, file)
    destination <- file.path(ctx$run_dir, file)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(source, destination, overwrite = FALSE)) stop('Could not copy unaffected artifact: ', file)
    assert_invariant(ctx, paste0('copied_unaffected_hash_', gsub('[^A-Za-z0-9]', '_', file)),
      identical(hash_file(source), hash_file(destination)))
    copied[[length(copied) + 1L]] <- data.frame(artifact = file, disposition = 'copied_unaffected',
      source_run = ctx$options$input_extended_run, source_file = file,
      source_sha256 = hash_file(source), source_data_version = upstream$report$data_version,
      effective_data_version = ctx$data_version, reason = 'Does not depend on changed creatinine/TG values')
  }
  if (length(copied)) do.call(rbind, copied) else data.frame()
}

rebuild_changed_table1 <- function(ctx, designs) {
  dependencies <- list()
  for (candidate in names(designs)) {
    d <- designs[[candidate]]$domain
    for (kind in c('continuous', 'continuous_tests')) {
      name <- paste0(candidate, '_table1_', kind, '.csv')
      source_path <- file.path(ctx$upstream$path, 'tables', name)
      if (!file.exists(source_path)) stop('Required upstream Table1 is absent: ', name)
      original <- utils::read.csv(source_path, stringsAsFactors = FALSE)
      replacement <- if (kind == 'continuous') table1_continuous(d, c('creatinine', 'triglycerides_biopro')) else
        continuous_tests(d, c('creatinine', 'triglycerides_biopro'))
      if ('candidate' %in% names(original)) replacement$candidate <- candidate
      unchanged <- original[!original$variable %in% c('creatinine', 'triglycerides_biopro'), , drop = FALSE]
      result <- bind_rows_aligned(list(unchanged, replacement))
      keys <- if (kind == 'continuous') c('variable', 'hypertension_group') else c('variable', 'method')
      original_keys <- row_key(original, keys)
      order <- match(original_keys, row_key(result, keys))
      assert_invariant(ctx, paste(candidate, 'Table1', kind, 'same_row_keys', sep = '_'), !anyNA(order) && nrow(result) == nrow(original))
      result <- result[order, , drop = FALSE]
      write_csv(result, file.path(ctx$run_dir, 'tables', name))
      recalculated <- result$variable %in% c('creatinine', 'triglycerides_biopro')
      dependencies[[length(dependencies) + 1L]] <- data.frame(artifact = paste0('tables/', name),
        row_key = original_keys, variable = result$variable,
        calculation_status = ifelse(recalculated, 'recomputed_harmonized_J', 'reused_unaffected'),
        source_run = ifelse(recalculated, ctx$options$run_id, ctx$options$input_extended_run),
        original_source_file = paste0('tables/', name), original_source_sha256 = hash_file(source_path),
        effective_data_version = ctx$data_version)
    }
  }
  write_csv(do.call(rbind, dependencies), file.path(ctx$run_dir, 'tables', 'table1_row_provenance.csv'))
}

plot_harmonization_qc <- function(ctx, master) {
  keep <- master$cycle_start == 2017 & master$analysis_domain
  grDevices::png(file.path(ctx$run_dir, 'figures', 'J_backward_harmonization_qc.png'), width = 1500, height = 700, res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(5, 5, 4, 2))
  for (variable in c('creatinine', 'triglycerides_biopro')) {
    x <- master[[paste0(variable, '_assay_raw')]][keep]
    y <- master[[variable]][keep]
    graphics::plot(x, y, pch = 16, cex = .3, col = grDevices::adjustcolor('#2166AC', alpha.f = .35),
      xlab = 'Original2017-2018 assay value (mg/dL)', ylab = 'Backward harmonized value (mg/dL)', main = variable)
    graphics::abline(a = 0, b = 1, lty = 2, col = '#777777')
  }
}

run_repair <- function(ctx) {
  start <- utc_now()
  options(timeout = 180, survey.lonely.psu = 'fail', survey.adjust.domain.lonely = FALSE)
  log_event(ctx, 'Start R-REPAIR-003 accepted plan1.5; immutable E1 reuse', ctx$options$input_extended_run)
  write_json(list(status = 'running', started_utc = start, options = ctx$options), file.path(ctx$run_dir, 'status.json'))
  signature <- paste(ctx$upstream$master_sha256, ctx$upstream$report$data_version, ctx$upstream$plan_sha256,
    '2017:creatinine=1.051*LBXSCR-0.06945;TG=0.9655*LBXSTR-7.020;before-median', sep = '|')
  ctx$data_version <- paste0('nhanes-2009-2018-harmonizedJ-', substr(digest::digest(signature, algo = 'sha256', serialize = FALSE), 1L, 20L))
  write_json(repair_definitions(ctx$upstream), file.path(ctx$run_dir, 'definitions.json'))
  write_csv(ctx$upstream$checks, file.path(ctx$run_dir, 'tables', 'upstream_artifact_checks.csv'))
  write_json(list(input_extended_run = ctx$options$input_extended_run,
    data_version = ctx$upstream$report$data_version, master_sha256 = ctx$upstream$master_sha256,
    artifact_manifest_sha256 = ctx$upstream$artifact_manifest_sha256, report_sha256 = ctx$upstream$report_sha256,
    all_input_artifact_hashes_verified = TRUE, all_raw_cache_hashes_verified = TRUE,
    inherited_core_run = ctx$upstream$report$input_run, plan_sha256 = ctx$upstream$plan_sha256),
    file.path(ctx$run_dir, 'upstream_input.json'))
  for (item in c('sources_manifest.csv', 'core_script_snapshot.R', 'executed_script.R')) {
    destination <- if (item == 'executed_script.R') 'extended_script_snapshot.R' else item
    file.copy(file.path(ctx$upstream$path, item), file.path(ctx$run_dir, destination), overwrite = FALSE)
  }
  file.copy(ctx$upstream$plan_path, file.path(ctx$run_dir, 'plan-v1.5.json'), overwrite = FALSE)
  original <- readRDS(file.path(ctx$upstream$path, 'derived', 'master.rds'))
  assert_invariant(ctx, 'upstream_master_data_version_matches_report',
    length(unique(original$data_version)) == 1L && identical(unique(original$data_version), ctx$upstream$report$data_version))
  changed <- harmonize_master(ctx, original)
  master <- changed$master
  check_derivation_fixture(ctx)
  check_addon_fixture(ctx)
  copied <- copy_unaffected(ctx)
  prior_imputation <- utils::read.csv(file.path(ctx$upstream$path, 'tables', 'continuous_missing_indicators.csv'), stringsAsFactors = FALSE)
  imputation <- bind_rows_aligned(list(prior_imputation[!prior_imputation$variable %in% c('creatinine', 'triglycerides_biopro'), ], changed$changed_imputation))
  write_csv(imputation, file.path(ctx$run_dir, 'tables', 'continuous_missing_indicators.csv'))
  log_event(ctx, 'Writing NEW harmonized master; source raw columns unchanged')
  saveRDS(master, file.path(ctx$run_dir, 'derived', 'master.rds'))
  write_csv(master, file.path(ctx$run_dir, 'derived', 'master.csv'))
  designs <- setNames(lapply(ctx$candidates, function(candidate) build_candidate(ctx, master, candidate)), ctx$candidates)
  rebuild_changed_table1(ctx, designs)
  plot_harmonization_qc(ctx, master)
  old_coefficients <- utils::read.csv(file.path(ctx$upstream$path, 'tables', 'all_model_coefficients.csv'), stringsAsFactors = FALSE)
  old_counts <- utils::read.csv(file.path(ctx$upstream$path, 'tables', 'model_sample_counts_formulas.csv'), stringsAsFactors = FALSE)
  old_trends <- utils::read.csv(file.path(ctx$upstream$path, 'tables', 'oral_trend_tests.csv'), stringsAsFactors = FALSE)
  unchanged_coefficients <- old_coefficients[old_coefficients$model %in% c('Model1', 'Model2') & old_coefficients$candidate %in% ctx$candidates, ]
  unchanged_counts <- old_counts[old_counts$model %in% c('Model1', 'Model2') & old_counts$candidate %in% ctx$candidates, ]
  unchanged_trends <- old_trends[old_trends$model %in% c('Model1', 'Model2') & old_trends$candidate %in% ctx$candidates, ]
  coefficient_parts <- list(unchanged_coefficients); count_parts <- list(unchanged_counts); trend_parts <- list(unchanged_trends)
  old_metadata <- jsonlite::read_json(file.path(ctx$upstream$path, 'models', 'model_metadata.json'), simplifyVector = FALSE)
  metadata <- list(); interactions <- list(); interaction_coefficients <- list(); cc <- list()
  for (candidate in ctx$candidates) {
    d <- designs[[candidate]]$domain
    scope <- repair_family_scope(candidate)
    for (family in names(scope)) {
      result <- repair_m3_suite(ctx, d, candidate, family, scope[[family]])
      coefficient_parts[[length(coefficient_parts) + 1L]] <- result$coefficients
      count_parts[[length(count_parts) + 1L]] <- result$counts
      trend_parts[[length(trend_parts) + 1L]] <- result$trends
      key <- paste(candidate, family, sep = '_')
      prior <- old_metadata[[key]]
      prior <- prior[!grepl('_Model3_', names(prior), fixed = TRUE)]
      prior <- lapply(prior, function(entry) {
        entry$calculation_status <- 'reused_unaffected_Model1_or_Model2'
        entry$provenance_run <- ctx$options$input_extended_run
        entry$source_data_version <- ctx$upstream$report$data_version
        entry$effective_data_version <- ctx$data_version
        entry
      })
      metadata[[key]] <- c(prior, result$metadata)
    }
    result <- interaction_suite(ctx, d, candidate)
    result$tests$provenance_run <- ctx$options$run_id
    result$tests$calculation_status <- 'recomputed_harmonized_J'
    result$tests$effective_data_version <- ctx$data_version
    result$coefficients$provenance_run <- ctx$options$run_id
    result$coefficients$calculation_status <- 'recomputed_harmonized_J'
    result$coefficients$effective_data_version <- ctx$data_version
    interactions[[length(interactions) + 1L]] <- result$tests
    interaction_coefficients[[length(interaction_coefficients) + 1L]] <- result$coefficients
    metadata[[paste0(candidate, '_interactions')]] <- result$metadata
  }
  if (ctx$options$complete_case) {
    if (!'A' %in% names(designs)) stop('Optional complete-case repair requires candidate A.')
    cc$A <- optional_complete_case(ctx, designs$A$domain, 'A')
  }
  coefficients <- add_row_provenance(ctx, bind_rows_aligned(coefficient_parts))
  counts <- add_row_provenance(ctx, bind_rows_aligned(count_parts))
  trends <- add_row_provenance(ctx, bind_rows_aligned(trend_parts))
  check_model_coverage(ctx, coefficients, counts, trends)
  expected_counts <- old_counts[old_counts$candidate %in% ctx$candidates, ]
  keys <- c('candidate', 'family', 'subgroup', 'model', 'exposure', 'outcome')
  index <- match(row_key(counts, keys), row_key(expected_counts, keys))
  assert_invariant(ctx, 'all_model_samples_match_E1_no_selection_change',
    !anyNA(index) && identical(as.numeric(counts$n), as.numeric(expected_counts$n[index])) &&
      identical(as.numeric(counts$cases_n), as.numeric(expected_counts$cases_n[index])) &&
      identical(as.numeric(counts$controls_n), as.numeric(expected_counts$controls_n[index])))
  assert_invariant(ctx, 'Model1_Model2_coefficients_reused_identically',
    isTRUE(all.equal(coefficients[coefficients$model %in% c('Model1', 'Model2'), names(unchanged_coefficients), drop = FALSE],
                     unchanged_coefficients, check.attributes = FALSE, tolerance = 0)))
  model3_rows <- coefficients$model == 'Model3'
  assert_invariant(ctx, 'no_stale_Model3_primary_coefficients',
    all(coefficients$provenance_run[model3_rows] == ctx$options$run_id &
      coefficients$source_data_version[model3_rows] == ctx$data_version))
  # Keep the primary CSV schemas exactly as E1; lineage belongs in sidecars.
  primary_coefficients <- coefficients[, names(old_coefficients), drop = FALSE]
  write_csv(primary_coefficients, file.path(ctx$run_dir, 'tables', 'all_model_coefficients.csv'))
  write_csv(counts[, names(old_counts), drop = FALSE], file.path(ctx$run_dir, 'tables', 'model_sample_counts_formulas.csv'))
  write_csv(trends[, names(old_trends), drop = FALSE], file.path(ctx$run_dir, 'tables', 'oral_trend_tests.csv'))
  joint <- do.call(rbind, interactions)
  assert_invariant(ctx, 'mandatory_interaction_count', nrow(joint) == sum(ifelse(ctx$candidates == 'A', 4L, 2L)))
  joint_schema <- names(utils::read.csv(file.path(ctx$upstream$path, 'tables', 'interaction_joint_wald.csv'), nrows = 0))
  interaction_schema <- names(utils::read.csv(file.path(ctx$upstream$path, 'tables', 'interaction_coefficients.csv'), nrows = 0))
  write_csv(joint[, joint_schema, drop = FALSE], file.path(ctx$run_dir, 'tables', 'interaction_joint_wald.csv'))
  interaction_rows <- bind_rows_aligned(interaction_coefficients)
  write_csv(interaction_rows[, interaction_schema, drop = FALSE], file.path(ctx$run_dir, 'tables', 'interaction_coefficients.csv'))
  write_json(metadata, file.path(ctx$run_dir, 'models', 'model_metadata.json'))
  for (candidate in ctx$candidates) {
    for (family in names(repair_family_scope(candidate))) {
      rows <- primary_coefficients[primary_coefficients$candidate == candidate & primary_coefficients$family == family, ]
      write_csv(exposure_rows_with_references(rows), file.path(ctx$run_dir, 'tables', paste0(candidate, '_', family, '_exposure_or.csv')))
    }
    plot_extended_forest(ctx, coefficients, candidate)
  }
  mixed <- lapply(c('all_model_coefficients.csv', 'model_sample_counts_formulas.csv', 'oral_trend_tests.csv'), function(name)
    data.frame(artifact = paste0('tables/', name), disposition = 'merged_reused_M1_M2_and_recomputed_M3',
      source_run = ctx$options$input_extended_run, source_file = paste0('tables/', name),
      source_sha256 = hash_file(file.path(ctx$upstream$path, 'tables', name)),
      source_data_version = ctx$upstream$report$data_version, effective_data_version = ctx$data_version,
      reason = 'Model1/2 unchanged; Model3 fully recomputed after harmonization'))
  dependencies <- bind_rows_aligned(c(list(copied), mixed))
  write_csv(dependencies, file.path(ctx$run_dir, 'artifact_dependencies.csv'))
  write_csv(counts[, c('candidate', 'family', 'subgroup', 'model', 'exposure', 'outcome',
    'provenance_run', 'calculation_status', 'source_data_version', 'effective_data_version')],
    file.path(ctx$run_dir, 'tables', 'model_row_provenance.csv'))
  write_csv(coefficients[, c('candidate', 'family', 'subgroup', 'model', 'exposure', 'outcome', 'term',
    'provenance_run', 'calculation_status', 'source_data_version', 'effective_data_version')],
    file.path(ctx$run_dir, 'tables', 'coefficient_row_provenance.csv'))
  write_csv(trends[, c('candidate', 'family', 'subgroup', 'model', 'term',
    'provenance_run', 'calculation_status', 'source_data_version', 'effective_data_version')],
    file.path(ctx$run_dir, 'tables', 'oral_trend_row_provenance.csv'))
  write_csv(joint[, c('candidate', 'exposure', 'modifier', 'provenance_run', 'calculation_status', 'effective_data_version')],
    file.path(ctx$run_dir, 'tables', 'interaction_row_provenance.csv'))
  file_arg <- grep('^--file=', commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg)) file.copy(sub('^--file=', '', file_arg[[1L]]), file.path(ctx$run_dir, 'executed_script.R'), overwrite = FALSE)
  report <- ctx$upstream$report
  report$task <- 'R-REPAIR-003'; report$revision <- '1.5'; report$run_id <- ctx$options$run_id
  report$stage <- 'partial_recompute_Model3_after_CDC_J_backward_harmonization'
  report$started_utc <- start; report$completed_utc <- utc_now(); report$data_version <- ctx$data_version
  report$input_extended_run <- ctx$options$input_extended_run
  report$source_core_run <- ctx$upstream$report$input_run
  report$upstream_data_version <- ctx$upstream$report$data_version
  report$upstream_master_sha256 <- ctx$upstream$master_sha256
  report$candidates <- lapply(designs, function(x) x$metadata)
  report$common_complete_case <- cc
  report$fit_recomputation <- list(models = 'Model3 only, including every approved subgroup/trend/interaction',
    reused = 'Model1/2 and unaffected Table1 rows, explicitly source-bound to E1',
    expected_fit_n = if ('A' %in% ctx$candidates) 25L else 0L)
  report$fit_recomputation$expected_fit_n <-
    sum(ifelse(ctx$candidates == 'A', 25L, 11L)) + if (ctx$options$complete_case) 2L else 0L
  report$warnings_n <- nrow(ctx$warnings); report$invariants_passed <- sum(ctx$invariants$passed)
  report$warnings_scope <- 'New repair computation warnings; historical unchanged-output warnings remain in E1/logs/warnings.csv.'
  report$scientific_interpretation <- 'A/B definitions corrected by CDC harmonization; E1 retained as unharmonized diagnostic, not a third candidate.'
  report$qa_core <- ctx$upstream$report$qa_core
  report$qa_extension <- ctx$upstream$report$qa_extension
  report$qa_provenance <- 'Inherited QA counts are valid because every unaffected original column and all missingness/domain flags are invariant-checked.'
  write_json(report, file.path(ctx$run_dir, 'report.json'))
  write_json(list(status = 'success', revision = '1.5', completed_utc = utc_now(),
    run_id = ctx$options$run_id, data_version = ctx$data_version, input_extended_run = ctx$options$input_extended_run),
    file.path(ctx$run_dir, 'status.json'))
  log_event(ctx, 'Repair success; complete primary outputs with explicit reused dependencies', ctx$run_dir)
  finalize_artifacts(ctx)
}

repair_main <- function() {
  opts <- repair_cli(commandArgs(trailingOnly = TRUE))
  project_lib <- file.path(opts$root, 'analysis', 'r-library')
  if (dir.exists(project_lib)) .libPaths(c(project_lib, .libPaths()))
  for (package in c('jsonlite', 'digest'))
    if (!requireNamespace(package, quietly = TRUE)) stop('Required installed package: ', package)
  upstream <- verify_extended_input(opts)
  source(file.path(upstream$path, 'core_script_snapshot.R'), local = .GlobalEnv, encoding = 'UTF-8')
  source(file.path(upstream$path, 'executed_script.R'), local = .GlobalEnv, encoding = 'UTF-8')
  ctx <- new_context(opts)
  ctx$upstream <- upstream
  ctx$candidates <- if (opts$candidate == 'both') c('A', 'B') else opts$candidate
  tryCatch(withCallingHandlers(run_repair(ctx), warning = function(w) {
    ctx$warnings <- rbind(ctx$warnings, data.frame(time_utc = utc_now(), message = conditionMessage(w),
      call = paste(deparse(conditionCall(w)), collapse = ' ')))
    log_event(ctx, 'WARNING:', conditionMessage(w)); invokeRestart('muffleWarning')
  }), error = function(e) {
    log_event(ctx, 'FAILED:', conditionMessage(e))
    write_json(list(status = 'failed', revision = '1.5', failed_utc = utc_now(), error = conditionMessage(e)),
      file.path(ctx$run_dir, 'status.json'))
    try(finalize_artifacts(ctx), silent = TRUE)
    stop(e)
  })
}

if (sys.nframe() == 0L) repair_main()
