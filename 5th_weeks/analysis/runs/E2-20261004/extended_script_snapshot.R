Sys.setlocale('LC_ALL', 'English_United States.utf8')
# R-EXT-002, accepted plan revision 1.4. Source core run_analysis.R, then reuse an
# immutable successful core run. No packages are installed and no core run changes.
# Rscript analysis/src/extend_models.R . NEW_RUN --input-run=CORE_RUN --candidate=both
# --candidate=A|B|both; --stage=test|model (default model); --complete-case=true|false
# A: MEC/5 candidate reconstruction. B: dietary-weight sensitivity, not a solution
# for every bias. Both retain the same core definitions and BIOPRO triglycerides.

extension_cli <- function(args) {
  positional <- args[!startsWith(args, '--')]
  if (length(positional) > 2L) stop('Positional arguments: root and new run ID.')
  options <- list(root = if (length(positional)) positional[[1L]] else '.',
    run_id = if (length(positional) >= 2L) positional[[2L]] else format(Sys.time(), '%Y%m%dT%H%M%S'),
    input_run = NULL, candidate = 'both', stage = 'model', complete_case = FALSE)
  for (arg in args[startsWith(args, '--')]) {
    pair <- strsplit(sub('^--', '', arg), '=', fixed = TRUE)[[1L]]
    if (length(pair) != 2L || !pair[[1L]] %in% c('input-run', 'candidate', 'stage', 'complete-case'))
      stop('Invalid extension option: ', arg)
    options[[gsub('-', '_', pair[[1L]], fixed = TRUE)]] <- pair[[2L]]
  }
  if (is.null(options$input_run)) stop('--input-run=successful-core-run is required.')
  if (!options$candidate %in% c('A', 'B', 'both')) stop('candidate must be A, B, or both.')
  if (!options$stage %in% c('test', 'model')) stop('stage must be test or model.')
  if (!as.character(options$complete_case) %in% c('FALSE', 'TRUE', 'false', 'true'))
    stop('complete-case must be true or false.')
  options$complete_case <- tolower(as.character(options$complete_case)) == 'true'
  for (id in c(options$run_id, options$input_run))
    if (!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$', id) || id %in% c('.', '..'))
      stop('Run IDs must be safe ASCII directory names.')
  options$root <- normalizePath(options$root, winslash = '/', mustWork = TRUE)
  options
}

addon_registry <- function() list(
  BMX = 'BMXBMI', SLQ = c('SLD010H', 'SLD012'),
  ALQ = c('ALQ101', 'ALQ110', 'ALQ120Q', 'ALQ120U', 'ALQ111', 'ALQ121', 'ALQ130'),
  PAQ = c('PAQ605', 'PAQ620', 'PAQ635', 'PAQ650', 'PAQ665'),
  MCQ = c('MCQ160B', 'MCQ160C', 'MCQ160D', 'MCQ160E', 'MCQ160F'),
  DIQ = 'DIQ010', DR1TOT = c('WTDRD1', 'DR1DRSTZ', 'DR1TSODI', 'DR1TTFAT'),
  TCHOL = 'LBXTC', HDL = 'LBDHDD', GHB = 'LBXGH', BIOPRO = c('LBXSCR', 'LBXSTR'))

acquire_addons <- function(ctx, acquired) {
  master <- acquired$master
  registry <- addon_registry()
  wanted <- unique(unlist(registry, use.names = FALSE))
  for (name in wanted) if (!name %in% names(master)) master[[name]] <- NA_real_
  manifests <- list()
  counts <- list()
  cycles <- data.frame(year = c(2009L, 2011L, 2013L, 2015L, 2017L), suffix = c('F', 'G', 'H', 'I', 'J'))
  for (i in seq_len(nrow(cycles))) {
    year <- cycles$year[[i]]
    suffix <- cycles$suffix[[i]]
    selected <- which(master$cycle_start == year)
    original_seqn <- as.numeric(master$SEQN[selected])
    for (component in names(registry)) {
      stem <- paste0(component, '_', suffix)
      url_base <- paste0('https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/', year, '/DataFiles/', stem)
      dat <- NULL
      for (kind in c('xpt', 'htm')) {
        path <- file.path(if (kind == 'xpt') ctx$raw_dir else ctx$source_dir, paste0(stem, '.', kind))
        cache <- ensure_cache(ctx, paste0(url_base, '.', kind), path,
                              if (kind == 'xpt') validate_xpt else validate_codebook)
        if (kind == 'xpt') dat <- as.data.frame(cache$data)
        manifests[[length(manifests) + 1L]] <- data.frame(
          cycle = paste0(year, '-', year + 1L), component = component, kind = kind,
          file = normalizePath(path, winslash = '/', mustWork = TRUE), url = paste0(url_base, '.', kind),
          bytes = file.info(path)$size, sha256 = hash_file(path), cache_status = cache$cache_status,
          retrieved_utc = cache$retrieved_utc, stringsAsFactors = FALSE)
      }
      matched <- match(original_seqn, as.numeric(dat$SEQN))
      for (name in intersect(registry[[component]], names(dat)))
        master[[name]][selected] <- as.numeric(dat[[name]][matched])
      counts[[length(counts) + 1L]] <- data.frame(cycle = paste0(year, '-', year + 1L),
        component = component, source_n = nrow(dat), demo_n = length(selected),
        demo_matched_n = sum(!is.na(matched)),
        absent_fields = paste(setdiff(registry[[component]], names(dat)), collapse = '|'))
      assert_invariant(ctx, paste0('addon_', stem, '_no_row_change'),
                       identical(as.numeric(master$SEQN[selected]), original_seqn))
    }
  }
  addon_manifest <- do.call(rbind, manifests)
  assert_invariant(ctx, 'all_55_addon_xpt_files', sum(addon_manifest$kind == 'xpt') == 55L)
  manifest <- rbind(acquired$manifest, addon_manifest)
  raw <- manifest[manifest$kind == 'xpt', ]
  raw <- raw[order(raw$cycle, raw$component), ]
  signature <- paste(paste(basename(raw$file), raw$sha256, sep = ':'), collapse = '\n')
  version <- paste0('nhanes-2009-2018-full-', substr(
    digest::digest(signature, algo = 'sha256', serialize = FALSE), 1L, 20L))
  write_csv(manifest, file.path(ctx$run_dir, 'sources_manifest.csv'))
  write_csv(do.call(rbind, counts), file.path(ctx$run_dir, 'tables', 'addon_component_counts.csv'))
  list(master = master, data_version = version, manifest = manifest)
}

finite_numeric <- function(x) { x[!is.finite(x)] <- NA_real_; x }
categorized <- function(values, levels, reference = levels[[1L]]) {
  values[is.na(values)] <- 'Missing'
  factor(values, levels = c(reference, setdiff(levels, reference), 'Missing'))
}
any_yes_all_no <- function(master, names) {
  items <- vapply(names, function(name) numeric_col(master, name), numeric(nrow(master)))
  yes <- rowSums(items == 1, na.rm = TRUE) > 0
  no <- rowSums(items == 2, na.rm = TRUE) == length(names)
  result <- rep(NA_integer_, nrow(master))
  result[no] <- 0L
  result[yes] <- 1L
  result
}
derive_alcohol <- function(master) {
  quantity <- numeric_col(master, 'ALQ120Q')
  unit <- numeric_col(master, 'ALQ120U')
  drinks <- numeric_col(master, 'ALQ130')
  max_drinks <- ifelse(master$cycle_start <= 2013, 95, 15)
  drinks[!is.finite(drinks) | drinks < 1 | drinks > max_drinks] <- NA_real_
  weeks_per_year <- 365 / 7
  frequency <- rep(NA_real_, nrow(master))
  early <- master$cycle_start <= 2015
  valid_quantity <- is.finite(quantity) & quantity >= 0 & quantity <= 366
  frequency[which(early & valid_quantity & unit == 1)] <- quantity[which(early & valid_quantity & unit == 1)]
  frequency[which(early & valid_quantity & unit == 2)] <-
    quantity[which(early & valid_quantity & unit == 2)] * 12 / weeks_per_year
  frequency[which(early & valid_quantity & unit == 3)] <-
    quantity[which(early & valid_quantity & unit == 3)] / weeks_per_year
  annual_2017 <- c(365, 260, 182, 104, 52, 30, 12, 9, 4.5, 1.5)
  category <- numeric_col(master, 'ALQ121')
  late <- master$cycle_start == 2017
  for (code in 1:10) {
    index <- which(late & category == code)
    frequency[index] <- annual_2017[[code]] / weeks_per_year
  }
  # Reported current frequency zero has priority even if amount/unit is missing.
  none <- (early & valid_quantity & quantity == 0) |
    (early & numeric_col(master, 'ALQ101') == 2 & numeric_col(master, 'ALQ110') == 2) |
    (late & category == 0) | (late & numeric_col(master, 'ALQ111') == 2)
  none[is.na(none)] <- FALSE
  weekly_drinks <- frequency * drinks
  weekly_drinks[none] <- 0
  values <- rep(NA_character_, nrow(master))
  values[which(is.finite(weekly_drinks) & weekly_drinks == 0)] <- 'No drinks'
  values[which(is.finite(weekly_drinks) & weekly_drinks > 0 & weekly_drinks <= 1)] <- '<=1 drink/week'
  values[which(is.finite(weekly_drinks) & weekly_drinks > 1)] <- '>1 drink/week'
  list(weekly_drinks = weekly_drinks, frequency_weekly = frequency,
       category = categorized(values, c('No drinks', '<=1 drink/week', '>1 drink/week')),
       none_proxy = early & numeric_col(master, 'ALQ101') == 2 & numeric_col(master, 'ALQ110') == 2)
}

derive_addon_covariates <- function(ctx, master) {
  before_keys <- paste(master$cycle, master$SEQN, sep = ':')
  before_domain <- master$analysis_domain
  bmi <- finite_numeric(numeric_col(master, 'BMXBMI'))
  values <- rep(NA_character_, nrow(master))
  values[which(bmi < 18.5)] <- '<18.5'
  values[which(bmi >= 18.5 & bmi < 25)] <- '18.5-24.9'
  values[which(bmi >= 25 & bmi < 30)] <- '25-29.9'
  values[which(bmi >= 30)] <- '>=30'
  master$bmi <- bmi
  master$bmi_category <- categorized(values, c('<18.5', '18.5-24.9', '25-29.9', '>=30'), '18.5-24.9')
  sleep <- ifelse(master$cycle_start <= 2013, numeric_col(master, 'SLD010H'),
                  numeric_col(master, 'SLD012'))
  # SLD012 includes fractional hours. Test a continuous range, not 0:24 membership.
  sleep[!is.finite(sleep) | sleep < 0 | sleep > 24] <- NA_real_
  values <- rep(NA_character_, nrow(master))
  values[which(sleep < 7)] <- '<7 hours'
  values[which(sleep >= 7 & sleep <= 9)] <- '7-9 hours'
  values[which(sleep > 9)] <- '>9 hours'
  master$sleep_hours <- sleep
  master$sleep_category <- categorized(values, c('<7 hours', '7-9 hours', '>9 hours'), '7-9 hours')
  raw_sleep_late <- numeric_col(master, 'SLD012')
  half_hour <- master$cycle_start >= 2015 & is.finite(raw_sleep_late) &
    raw_sleep_late >= 0 & raw_sleep_late <= 24 & abs(raw_sleep_late - round(raw_sleep_late)) > 1e-12
  assert_invariant(ctx, 'sleep_fractional_hours_preserved',
                   all(master$sleep_hours[half_hour] == raw_sleep_late[half_hour]))
  alcohol <- derive_alcohol(master)
  master$alcohol_weekly_drinks <- alcohol$weekly_drinks
  master$alcohol_weekly_frequency <- alcohol$frequency_weekly
  master$alcohol_category <- alcohol$category
  master$alcohol_lifetime_lt12_proxy <- alcohol$none_proxy
  activity <- any_yes_all_no(master, c('PAQ605', 'PAQ620', 'PAQ635', 'PAQ650', 'PAQ665'))
  values <- ifelse(is.na(activity), NA_character_, ifelse(activity == 1, 'Active', 'Inactive'))
  master$activity_category <- categorized(values, c('Inactive', 'Active'))
  cvd <- any_yes_all_no(master, c('MCQ160B', 'MCQ160C', 'MCQ160D', 'MCQ160E', 'MCQ160F'))
  master$cvd_category <- categorized(as.character(label_binary(cvd)), c('No', 'Yes'))
  diabetes <- binary_code(numeric_col(master, 'DIQ010')) # code 3 borderline remains Missing
  master$diabetes_category <- categorized(as.character(label_binary(diabetes)), c('No', 'Yes'))
  continuous_raw <- c(sodium = 'DR1TSODI', fat = 'DR1TTFAT', total_cholesterol = 'LBXTC',
    creatinine = 'LBXSCR', triglycerides_biopro = 'LBXSTR', hba1c = 'LBXGH', hdl = 'LBDHDD')
  imputation <- list()
  for (name in names(continuous_raw)) {
    value <- finite_numeric(numeric_col(master, continuous_raw[[name]]))
    master[[name]] <- value
    donor <- value[master$analysis_domain & !is.na(value)]
    if (!length(donor)) stop('No primary-domain observations for continuous covariate: ', name)
    median_value <- stats::median(donor)
    missing <- is.na(value)
    filled <- value
    filled[missing] <- median_value
    master[[paste0(name, '_filled')]] <- filled
    master[[paste0(name, '_missing')]] <- as.integer(missing)
    imputation[[length(imputation) + 1L]] <- data.frame(variable = name,
      raw_variable = continuous_raw[[name]], median_value = median_value,
      observed_primary_n = length(donor), missing_primary_n = sum(missing & master$analysis_domain),
      strategy = 'Primary-domain observed median plus missing indicator; analyst assumption')
  }
  master$diet_weight <- numeric_col(master, 'WTDRD1') / 5
  master$diet_design_eligible <- is.finite(master$diet_weight) & master$diet_weight > 0 &
    is.finite(numeric_col(master, 'SDMVPSU')) & is.finite(numeric_col(master, 'SDMVSTRA'))
  master$dietary_sensitivity_domain <- master$analysis_domain &
    !is.na(numeric_col(master, 'DR1DRSTZ')) & numeric_col(master, 'DR1DRSTZ') == 1 &
    !is.na(master$sodium) & !is.na(master$fat) & master$diet_design_eligible
  master$data_version <- ctx$data_version
  assert_invariant(ctx, 'extension_preserves_core_record_keys',
                   identical(paste(master$cycle, master$SEQN, sep = ':'), before_keys))
  assert_invariant(ctx, 'extension_preserves_core_domain', identical(master$analysis_domain, before_domain))
  assert_invariant(ctx, 'B_is_subset_of_A',
                   all(!master$dietary_sensitivity_domain | master$analysis_domain))
  write_csv(do.call(rbind, imputation), file.path(ctx$run_dir, 'tables', 'continuous_missing_indicators.csv'))
  master
}

extension_definitions <- function() list(
  task = 'R-EXT-002', revision = '1.4', status = 'candidate reconstruction',
  core = 'Definitions are frozen from accepted rev1.1 successful input run.',
  candidates = list(A = 'WTMEC2YR/5; Table1/2/3 and supplements on approved domains',
    B = 'Dietary-weight sensitivity for Table1/2 only: WTDRD1/5 full dietary design, then core domain AND DR1DRSTZ==1 AND observed sodium/fat.'),
  interpretation_B = 'Dietary-weight sensitivity does not resolve every selection, confounding, or measurement bias.',
  triglycerides = paste('BIOPRO LBXSTR biochemical-profile triglyceride candidate without fasting restriction.',
    'This differs from CDC-recommended reference LBXTR fasting triglycerides; not a claim of lab equivalence.'),
  bmi = 'BMXBMI categories <18.5 / 18.5 to <25 / 25 to <30 / >=30; Missing indicator level',
  sleep = 'F-H SLD010H; I-J SLD012 continuous 0-24 valid range incl half hours; <7 / 7-9 / >9; Missing',
  alcohol = list(early = paste('F-I: ALQ120Q frequency * ALQ130 amount; ALQ120U 1 week,2 month,3 year.',
    'Weekly denominator 365/7; monthly frequency *12/(365/7); yearly /(365/7).'),
    late = 'J: ALQ121 1:10 mapped to annual frequency 365,260,182,104,52,30,12,9,4.5,1.5; divide by 365/7 and multiply ALQ130.',
    zeros = 'Reported frequency0 is No drinks regardless of missing unit/amount; J ALQ111==2 is No drinks.',
    proxy = 'F-I ALQ101==2 AND ALQ110==2 treated as No drinks: incomplete <12 lifetime drinks proxy, analyst assumption.',
    amount = 'ALQ130 F-H 1:95; I-J 1:15 (upper category 15 or more); refused/unknown Missing.',
    ambiguity = 'Category midpoint choices, nearly-every-day 260, and lifetime proxy are analyst assumptions; paper mapping unavailable.'),
  activity = 'Any PAQ605/620/635/650/665==1 Active; all==2 Inactive; otherwise Missing',
  cvd = 'Any MCQ160B/C/D/E/F==1 Yes; all==2 No; otherwise Missing',
  diabetes = 'DIQ010 1 Yes,2 No; borderline3/refused7/unknown9 Missing',
  continuous = 'Sodium DR1TSODI mg, fat DR1TTFAT g, TC LBXTC mg/dL, creatinine LBXSCR mg/dL, TG LBXSTR mg/dL, HbA1c LBXGH %, HDL LBDHDD mg/dL',
  missing = 'Categorical Missing indicator levels. Continuous missing: primary-domain median plus indicator; explicit analyst assumption.',
  table2 = 'M1 age/sex/race/education; M2 adds BMI/sleep/alcohol/activity/CVD/diabetes/sodium/fat (no smoking); M3 adds five laboratory variables. The interaction model includes smoking main effects explicitly.',
  table3 = 'A only; strata age30-44 and45+ (no additional overall column). M1 sex/race/education, no age; M2 adds BMI/sleep/alcohol/activity/smoking, no CVD/diabetes/diet; M3 adds five laboratory variables.',
  supplements = paste('A MEC weights only. SupI domain core AND diagnosed_or_treated==0, outcome measured_htn.',
    'SupII domain core AND (diagnosed_or_treated==1 OR core hypertension==0), outcome diagnosed_or_treated.',
    'Both retain the same primary nonhypertensive controls. Domain rules inferred from supplement counts are candidate reconstruction rules, not proved author implementation.',
    'Overall only, without supplemental smoking strata. M1 age/sex/race/education; M2 adds only BMI/sleep/alcohol/activity; M3 adds five laboratories.'),
  trend = 'Oral categories assigned ordinal scores0,1,2,3; separate adjusted survey Wald t trend model.',
  interaction = 'Joint survey Wald F on M3 exposure-by-smoking and exposure-by-age-group terms, not product term p alone.',
  inference = 'Primary t CI/p uses model residual survey df. Normal z CI/p reported separately for comparison, without selecting by article match.',
  complete_case = 'Optional common Model3 complete-case sensitivity changes the sample; both exposures use exactly the same subset.',
  fit_storage = paste('Lean RDS artifacts contain coefficients, vcov, formula text, family/link, n, rank,',
    'degrees of freedom, contrasts/xlevels, convergence and source data version. Full survey fit objects are not serialized.',
    'Use raw/derived master, source code and survey design metadata to reconstruct complete fits.'))

extension_models <- function(family = 'table2', smoking_stratum = FALSE) {
  base <- if (family == 'table3') c('sex', 'race', 'education') else c('age', 'sex', 'race', 'education')
  added <- c('bmi_category', 'sleep_category', 'alcohol_category', 'activity_category')
  if (family == 'table3') added <- c(added, 'smoking')
  if (smoking_stratum) added <- setdiff(added, 'smoking')
  if (family == 'table2') added <- c(added, 'cvd_category', 'diabetes_category',
                                    'sodium_filled', 'sodium_missing', 'fat_filled', 'fat_missing')
  labs <- unlist(lapply(c('total_cholesterol', 'creatinine', 'triglycerides_biopro', 'hba1c', 'hdl'),
                         function(name) paste0(name, c('_filled', '_missing'))), use.names = FALSE)
  list(Model1 = base, Model2 = c(base, added), Model3 = c(base, added, labs))
}
build_candidate <- function(ctx, master, candidate) {
  eligible <- if (candidate == 'A') master$mec_design_eligible else master$diet_design_eligible
  population <- master[eligible, , drop = FALSE]
  population$pooled_candidate_weight <- if (candidate == 'A') population$mec_weight else population$diet_weight
  population$candidate_domain <- if (candidate == 'A') population$analysis_domain else population$dietary_sensitivity_domain
  population$SDMVPSU <- as.numeric(population$SDMVPSU)
  population$SDMVSTRA <- as.numeric(population$SDMVSTRA)
  full <- survey::svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA,
                            weights = ~pooled_candidate_weight, data = population, nest = TRUE)
  domain <- subset(full, candidate_domain)
  assert_invariant(ctx, paste0(candidate, '_build_full_then_subset'),
                   nrow(full$variables) == sum(eligible) &&
                     nrow(domain$variables) == sum(population$candidate_domain))
  assert_invariant(ctx, paste0(candidate, '_has_five_cycles'), length(unique(full$variables$cycle)) == 5L)
  assert_invariant(ctx, paste0(candidate, '_nonempty'), nrow(domain$variables) > 0)
  list(full = full, domain = domain, metadata = list(candidate = candidate,
    label = if (candidate == 'A') 'MEC-weight candidate' else 'Dietary-weight sensitivity',
    full_n = nrow(population), domain_n = nrow(domain$variables),
    full_df = survey::degf(full), domain_df = survey::degf(domain)))
}

fit_extended <- function(ctx, design, exposure, covariates, outcome,
                         family, subgroup, model_name, candidate) {
  # An absent Missing level or indicator can be redundant; R's aliased terms are
  # retained as NA and recorded. No data rows are dropped for covariate missingness.
  label <- paste(candidate, family, subgroup, model_name, exposure, outcome, sep = '_')
  start_elapsed <- proc.time()[['elapsed']]
  log_event(ctx, 'FIT START', label, 'n', nrow(design$variables), 'covariates', length(covariates))
  result <- fit_one_model(design, exposure, covariates, outcome)
  result$metadata$fit_elapsed_seconds <- proc.time()[['elapsed']] - start_elapsed
  log_event(ctx, 'FIT END', label, 'elapsed_seconds', round(result$metadata$fit_elapsed_seconds, 3),
            'residual_df', result$metadata$residual_df)
  result$coefficients$z_ci_low <- exp(result$coefficients$log_odds - stats::qnorm(.975) * result$coefficients$se)
  result$coefficients$z_ci_high <- exp(result$coefficients$log_odds + stats::qnorm(.975) * result$coefficients$se)
  result$coefficients$z_p_value <- 2 * stats::pnorm(abs(result$coefficients$t_statistic), lower.tail = FALSE)
  for (name in c('candidate', 'family', 'subgroup', 'model', 'exposure', 'outcome')) {
    value <- switch(name, candidate = candidate, family = family, subgroup = subgroup,
                    model = model_name, exposure = exposure, outcome = outcome)
    result$coefficients[[name]] <- value
    result$metadata[[name]] <- value
  }
  result$metadata$aliased_coefficients <- result$coefficients$term[is.na(result$coefficients$log_odds)]
  assert_invariant(ctx, paste(candidate, family, subgroup, model_name, exposure, outcome, 'converged', sep = '_'),
                   result$metadata$converged)
  assert_invariant(ctx, paste(candidate, family, subgroup, model_name, exposure, outcome, 'same_n', sep = '_'),
                   result$metadata$n == nrow(design$variables))
  name <- paste(candidate, family, subgroup, model_name, exposure, outcome, sep = '_')
  safe_name <- gsub('[^A-Za-z0-9_.-]', '_', name)
  # Never serialize the full fit: it contains the full survey design/master.
  # The lean artifact keeps the quantities needed to reproduce inference.
  result$metadata$storage <- 'lean'
  store_start <- proc.time()[['elapsed']]
  lean <- list(storage = 'lean', artifact_version = 1L,
    coefficients = stats::coef(result$fit), vcov = stats::vcov(result$fit),
    formula = result$metadata$formula, family = 'quasibinomial', link = 'logit',
    n = result$metadata$n, rank = result$metadata$rank,
    design_df = result$metadata$design_df, residual_df = result$metadata$residual_df,
    converged = result$metadata$converged, contrasts = result$fit$contrasts,
    xlevels = result$fit$xlevels, aliased_coefficients = result$metadata$aliased_coefficients,
    data_version = ctx$data_version, input_run = ctx$options$input_run,
    fit_elapsed_seconds = result$metadata$fit_elapsed_seconds,
    metadata = result$metadata)
  lean_path <- file.path(ctx$run_dir, 'models', paste0(safe_name, '_lean.rds'))
  saveRDS(lean, lean_path)
  capture.output(summary(result$fit, df.resid = result$metadata$residual_df),
                 file = file.path(ctx$run_dir, 'models', paste0(safe_name, '.txt')))
  result$metadata$storage_elapsed_seconds <- proc.time()[['elapsed']] - store_start
  result$metadata$lean_bytes <- file.info(lean_path)$size
  log_event(ctx, 'MODEL STORED', label, 'storage', 'lean', 'bytes', result$metadata$lean_bytes,
            'elapsed_seconds', round(result$metadata$storage_elapsed_seconds, 3))
  result
}

model_suite <- function(ctx, design, candidate, family, outcome = 'hypertension_code') {
  if (startsWith(family, 'supplement')) {
    if (candidate != 'A') stop('Supplements apply only to the MEC-weight candidate A.')
    diagnosed <- design$variables$diagnosed_or_treated_htn
    keep <- if (family == 'supplement_measured') !is.na(diagnosed) & diagnosed == 0L else
      (!is.na(diagnosed) & diagnosed == 1L) | design$variables$hypertension_code == 0L
    design <- design[keep, ]
  }
  groups <- if (family == 'table3') c('30-44', '45+') else if (startsWith(family, 'supplement')) 'Overall' else c('Overall', 'No', 'Yes')
  rows <- list(); metadata <- list(); trends <- list(); counts <- list()
  for (group in groups) {
    d <- design
    if (group != 'Overall') {
      keep <- if (family == 'table3') d$variables$age_group == group else d$variables$smoking == group
      d <- d[!is.na(keep) & keep, ]
    }
    observed <- !is.na(d$variables[[outcome]])
    d <- d[observed, ]
    if (!nrow(d$variables) || length(unique(d$variables[[outcome]])) < 2L)
      stop('Insufficient outcome variation: ', candidate, '/', family, '/', group, '/', outcome)
    registry_family <- if (family == 'table3') 'table3' else if (startsWith(family, 'supplement')) 'supplement' else 'table2'
    registry <- extension_models(registry_family,
                                 smoking_stratum = family != 'table3' && group != 'Overall')
    for (model_name in names(registry)) {
      covariates <- registry[[model_name]]
      for (exposure in c('periodontal', 'oral_health')) {
        log_event(ctx, 'Model', candidate, family, group, model_name, exposure, outcome)
        result <- fit_extended(ctx, d, exposure, covariates, outcome, family, group, model_name, candidate)
        rows[[length(rows) + 1L]] <- result$coefficients
        metadata[[paste(group, model_name, exposure, sep = '_')]] <- result$metadata
        counts[[length(counts) + 1L]] <- data.frame(candidate = candidate, family = family,
          outcome = outcome, subgroup = group, model = model_name, exposure = exposure,
          n = nrow(d$variables), cases_n = sum(d$variables[[outcome]] == 1L),
          controls_n = sum(d$variables[[outcome]] == 0L), design_df = survey::degf(d),
          model_residual_df = result$metadata$residual_df, formula = result$metadata$formula)
      }
      trend <- fit_extended(ctx, d, 'oral_score', covariates, outcome,
                            family, group, model_name, candidate)
      trend_row <- trend$coefficients[trend$coefficients$term == 'oral_score', , drop = FALSE]
      trend_row$candidate <- candidate; trend_row$family <- family; trend_row$outcome <- outcome
      trend_row$subgroup <- group; trend_row$model <- model_name
      trend_row$score_rule <- 'Excellent/Very good0;Good1;Fair2;Poor3'
      trend_row$z_ci_low <- exp(trend_row$log_odds - stats::qnorm(.975) * trend_row$se)
      trend_row$z_ci_high <- exp(trend_row$log_odds + stats::qnorm(.975) * trend_row$se)
      trend_row$z_p_value <- 2 * stats::pnorm(abs(trend_row$t_statistic), lower.tail = FALSE)
      trends[[length(trends) + 1L]] <- trend_row
      metadata[[paste(group, model_name, 'oral_trend', sep = '_')]] <- trend$metadata
    }
  }
  list(coefficients = do.call(rbind, rows), metadata = metadata,
       trends = do.call(rbind, trends), counts = do.call(rbind, counts))
}

interaction_suite <- function(ctx, design, candidate) {
  rows <- list(); metadata <- list(); coefficients <- list()
  modifiers <- if (candidate == 'A') c('smoking', 'age_group') else 'smoking'
  for (modifier in modifiers) for (exposure in c('periodontal', 'oral_health')) {
    family <- if (modifier == 'smoking') 'table2' else 'table3'
    covariates <- setdiff(extension_models(family)$Model3, modifier)
    formula <- stats::reformulate(c(paste0(exposure, '*', modifier), covariates),
                                  response = 'hypertension_code')
    label <- paste(candidate, 'interaction', exposure, modifier, sep = '_')
    fit_start <- proc.time()[['elapsed']]
    log_event(ctx, 'FIT START', label, 'n', nrow(design$variables))
    fit <- survey::svyglm(formula, design, family = stats::quasibinomial())
    fit_elapsed <- proc.time()[['elapsed']] - fit_start
    log_event(ctx, 'FIT END', label, 'elapsed_seconds', round(fit_elapsed, 3))
    assert_invariant(ctx, paste(candidate, exposure, modifier, 'interaction_converged', sep = '_'), isTRUE(fit$converged))
    tested_term <- stats::as.formula(paste0('~', exposure, ':', modifier))
    test <- survey::regTermTest(fit, tested_term, method = 'Wald', df = fit$df.residual)
    rows[[length(rows) + 1L]] <- data.frame(candidate = candidate, exposure = exposure,
      modifier = modifier, model = 'Model3', statistic_F = as.numeric(test$Ftest),
      numerator_df = as.numeric(test$df), denominator_df = as.numeric(test$ddf),
      p_value = as.numeric(test$p), method = 'Joint survey Wald F',
      formula = paste(deparse(formula), collapse = ' '), n = nrow(stats::model.frame(fit)))
    metadata[[paste(exposure, modifier, sep = '_')]] <- list(formula = paste(deparse(formula), collapse = ' '),
      tested_term = paste(deparse(tested_term), collapse = ' '), n = nrow(stats::model.frame(fit)),
      residual_df = fit$df.residual, design_df = survey::degf(design),
      fit_elapsed_seconds = fit_elapsed, storage = 'lean')
    beta <- stats::coef(fit); se <- sqrt(diag(stats::vcov(fit)))
    coefficients[[length(coefficients) + 1L]] <- data.frame(candidate = candidate, exposure = exposure,
      modifier = modifier, term = names(beta), log_odds = as.numeric(beta), se = as.numeric(se),
      odds_ratio = exp(beta), ci_low = exp(beta - stats::qt(.975, fit$df.residual) * se),
      ci_high = exp(beta + stats::qt(.975, fit$df.residual) * se),
      p_value = 2 * stats::pt(abs(beta/se), fit$df.residual, lower.tail = FALSE))
    store_start <- proc.time()[['elapsed']]
    lean_path <- file.path(ctx$run_dir, 'models', paste0(label, '_lean.rds'))
    saveRDS(list(storage = 'lean', artifact_version = 1L, coefficients = beta,
      vcov = stats::vcov(fit), formula = paste(deparse(formula), collapse = ' '),
      family = 'quasibinomial', link = 'logit', n = nrow(stats::model.frame(fit)),
      design_df = survey::degf(design), residual_df = fit$df.residual,
      rank = fit$rank, converged = isTRUE(fit$converged), contrasts = fit$contrasts,
      xlevels = fit$xlevels, joint_wald = rows[[length(rows)]],
      data_version = ctx$data_version, input_run = ctx$options$input_run,
      fit_elapsed_seconds = fit_elapsed), lean_path)
    capture.output(summary(fit, df.resid = fit$df.residual),
                   file = file.path(ctx$run_dir, 'models', paste0(label, '.txt')))
    log_event(ctx, 'MODEL STORED', label, 'storage', 'lean', 'bytes', file.info(lean_path)$size,
              'elapsed_seconds', round(proc.time()[['elapsed']] - store_start, 3))
  }
  list(tests = do.call(rbind, rows), metadata = metadata, coefficients = do.call(rbind, coefficients))
}

plot_extended_forest <- function(ctx, coefficients, candidate) {
  x <- coefficients[coefficients$candidate == candidate & coefficients$family == 'table2' &
    coefficients$subgroup == 'Overall' & coefficients$outcome == 'hypertension_code' &
    coefficients$is_exposure & is.finite(coefficients$ci_low) & coefficients$ci_low > 0, ]
  if (!nrow(x)) stop('No estimable forest data.')
  x <- x[order(x$exposure, x$term, x$model), ]
  grDevices::png(file.path(ctx$run_dir, 'figures', paste0(candidate, '_model1_3_forest.png')),
                 width = 1700, height = max(850, 72 * nrow(x)), res = 150)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 20, 4, 2))
  y <- rev(seq_len(nrow(x)))
  colors <- c(Model1 = '#2166AC', Model2 = '#7B3294', Model3 = '#B2182B')
  graphics::plot(x$odds_ratio, y, log = 'x', xlim = range(c(.9, 1.1, x$ci_low, x$ci_high)),
    ylim = c(.5, nrow(x) + .5), yaxt = 'n', pch = 19, col = colors[x$model],
    xlab = 'Odds ratio with survey residual-df 95% t CI', ylab = '',
    main = paste(candidate, 'candidate: hypertension as outcome'))
  graphics::segments(x$ci_low, y, x$ci_high, y, col = colors[x$model])
  graphics::abline(v = 1, col = '#777777', lty = 2)
  graphics::axis(2, at = y, labels = paste(x$model, x$exposure, x$term, sep = ': '), las = 2, cex.axis = .7)
}

extension_qa <- function(ctx, master, designs) {
  categorical <- c('bmi_category', 'sleep_category', 'alcohol_category', 'activity_category', 'cvd_category', 'diabetes_category')
  continuous <- c('bmi', 'sleep_hours', 'sodium', 'fat', 'total_cholesterol', 'creatinine',
                   'triglycerides_biopro', 'hba1c', 'hdl')
  rows <- list()
  for (candidate in names(designs)) {
    d <- designs[[candidate]]$domain
    for (variable in c(categorical, continuous)) {
      v <- d$variables[[variable]]
      rows[[length(rows) + 1L]] <- data.frame(candidate = candidate, variable = variable,
        domain_n = length(v), observed_n = sum(!is.na(v)), missing_n = sum(is.na(v)),
        missing_category_n = if (is.factor(v)) sum(v == 'Missing', na.rm = TRUE) else NA_integer_)
    }
    cats <- table1_categorical(ctx, d, c('periodontal', 'oral_health', 'smoking', 'sex', 'race', 'education', 'age_group', categorical))
    cats$candidate <- candidate
    cont <- table1_continuous(d, c('age', 'mean_sbp', 'mean_dbp', continuous))
    cont$candidate <- candidate
    write_csv(cats, file.path(ctx$run_dir, 'tables', paste0(candidate, '_table1_categorical.csv')))
    write_csv(cont, file.path(ctx$run_dir, 'tables', paste0(candidate, '_table1_continuous.csv')))
    write_csv(continuous_tests(d, c('age', 'mean_sbp', 'mean_dbp', continuous)),
              file.path(ctx$run_dir, 'tables', paste0(candidate, '_table1_continuous_tests.csv')))
    # Unobserved levels are dropped by categorical_tests before its survey test.
    tested <- categorical_tests(d, c('periodontal', 'oral_health', 'smoking', 'sex', 'race', 'education', 'age_group', categorical))
    write_csv(tested$tests, file.path(ctx$run_dir, 'tables', paste0(candidate, '_table1_categorical_tests.csv')))
  }
  write_csv(do.call(rbind, rows), file.path(ctx$run_dir, 'tables', 'covariate_missingness.csv'))
  codes <- c('SLD010H', 'SLD012', 'ALQ101', 'ALQ110', 'ALQ111', 'ALQ120Q', 'ALQ120U', 'ALQ121', 'ALQ130', 'DIQ010', 'DR1DRSTZ')
  raw_codes <- do.call(rbind, lapply(codes, function(variable) {
    result <- list()
    for (cycle in unique(master$cycle)) {
      tab <- table(master[[variable]][master$cycle == cycle], useNA = 'always')
      result[[length(result) + 1L]] <- data.frame(cycle = cycle, variable = variable,
        raw_code = names(tab), n = as.integer(tab))
    }
    do.call(rbind, result)
  }))
  write_csv(raw_codes, file.path(ctx$run_dir, 'tables', 'addon_raw_code_counts.csv'))
  diabetes_raw <- numeric_col(master, 'DIQ010')
  diabetes_groups <- c('Yes', 'No', 'Borderline3', 'Refused7', 'Unknown9', 'Absent', 'Other')
  diabetes_status <- rep('Other', nrow(master))
  diabetes_status[is.na(diabetes_raw)] <- 'Absent'
  for (code in c(1, 2, 3, 7, 9)) diabetes_status[which(diabetes_raw == code)] <-
    switch(as.character(code), '1' = 'Yes', '2' = 'No', '3' = 'Borderline3',
           '7' = 'Refused7', '9' = 'Unknown9')
  diabetes_qa <- do.call(rbind, lapply(c('All DEMO', 'Primary A'), function(population) {
    keep <- if (population == 'All DEMO') rep(TRUE, nrow(master)) else master$analysis_domain
    data.frame(population = population, status = diabetes_groups,
      n = as.integer(table(factor(diabetes_status[keep], levels = diabetes_groups))))
  }))
  write_csv(diabetes_qa, file.path(ctx$run_dir, 'tables', 'diabetes_borderline_refused_unknown_counts.csv'))
  sleep_qa <- do.call(rbind, lapply(unique(master$cycle), function(cycle) {
    keep <- master$cycle == cycle
    raw <- if (unique(master$cycle_start[keep]) <= 2013) numeric_col(master, 'SLD010H')[keep] else numeric_col(master, 'SLD012')[keep]
    valid <- is.finite(raw) & raw >= 0 & raw <= 24
    data.frame(cycle = cycle, raw_field = if (unique(master$cycle_start[keep]) <= 2013) 'SLD010H' else 'SLD012',
      all_n = sum(keep), valid_n = sum(valid), fractional_valid_n = sum(valid & abs(raw - round(raw)) > 1e-12, na.rm = TRUE),
      derived_missing_n = sum(is.na(master$sleep_hours[keep])))
  }))
  write_csv(sleep_qa, file.path(ctx$run_dir, 'tables', 'sleep_mapping_counts.csv'))
  for (name in c('sodium', 'fat', 'total_cholesterol', 'creatinine', 'triglycerides_biopro', 'hba1c', 'hdl')) {
    assert_invariant(ctx, paste0('filled_', name, '_finite'), all(is.finite(master[[paste0(name, '_filled')]])))
    assert_invariant(ctx, paste0('missing_indicator_', name, '_matches_raw'),
      identical(master[[paste0(name, '_missing')]], as.integer(is.na(master[[name]]))))
  }
  list(core_n = sum(master$analysis_domain), A_n = sum(master$analysis_domain),
    B_n = sum(master$dietary_sensitivity_domain), B_excluded_from_A = sum(master$analysis_domain & !master$dietary_sensitivity_domain),
    lab_candidate = 'BIOPRO LBXSTR; no fasting restriction', dietary_week_denominator = 365/7,
    alcohol_lifetime_proxy_n = sum(master$alcohol_lifetime_lt12_proxy & master$analysis_domain, na.rm = TRUE))
}

check_addon_fixture <- function(ctx) {
  x <- data.frame(cycle_start = c(2009, 2009, 2017, 2017, 2017, 2015),
    ALQ120Q = c(0, NA, NA, NA, NA, 1), ALQ120U = c(NA, NA, NA, NA, NA, 3),
    ALQ130 = c(NA, NA, 10, NA, 777, 15), ALQ101 = c(1, 2, NA, NA, NA, 1),
    ALQ110 = c(NA, 2, NA, NA, NA, NA), ALQ111 = c(NA, NA, 1, 1, 1, NA),
    ALQ121 = c(NA, NA, 8, 0, 99, NA))
  y <- derive_alcohol(x)
  assert_invariant(ctx, 'alcohol_fixture_zero_unit_amount_missing_is_none',
                   identical(as.character(y$category[c(1, 4)]), c('No drinks', 'No drinks')))
  assert_invariant(ctx, 'alcohol_fixture_lifetime_lt12_proxy_is_none',
                   identical(as.character(y$category[[2L]]), 'No drinks'))
  assert_invariant(ctx, 'alcohol_fixture_J_7to11_midpoint9',
                   abs(y$weekly_drinks[[3L]] - 9 / (365/7) * 10) < 1e-12)
  assert_invariant(ctx, 'alcohol_fixture_special_codes_missing',
                   identical(as.character(y$category[[5L]]), 'Missing'))
}

exposure_rows_with_references <- function(coefficients) {
  x <- coefficients[coefficients$is_exposure, , drop = FALSE]
  x$is_reference <- FALSE
  key_cols <- c('candidate', 'family', 'outcome', 'subgroup', 'model', 'exposure')
  key <- do.call(paste, c(x[, key_cols, drop = FALSE], sep = '|'))
  first <- x[!duplicated(key), , drop = FALSE]
  if (!nrow(first)) return(x)
  first$term <- ifelse(first$exposure == 'periodontal', 'periodontalNo', 'oral_healthExcellent/Very good')
  first$log_odds <- 0; first$se <- NA_real_; first$odds_ratio <- 1
  first$ci_low <- NA_real_; first$ci_high <- NA_real_; first$t_statistic <- NA_real_
  first$p_value <- NA_real_; first$z_ci_low <- NA_real_; first$z_ci_high <- NA_real_; first$z_p_value <- NA_real_
  first$is_reference <- TRUE
  first$ci_method <- 'Reference category; fixed odds ratio 1'
  rbind(first, x)
}

optional_complete_case <- function(ctx, design, candidate) {
  cats <- c('sex', 'race', 'education', 'bmi_category', 'sleep_category', 'alcohol_category',
             'activity_category', 'smoking', 'cvd_category', 'diabetes_category')
  raw <- c('age', 'sodium', 'fat', 'total_cholesterol', 'creatinine', 'triglycerides_biopro', 'hba1c', 'hdl')
  keep <- stats::complete.cases(design$variables[, c(cats, raw)])
  for (name in cats) keep <- keep & as.character(design$variables[[name]]) != 'Missing'
  d <- design[keep, ]
  if (!nrow(d$variables)) stop('Common Model3 complete-case sensitivity has no records.')
  cov <- extension_models('table2')$Model3
  rows <- lapply(c('periodontal', 'oral_health'), function(exposure)
    fit_extended(ctx, d, exposure, cov, 'hypertension_code', 'common_complete_case',
                 'Overall', 'Model3', candidate)$coefficients)
  coefficients <- do.call(rbind, rows)
  write_csv(coefficients, file.path(ctx$run_dir, 'tables', paste0(candidate, '_common_complete_case_coefficients.csv')))
  list(candidate = candidate, original_domain_n = nrow(design$variables), common_complete_case_n = nrow(d$variables),
       excluded_n = nrow(design$variables) - nrow(d$variables),
       interpretation = 'Both exposures use the same changed sample; optional sensitivity, not primary model.')
}

run_extension <- function(ctx) {
  options(timeout = 180, survey.lonely.psu = 'fail', survey.adjust.domain.lonely = FALSE)
  start <- utc_now()
  write_json(list(status = 'running', started_utc = start, options = ctx$options), file.path(ctx$run_dir, 'status.json'))
  write_json(extension_definitions(), file.path(ctx$run_dir, 'definitions.json'))
  log_event(ctx, 'Start R-EXT-002 plan rev1.4', ctx$options$stage, ctx$options$candidate)
  check_addon_fixture(ctx)
  input <- load_input_run(ctx)
  input_dir <- file.path(ctx$analysis_dir, 'runs', ctx$options$input_run)
  upstream <- list(run_id = ctx$options$input_run,
    master_sha256 = hash_file(file.path(input_dir, 'derived', 'master.rds')),
    artifact_manifest_sha256 = hash_file(file.path(input_dir, 'artifact_hashes.csv')),
    report_sha256 = hash_file(file.path(input_dir, 'report.json')),
    data_version = input$data_version, master_manifest_verified = TRUE)
  write_json(upstream, file.path(ctx$run_dir, 'upstream_input.json'))
  file.copy(ctx$core_source_path, file.path(ctx$run_dir, 'core_script_snapshot.R'), overwrite = FALSE)
  assert_invariant(ctx, 'core_script_snapshot_matches_loaded_source',
                   identical(hash_file(file.path(ctx$run_dir, 'core_script_snapshot.R')), ctx$core_source_sha256))
  added <- acquire_addons(ctx, input)
  ctx$data_version <- added$data_version
  master <- derive_addon_covariates(ctx, added$master)
  check_derivation_fixture(ctx)
  qa_core <- write_qa(ctx, master)
  candidates <- if (ctx$options$candidate == 'both') c('A', 'B') else ctx$options$candidate
  designs <- setNames(lapply(candidates, function(candidate) build_candidate(ctx, master, candidate)), candidates)
  qa <- extension_qa(ctx, master, designs)
  saveRDS(master, file.path(ctx$run_dir, 'derived', 'master.rds'))
  write_csv(master, file.path(ctx$run_dir, 'derived', 'master.csv'))
  all_coefficients <- list(); all_counts <- list(); all_trends <- list(); all_metadata <- list()
  all_interactions <- list(); all_interaction_coefficients <- list(); cc <- list()
  if (ctx$options$stage == 'model') {
    for (candidate in candidates) {
      d <- designs[[candidate]]$domain
      specs <- list(table2 = 'hypertension_code', table3 = 'hypertension_code',
                    supplement_measured = 'measured_htn', supplement_diagnosed_treated = 'diagnosed_or_treated_htn')
      if (candidate == 'B') specs <- specs['table2']
      for (family in names(specs)) {
        if (candidate == 'B' && startsWith(family, 'supplement')) next
        result <- model_suite(ctx, d, candidate, family, specs[[family]])
        all_coefficients[[length(all_coefficients) + 1L]] <- result$coefficients
        all_counts[[length(all_counts) + 1L]] <- result$counts
        all_trends[[length(all_trends) + 1L]] <- result$trends
        all_metadata[[paste(candidate, family, sep = '_')]] <- result$metadata
        write_csv(exposure_rows_with_references(result$coefficients),
                  file.path(ctx$run_dir, 'tables', paste0(candidate, '_', family, '_exposure_or.csv')))
      }
      interaction <- interaction_suite(ctx, d, candidate)
      all_interactions[[length(all_interactions) + 1L]] <- interaction$tests
      all_interaction_coefficients[[length(all_interaction_coefficients) + 1L]] <- interaction$coefficients
      all_metadata[[paste0(candidate, '_interactions')]] <- interaction$metadata
      if (ctx$options$complete_case) cc[[candidate]] <- optional_complete_case(ctx, d, candidate)
    }
    coefficients <- do.call(rbind, all_coefficients)
    write_csv(coefficients, file.path(ctx$run_dir, 'tables', 'all_model_coefficients.csv'))
    write_csv(do.call(rbind, all_counts), file.path(ctx$run_dir, 'tables', 'model_sample_counts_formulas.csv'))
    write_csv(do.call(rbind, all_trends), file.path(ctx$run_dir, 'tables', 'oral_trend_tests.csv'))
    write_csv(do.call(rbind, all_interactions), file.path(ctx$run_dir, 'tables', 'interaction_joint_wald.csv'))
    write_csv(do.call(rbind, all_interaction_coefficients), file.path(ctx$run_dir, 'tables', 'interaction_coefficients.csv'))
    write_json(all_metadata, file.path(ctx$run_dir, 'models', 'model_metadata.json'))
    for (candidate in candidates) plot_extended_forest(ctx, coefficients, candidate)
  }
  file_arg <- grep('^--file=', commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg)) file.copy(sub('^--file=', '', file_arg[[1L]]), file.path(ctx$run_dir, 'executed_script.R'), overwrite = FALSE)
  write_json(list(task = 'R-EXT-002', revision = '1.4', data_version = added$data_version,
    run_id = ctx$options$run_id, stage = ctx$options$stage, started_utc = start, completed_utc = utc_now(),
    input_run = ctx$options$input_run, upstream_input = upstream,
    candidates = lapply(designs, function(x) x$metadata),
    qa_core = qa_core, qa_extension = qa, common_complete_case = cc,
    warnings_n = nrow(ctx$warnings), invariants_passed = sum(ctx$invariants$passed),
    target_comparison = 'Published results visible during source review; no target-based optimization; discrepancies must be reported.',
    inference = 'Primary t residual-df CI/p; separately labelled normal z sensitivity CI/p.'),
    file.path(ctx$run_dir, 'report.json'))
  write_json(list(status = 'success', completed_utc = utc_now(), revision = '1.4', data_version = added$data_version),
             file.path(ctx$run_dir, 'status.json'))
  log_event(ctx, 'Extension success', ctx$run_dir)
  finalize_artifacts(ctx)
}

extension_main <- function() {
  opts <- extension_cli(commandArgs(trailingOnly = TRUE))
  core_path <- file.path(opts$root, 'analysis', 'src', 'run_analysis.R')
  if (!file.exists(core_path)) stop('Promote the core script to analysis/src/run_analysis.R first.')
  source(core_path, local = .GlobalEnv, encoding = 'UTF-8')
  ctx <- new_context(opts)
  ctx$core_source_path <- core_path
  ctx$core_source_sha256 <- hash_file(core_path)
  tryCatch(withCallingHandlers(run_extension(ctx), warning = function(w) {
    ctx$warnings <- rbind(ctx$warnings, data.frame(time_utc = utc_now(), message = conditionMessage(w),
      call = paste(deparse(conditionCall(w)), collapse = ' ')))
    log_event(ctx, 'WARNING:', conditionMessage(w)); invokeRestart('muffleWarning')
  }), error = function(e) {
    log_event(ctx, 'FAILED:', conditionMessage(e))
    write_json(list(status = 'failed', failed_utc = utc_now(), error = conditionMessage(e)), file.path(ctx$run_dir, 'status.json'))
    try(finalize_artifacts(ctx), silent = TRUE)
    stop(e)
  })
}

if (sys.nframe() == 0L) extension_main()
