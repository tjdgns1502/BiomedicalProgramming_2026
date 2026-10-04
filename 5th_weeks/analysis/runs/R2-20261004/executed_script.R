Sys.setlocale('LC_ALL', 'English_United States.utf8')
# R-CAT-001, revision 1.1. Public NHANES candidate reconstruction.
# No package installation is performed by this script.
# Usage from the project root:
# Rscript analysis/src/run_analysis.R . RUN_ID --stage=all
# Rscript analysis/src/run_analysis.R . RUN_ID --stage=test
# Rscript analysis/src/run_analysis.R . NEW_RUN_ID --stage=model --input-run=TEST_RUN_ID
# Stages always create a NEW output run. Cached raw files are never overwritten.
# test: acquire/derive/check/descriptive analysis, without logistic models.
# model: acquire/derive/check/fit; --input-run reuses a tested master instead.
# all: complete candidate analysis. Results are not calibrated to article targets.
# Exposure audit: published Abstract/Results values were visible during source
# documentation review; the implementation is not claimed to be blind.

parse_cli <- function(args) {
  positional <- args[!startsWith(args, '--')]
  named <- args[startsWith(args, '--')]
  opts <- list(root = if (length(positional)) positional[[1L]] else '.',
               run_id = if (length(positional) >= 2L) positional[[2L]] else
                 format(Sys.time(), '%Y%m%dT%H%M%S'),
               stage = 'all', input_run = NULL)
  if (length(positional) > 2L) stop('At most root and run_id are positional arguments.')
  for (arg in named) {
    pieces <- strsplit(sub('^--', '', arg), '=', fixed = TRUE)[[1L]]
    if (length(pieces) != 2L || !pieces[[1L]] %in% c('stage', 'input-run'))
      stop('Supported options: --stage=all|test|model and --input-run=ID.')
    key <- gsub('-', '_', pieces[[1L]], fixed = TRUE)
    opts[[key]] <- pieces[[2L]]
  }
  if (!opts$stage %in% c('all', 'test', 'model')) stop('Invalid stage.')
  for (id in c(opts$run_id, opts$input_run))
    if (!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$', id) || id %in% c('.', '..'))
      stop('Run IDs must be safe ASCII directory names, at most 96 characters.')
  if (!is.null(opts$input_run) && opts$stage != 'model')
    stop('--input-run is supported only with --stage=model.')
  opts$root <- normalizePath(opts$root, winslash = '/', mustWork = TRUE)
  opts
}

new_context <- function(opts) {
  analysis_dir <- file.path(opts$root, 'analysis')
  lib_dir <- file.path(analysis_dir, 'r-library')
  if (dir.exists(lib_dir)) .libPaths(c(lib_dir, .libPaths()))
  required <- c('survey', 'haven', 'jsonlite', 'digest')
  absent <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(absent)) stop('Install required packages into analysis/r-library first: ',
                           paste(absent, collapse = ', '))
  run_dir <- file.path(analysis_dir, 'runs', opts$run_id)
  if (file.exists(run_dir)) stop('Run already exists; refusing to overwrite: ', run_dir)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(run_dir)) stop('Could not create run directory: ', run_dir)
  ctx <- new.env(parent = emptyenv())
  ctx$options <- opts
  ctx$analysis_dir <- analysis_dir
  ctx$run_dir <- run_dir
  ctx$raw_dir <- file.path(analysis_dir, 'data', 'raw', 'nhanes')
  ctx$source_dir <- file.path(analysis_dir, 'sources', 'cache', 'codebooks')
  ctx$warnings <- data.frame(time_utc = character(), message = character(),
                              call = character(), stringsAsFactors = FALSE)
  ctx$invariants <- data.frame(name = character(), passed = logical(), detail = character(),
                                stringsAsFactors = FALSE)
  for (dir in c(ctx$raw_dir, ctx$source_dir,
                file.path(run_dir, c('derived', 'tables', 'figures', 'models', 'logs'))))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ctx$log_file <- file.path(run_dir, 'logs', 'analysis.log')
  ctx
}

utc_now <- function() format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
log_event <- function(ctx, ...) {
  line <- paste(utc_now(), paste(..., collapse = ' '))
  cat(line, '\n', file = ctx$log_file, append = TRUE)
  message(line)
}
write_csv <- function(x, path) utils::write.csv(x, path, row.names = FALSE, na = '')
write_json <- function(x, path) jsonlite::write_json(
  x, path, pretty = TRUE, auto_unbox = TRUE, null = 'null', na = 'null', digits = 16)
hash_file <- function(path) digest::digest(file = path, algo = 'sha256', serialize = FALSE)
assert_invariant <- function(ctx, name, condition, detail = '') {
  ok <- length(condition) == 1L && !is.na(condition) && isTRUE(condition)
  ctx$invariants <- rbind(ctx$invariants,
                         data.frame(name = name, passed = ok, detail = as.character(detail)))
  if (!ok) stop('Invariant failed: ', name, ' ', detail)
  invisible(ok)
}
numeric_col <- function(x, name, default = NA_real_) {
  if (!name %in% names(x)) return(rep(default, nrow(x)))
  as.numeric(x[[name]])
}
binary_code <- function(x) {
  out <- rep(NA_integer_, length(x))
  out[which(x == 1)] <- 1L
  out[which(x == 2)] <- 0L
  out
}
label_binary <- function(x) factor(ifelse(is.na(x), NA_character_,
                                          ifelse(x == 1L, 'Yes', 'No')),
                                    levels = c('No', 'Yes'))
missing_factor <- function(x, codes, labels, reference) {
  out <- rep('Missing', length(x))
  for (i in seq_along(codes)) out[which(x == codes[[i]])] <- labels[[i]]
  factor(out, levels = c(reference, setdiff(labels, reference), 'Missing'))
}

validate_xpt <- function(path) {
  if (!file.exists(path) || file.info(path)$size < 240L) stop('Empty/short XPT: ', path)
  con <- file(path, open = 'rb')
  on.exit(close(con), add = TRUE)
  # SAS metadata beyond the first 80-byte library header may contain NUL bytes.
  # Inspect only the ASCII library header; never decode binary metadata as text.
  header_raw <- readBin(con, what = 'raw', n = 80L)
  header <- rawToChar(header_raw[header_raw != as.raw(0)])
  if (!grepl('HEADER RECORD', header, fixed = TRUE) ||
      !grepl('LIBRARY', header, fixed = TRUE)) stop('Invalid SAS transport header: ', path)
  dat <- haven::read_xpt(path)
  if (!'SEQN' %in% names(dat)) stop('XPT has no SEQN: ', path)
  key <- as.numeric(dat$SEQN)
  if (anyNA(key) || anyDuplicated(key)) stop('Missing/duplicated SEQN in XPT: ', path)
  dat
}
validate_codebook <- function(path) {
  if (!file.exists(path) || file.info(path)$size < 100L) stop('Empty codebook: ', path)
  html <- paste(readLines(path, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
  if (!grepl('<html', html, ignore.case = TRUE) ||
      !grepl('SEQN', html, fixed = TRUE) || grepl('Page Not Found', html, fixed = TRUE))
    stop('Unexpected codebook HTML: ', path)
  invisible(TRUE)
}
ensure_cache <- function(ctx, url, path, validator) {
  if (file.exists(path)) {
    result <- validator(path)
    log_event(ctx, 'Using validated immutable cache', basename(path))
    return(list(data = result, cache_status = 'existing', retrieved_utc = NA_character_))
  }
  for (attempt in seq_len(3L)) { # first attempt plus at most two retries
    temp <- tempfile(pattern = paste0(basename(path), '-'), tmpdir = dirname(path))
    error <- NULL
    result <- tryCatch({
      log_event(ctx, 'Downloading', url, 'attempt', attempt)
      status <- utils::download.file(url, temp, mode = 'wb', method = 'libcurl', quiet = TRUE)
      if (!identical(status, 0L)) stop('download.file returned status ', status)
      validator(temp)
    }, error = function(e) { error <<- conditionMessage(e); NULL })
    if (is.null(error)) {
      if (file.exists(path)) stop('Cache path appeared during download; refusing overwrite: ', path)
      if (!file.rename(temp, path)) stop('Could not atomically promote cache: ', path)
      return(list(data = result, cache_status = 'downloaded', retrieved_utc = utc_now()))
    }
    if (file.exists(temp)) unlink(temp)
    log_event(ctx, 'Download validation failed:', error)
  }
  stop('Download failed after initial attempt and two retries: ', url)
}

acquire_data <- function(ctx) {
  cycles <- data.frame(year = c(2009L, 2011L, 2013L, 2015L, 2017L),
                       suffix = c('F', 'G', 'H', 'I', 'J'))
  components <- c('DEMO', 'OHQ', 'BPQ', 'BPX', 'SMQ')
  blocks <- vector('list', nrow(cycles))
  manifests <- list()
  component_counts <- list()
  for (i in seq_len(nrow(cycles))) {
    year <- cycles$year[[i]]
    suffix <- cycles$suffix[[i]]
    cycle_label <- paste0(year, '-', year + 1L)
    parts <- list()
    for (component in components) {
      stem <- paste0(component, '_', suffix)
      base_url <- paste0('https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/',
                         year, '/DataFiles/', stem)
      for (kind in c('xpt', 'htm')) {
        path <- file.path(if (kind == 'xpt') ctx$raw_dir else ctx$source_dir,
                          paste0(stem, '.', kind))
        validator <- if (kind == 'xpt') validate_xpt else validate_codebook
        cached <- ensure_cache(ctx, paste0(base_url, '.', kind), path, validator)
        manifests[[length(manifests) + 1L]] <- data.frame(
          cycle = cycle_label, component = component, kind = kind,
          file = normalizePath(path, winslash = '/', mustWork = TRUE),
          url = paste0(base_url, '.', kind), bytes = file.info(path)$size,
          sha256 = hash_file(path), cache_status = cached$cache_status,
          retrieved_utc = cached$retrieved_utc, stringsAsFactors = FALSE)
        if (kind == 'xpt') parts[[component]] <- as.data.frame(cached$data)
      }
      component_counts[[length(component_counts) + 1L]] <- data.frame(
        cycle = cycle_label, component = component, n = nrow(parts[[component]]),
        unique_seqn = length(unique(parts[[component]]$SEQN)))
    }
    merged <- parts$DEMO
    merged$.demo_order <- seq_len(nrow(merged))
    for (component in setdiff(components, 'DEMO')) {
      duplicates <- intersect(setdiff(names(merged), 'SEQN'),
                              setdiff(names(parts[[component]]), 'SEQN'))
      if (length(duplicates)) stop('Unexpected overlapping fields: ', paste(duplicates, collapse = ', '))
      merged <- merge(merged, parts[[component]], by = 'SEQN', all.x = TRUE, sort = FALSE)
      assert_invariant(ctx, paste0('left_merge_rows_', suffix, '_', component),
                       nrow(merged) == nrow(parts$DEMO))
      assert_invariant(ctx, paste0('left_merge_unique_', suffix, '_', component),
                       !anyDuplicated(merged$SEQN))
    }
    merged <- merged[order(merged$.demo_order), , drop = FALSE]
    merged$.demo_order <- NULL
    merged$cycle <- cycle_label
    merged$cycle_start <- year
    merged$cycle_suffix <- suffix
    blocks[[i]] <- merged
  }
  union_names <- unique(unlist(lapply(blocks, names), use.names = FALSE))
  blocks <- lapply(blocks, function(x) {
    for (name in setdiff(union_names, names(x))) x[[name]] <- NA_real_
    x[, union_names, drop = FALSE]
  })
  master <- do.call(rbind, blocks)
  rownames(master) <- NULL
  manifest <- do.call(rbind, manifests)
  raw_manifest <- manifest[manifest$kind == 'xpt', , drop = FALSE]
  signature <- paste(paste(basename(raw_manifest$file), raw_manifest$sha256, sep = ':'),
                     collapse = '\n')
  data_version <- paste0('nhanes-2009-2018-', substr(
    digest::digest(signature, algo = 'sha256', serialize = FALSE), 1L, 20L))
  write_csv(manifest, file.path(ctx$run_dir, 'sources_manifest.csv'))
  write_csv(do.call(rbind, component_counts),
            file.path(ctx$run_dir, 'tables', 'component_counts.csv'))
  assert_invariant(ctx, 'all_five_cycles', length(unique(master$cycle)) == 5L)
  assert_invariant(ctx, 'all_25_raw_components', nrow(raw_manifest) == 25L)
  assert_invariant(ctx, 'cycle_seqn_unique',
                   !anyDuplicated(paste(master$cycle, master$SEQN, sep = ':')))
  list(master = master, data_version = data_version, manifest = manifest)
}

derive_records <- function(master) {
  required <- c('SEQN', 'RIDAGEYR', 'RIAGENDR', 'RIDRETH1', 'DMDEDUC2',
                'WTMEC2YR', 'SDMVPSU', 'SDMVSTRA', 'OHQ835', 'OHQ845',
                'SMQ020', 'BPQ020', 'BPQ040A', 'BPQ050A')
  missing <- setdiff(required, names(master))
  if (length(missing)) stop('Required variables absent: ', paste(missing, collapse = ', '))
  master$age <- numeric_col(master, 'RIDAGEYR')
  master$age[!is.finite(master$age) | master$age < 0] <- NA_real_
  master$periodontal_code <- binary_code(numeric_col(master, 'OHQ835'))
  master$periodontal <- label_binary(master$periodontal_code)
  oral_raw <- numeric_col(master, 'OHQ845')
  oral <- rep(NA_character_, nrow(master))
  oral[which(oral_raw %in% c(1, 2))] <- 'Excellent/Very good'
  oral[which(oral_raw == 3)] <- 'Good'
  oral[which(oral_raw == 4)] <- 'Fair'
  oral[which(oral_raw == 5)] <- 'Poor'
  master$oral_health <- factor(oral, levels = c('Excellent/Very good', 'Good', 'Fair', 'Poor'))
  master$oral_score <- as.integer(master$oral_health) - 1L
  master$smoking_code <- binary_code(numeric_col(master, 'SMQ020'))
  master$smoking <- label_binary(master$smoking_code)
  master$sex <- missing_factor(numeric_col(master, 'RIAGENDR'), c(1, 2),
                               c('Male', 'Female'), 'Male')
  master$race <- missing_factor(numeric_col(master, 'RIDRETH1'), 1:5,
    c('Mexican American', 'Other Hispanic', 'Non-Hispanic White',
      'Non-Hispanic Black', 'Other race including multiracial'), 'Non-Hispanic White')
  education_raw <- numeric_col(master, 'DMDEDUC2')
  education <- rep('Missing', nrow(master))
  education[which(education_raw %in% c(1, 2))] <- 'Less than high school'
  education[which(education_raw == 3)] <- 'High school'
  education[which(education_raw %in% c(4, 5))] <- 'More than high school'
  master$education <- factor(education,
    levels = c('More than high school', 'High school', 'Less than high school', 'Missing'))
  master$education_missing <- as.integer(education == 'Missing')
  # The Missing level is itself an indicator. Do not add the redundant indicator
  # to the same factor model. This hook also supports later missing indicators.
  bp_mean <- function(prefix, include_zero) {
    readings <- vapply(paste0(prefix, 1:4), function(name) numeric_col(master, name),
                       numeric(nrow(master)))
    valid <- is.finite(readings) & if (include_zero) readings >= 0 else readings > 0
    readings[!valid] <- NA_real_
    count <- rowSums(valid)
    means <- rowMeans(readings, na.rm = TRUE)
    means[count == 0L] <- NA_real_
    list(mean = means, count = count, zero_count = rowSums(valid & readings == 0, na.rm = TRUE))
  }
  sbp <- bp_mean('BPXSY', FALSE)
  dbp <- bp_mean('BPXDI', TRUE)
  master$mean_sbp <- sbp$mean
  master$mean_dbp <- dbp$mean
  master$n_valid_sbp <- sbp$count
  master$n_valid_dbp <- dbp$count
  master$n_zero_dbp <- dbp$zero_count
  master$bp_measured_complete <- master$n_valid_sbp >= 1L & master$n_valid_dbp >= 1L
  # SBP and DBP are averaged independently; unpaired valid readings are allowed.
  measured <- rep(NA_integer_, nrow(master))
  measured[which(master$bp_measured_complete)] <- as.integer(
    master$mean_sbp[master$bp_measured_complete] >= 140 |
      master$mean_dbp[master$bp_measured_complete] >= 90)
  master$measured_htn <- measured
  diagnosis <- binary_code(numeric_col(master, 'BPQ020'))
  prescribed <- binary_code(numeric_col(master, 'BPQ040A'))
  reported_med <- binary_code(numeric_col(master, 'BPQ050A'))
  medication <- reported_med
  structural_no <- is.na(reported_med) & ((!is.na(diagnosis) & diagnosis == 0L) |
                                          (!is.na(prescribed) & prescribed == 0L))
  medication[which(structural_no)] <- 0L
  master$diagnosis_htn <- diagnosis
  master$medication_htn <- medication
  master$medication_structural_no <- structural_no
  master$medication_conflict <- !is.na(reported_med) & reported_med == 1L &
    ((!is.na(diagnosis) & diagnosis == 0L) | (!is.na(prescribed) & prescribed == 0L))
  yes_evidence <- (!is.na(measured) & measured == 1L) |
    (!is.na(diagnosis) & diagnosis == 1L) | (!is.na(medication) & medication == 1L)
  no_evidence <- !is.na(measured) & measured == 0L &
    !is.na(diagnosis) & diagnosis == 0L & !is.na(medication) & medication == 0L
  hypertension <- rep(NA_integer_, nrow(master))
  hypertension[which(no_evidence)] <- 0L
  hypertension[which(yes_evidence)] <- 1L
  master$hypertension_code <- hypertension
  master$hypertension <- label_binary(hypertension)
  treated <- rep(NA_integer_, nrow(master))
  treated[which(!is.na(diagnosis) & diagnosis == 0L &
                  !is.na(medication) & medication == 0L)] <- 0L
  treated[which((!is.na(diagnosis) & diagnosis == 1L) |
                  (!is.na(medication) & medication == 1L))] <- 1L
  master$diagnosed_or_treated_htn <- treated
  master$mec_weight <- numeric_col(master, 'WTMEC2YR') / 5
  master$mec_design_eligible <- is.finite(master$mec_weight) & master$mec_weight > 0 &
    is.finite(numeric_col(master, 'SDMVPSU')) &
    is.finite(numeric_col(master, 'SDMVSTRA'))
  master$domain_age30 <- !is.na(master$age) & master$age >= 30
  master$domain_bp <- master$domain_age30 & master$bp_measured_complete
  master$domain_periodontal <- master$domain_bp & !is.na(master$periodontal)
  master$domain_oral <- master$domain_periodontal & !is.na(master$oral_health)
  master$domain_smoking <- master$domain_oral & !is.na(master$smoking)
  master$domain_htn <- master$domain_smoking & !is.na(master$hypertension_code)
  master$analysis_domain <- master$domain_htn & master$mec_design_eligible
  master$age_group <- factor(ifelse(is.na(master$age), NA_character_,
                                   ifelse(master$age < 45, '30-44', '45+')),
                             levels = c('30-44', '45+'))
  master
}

definition_document <- function() list(
  task = 'R-CAT-001', revision = '1.1', status = 'candidate reconstruction',
  paper = 'https://link.springer.com/article/10.1186/s12889-023-16012-z',
  purpose = 'Transparent reconstruction; published results were visible during source review and were not used for tuning.',
  cycles = c('2009-2010', '2011-2012', '2013-2014', '2015-2016', '2017-2018'),
  bp_average = list(readings = 'all available 1:4', sbp = 'finite > 0',
                    dbp = 'finite >= 0, including valid auscultatory zero',
                    minimum = 'at least one valid SBP AND at least one valid DBP',
                    pairing = 'means computed independently; paired readings are not required',
                    ambiguity = 'Paper does not specify zero, unpaired, or first-reading rules.'),
  periodontal = 'OHQ835: 1 Yes, 2 No, every other code Missing; self-reported gum disease',
  oral_health = 'OHQ845: 1/2 Excellent/Very good; 3 Good; 4 Fair; 5 Poor; else Missing',
  smoking = 'SMQ020: 1 Yes (ever smoked >=100 cigarettes), 2 No; else Missing',
  medication = paste('BPQ050A 1 Yes, 2 No. If 050A unavailable, BPQ020==2 OR',
                     'BPQ040A==2 implies structural No. Refused/unknown alone never implies No.'),
  hypertension = paste('Yes evidence: mean SBP>=140 OR mean DBP>=90 OR BPQ020==1 OR',
                      'BPQ050A==1. No: normal complete measured BP AND diagnosis No',
                      'AND medication No. Remaining cases Missing. Yes evidence wins.'),
  sample = paste('Age>=30; measured SBP and DBP each observed; periodontal, oral health,',
                 'smoking and hypertension observed; positive MEC weight and valid design IDs.'),
  education = 'DMDEDUC2 1/2 Less than HS, 3 HS, 4/5 More than HS; else Missing factor indicator',
  covariate_missing = 'Sex, race and education retain Missing levels. Age is observed by domain.',
  design = 'Build design on ALL positive-weight valid-ID MEC records, then subset analysis domain.',
  weighting = 'WTMEC2YR / 5; SDMVPSU; SDMVSTRA; nest=TRUE; lonely PSU policy=fail',
  model1 = 'Separate exposure models: HTN ~ periodontal OR oral health + age + sex + race + education',
  model_references = list(periodontal = 'No', oral = 'Excellent/Very good',
                         sex = 'Male', race = 'Non-Hispanic White',
                         education = 'More than high school'),
  inference = paste('quasibinomial svyglm; Wald t confidence intervals and p values use',
                    'fit df.residual = survey design df + 1 - model rank.',
                    'This may differ from SAS normal-Wald inference in the paper.'),
  descriptive = 'Raw n and column percentages; survey weighted column percentages; means and SE.',
  tests = 'Naive Pearson; 2x2 Yates/Fisher only; survey svychisq statistic=F (Rao-Scott).',
  fisher = 'fisher.test estimate is conditional MLE, distinct from raw cross-product ad/bc.',
  future_extension = 'Model registry and fit functions accept additional covariate vectors and outcomes.')

check_derivation_fixture <- function(ctx) {
  x <- data.frame(SEQN = 1:8, RIDAGEYR = rep(40, 8), RIAGENDR = 1,
                   RIDRETH1 = 3, DMDEDUC2 = 5, WTMEC2YR = 5,
                   SDMVPSU = 1, SDMVSTRA = 1, OHQ835 = c(1, 2, 7, 9, 1, 2, 1, 2),
                   OHQ845 = c(1, 2, 3, 4, 5, 7, 9, 3), SMQ020 = c(1, 2, 7, 9, 1, 2, 1, 2),
                   BPQ020 = c(2, 1, 7, 2, 2, 7, 2, 2),
                   BPQ040A = c(NA, 1, NA, NA, NA, 2, 2, NA),
                   BPQ050A = c(NA, 2, NA, NA, 1, NA, 1, NA),
                   BPXSY1 = c(120, 120, 120, 150, NA, 120, 120, NA),
                   BPXSY2 = c(NA, NA, NA, NA, 120, NA, NA, NA),
                   BPXDI1 = c(0, 80, 80, 80, 80, 80, 80, NA),
                   BPXDI2 = c(80, NA, NA, NA, NA, NA, NA, NA))
  y <- derive_records(x)
  assert_invariant(ctx, 'fixture_zero_dbp_included', identical(y$mean_dbp[[1L]], 40))
  assert_invariant(ctx, 'fixture_unpaired_valid_means', y$bp_measured_complete[[5L]])
  assert_invariant(ctx, 'fixture_htn_unknown_and_yes_priority',
                   identical(y$hypertension_code, c(0L, 1L, NA_integer_, 1L,
                                                    1L, NA_integer_, 1L, NA_integer_)))
  assert_invariant(ctx, 'fixture_special_codes_missing',
                   all(is.na(y$periodontal_code[3:4])) && all(is.na(y$smoking_code[3:4])))
  assert_invariant(ctx, 'fixture_medication_structural_no',
                   all(y$medication_htn[c(1, 4, 6, 8)] == 0L))
}

write_qa <- function(ctx, master) {
  assert_invariant(ctx, 'five_cycle_weight_scaling',
                   all(master$mec_weight == as.numeric(master$WTMEC2YR) / 5 |
                         (is.na(master$mec_weight) & is.na(master$WTMEC2YR))))
  assert_invariant(ctx, 'no_duplicate_cycle_seqn_after_derivation',
                   !anyDuplicated(paste(master$cycle, master$SEQN, sep = ':')))
  included <- master[master$analysis_domain, , drop = FALSE]
  assert_invariant(ctx, 'nonempty_analysis_domain', nrow(included) > 0L)
  assert_invariant(ctx, 'included_bp_minimum',
                   all(included$n_valid_sbp >= 1L & included$n_valid_dbp >= 1L))
  assert_invariant(ctx, 'included_exposures_and_outcome_observed',
                   !anyNA(included[, c('periodontal_code', 'oral_health', 'smoking_code',
                                      'hypertension_code', 'age')]))
  assert_invariant(ctx, 'both_hypertension_levels',
                   identical(sort(unique(included$hypertension_code)), c(0L, 1L)))
  stages <- c(all_demo = nrow(master), age30 = sum(master$domain_age30),
              valid_measured_sbp_dbp = sum(master$domain_bp),
              observed_periodontal = sum(master$domain_periodontal),
              observed_oral_health = sum(master$domain_oral),
              observed_smoking = sum(master$domain_smoking),
              observed_hypertension = sum(master$domain_htn),
              positive_mec_weight_valid_design = nrow(included))
  flow <- data.frame(stage = names(stages), n = as.integer(stages),
                     excluded_since_previous = c(NA_integer_, -diff(as.integer(stages))))
  assert_invariant(ctx, 'flow_monotone', all(diff(flow$n) <= 0L))
  write_csv(flow, file.path(ctx$run_dir, 'tables', 'sample_flow.csv'))
  group_counts <- as.data.frame(table(cycle = master$cycle,
                                    included = master$analysis_domain), stringsAsFactors = FALSE)
  write_csv(group_counts, file.path(ctx$run_dir, 'tables', 'cycle_flow_counts.csv'))
  qa_vars <- c('age', 'periodontal_code', 'oral_health', 'smoking_code', 'mean_sbp',
               'mean_dbp', 'diagnosis_htn', 'medication_htn', 'hypertension_code',
               'education', 'mec_weight', 'SDMVPSU', 'SDMVSTRA')
  missingness <- do.call(rbind, lapply(qa_vars, function(variable) {
    v <- master[[variable]]
    data.frame(variable = variable, all_n = length(v), missing_n = sum(is.na(v)),
               missing_percent = 100 * mean(is.na(v)),
               included_missing_n = sum(is.na(included[[variable]])),
               missing_category_n = if (is.factor(v)) sum(v == 'Missing', na.rm = TRUE) else NA_integer_)
  }))
  write_csv(missingness, file.path(ctx$run_dir, 'tables', 'missingness.csv'))
  raw_vars <- c('OHQ835', 'OHQ845', 'SMQ020', 'BPQ020', 'BPQ040A', 'BPQ050A',
                'DMDEDUC2', 'RIAGENDR', 'RIDRETH1')
  raw_codes <- do.call(rbind, lapply(raw_vars, function(variable) {
    tab <- table(numeric_col(master, variable), useNA = 'always')
    data.frame(variable = variable, raw_code = names(tab), n = as.integer(tab))
  }))
  write_csv(raw_codes, file.path(ctx$run_dir, 'tables', 'raw_code_counts.csv'))
  bp_qa <- as.data.frame(table(n_sbp = master$n_valid_sbp, n_dbp = master$n_valid_dbp,
                              zero_dbp = master$n_zero_dbp), stringsAsFactors = FALSE)
  write_csv(bp_qa, file.path(ctx$run_dir, 'tables', 'bp_reading_counts.csv'))
  component_qa <- as.data.frame(table(diagnosis = master$diagnosis_htn,
                                     medication = master$medication_htn,
                                     measured = master$measured_htn,
                                     final = master$hypertension_code, useNA = 'always'))
  write_csv(component_qa, file.path(ctx$run_dir, 'tables', 'htn_component_counts.csv'))
  list(flow = flow, analysis_n = nrow(included),
       htn_raw_n = sum(included$hypertension_code == 1L),
       no_htn_raw_n = sum(included$hypertension_code == 0L),
       htn_raw_percent = 100 * mean(included$hypertension_code),
       mec_design_n = sum(master$mec_design_eligible),
       zero_dbp_people_all = sum(master$n_zero_dbp > 0),
       zero_dbp_people_included = sum(included$n_zero_dbp > 0),
       medication_structural_no_n = sum(master$medication_structural_no),
       medication_conflict_n = sum(master$medication_conflict))
}

build_survey_design <- function(ctx, master) {
  # Filtering here is only the eligibility of the MEC survey design, not the
  # age/exposure/BP study domain. Retain out-of-domain records for variance.
  design_population <- master[master$mec_design_eligible, , drop = FALSE]
  design_population$SDMVPSU <- as.numeric(design_population$SDMVPSU)
  design_population$SDMVSTRA <- as.numeric(design_population$SDMVSTRA)
  full_design <- survey::svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA,
                                  weights = ~mec_weight, data = design_population,
                                  nest = TRUE)
  domain_design <- subset(full_design, analysis_domain)
  assert_invariant(ctx, 'design_uses_all_mec_before_domain',
                   nrow(full_design$variables) == sum(master$mec_design_eligible))
  assert_invariant(ctx, 'design_domain_equals_flow',
                   nrow(domain_design$variables) == sum(master$analysis_domain))
  assert_invariant(ctx, 'design_five_cycles',
                   length(unique(full_design$variables$cycle)) == 5L)
  assert_invariant(ctx, 'survey_design_positive_degrees_freedom', survey::degf(domain_design) > 0)
  psu_counts <- aggregate(SDMVPSU ~ SDMVSTRA, data =
                           unique(design_population[, c('SDMVSTRA', 'SDMVPSU')]), length)
  names(psu_counts)[[2L]] <- 'distinct_psu_n'
  write_csv(psu_counts, file.path(ctx$run_dir, 'tables', 'stratum_psu_counts.csv'))
  list(full = full_design, domain = domain_design,
       metadata = list(full_mec_n = nrow(full_design$variables),
                       domain_n = nrow(domain_design$variables),
                       full_design_df = survey::degf(full_design),
                       domain_design_df = survey::degf(domain_design),
                       strata_n = nrow(psu_counts), lonely_psu_policy = 'fail'))
}

table1_categorical <- function(ctx, design, variables) {
  output <- list()
  for (variable in variables) {
    for (group in c('All', 'No', 'Yes')) {
      d <- if (group == 'All') design else subset(design, hypertension == group)
      values <- d$variables[[variable]]
      levels <- levels(values)
      for (level in levels) {
        d$variables$.indicator <- as.numeric(values == level)
        est <- survey::svymean(~.indicator, d, na.rm = TRUE)
        output[[length(output) + 1L]] <- data.frame(
          variable = variable, level = level, hypertension_group = group,
          raw_n = sum(values == level, na.rm = TRUE), raw_denominator = sum(!is.na(values)),
          raw_percent = 100 * mean(values == level, na.rm = TRUE),
          weighted_percent = 100 * as.numeric(stats::coef(est)[[1L]]),
          weighted_percent_se = 100 * as.numeric(survey::SE(est)[[1L]]))
      }
    }
  }
  result <- do.call(rbind, output)
  for (variable in variables) for (group in c('All', 'No', 'Yes')) {
    rows <- result[result$variable == variable & result$hypertension_group == group, ]
    assert_invariant(ctx, paste0('table1_n_sum_', variable, '_', group),
                     sum(rows$raw_n) == unique(rows$raw_denominator))
    assert_invariant(ctx, paste0('table1_weighted_pct_sum_', variable, '_', group),
                     abs(sum(rows$weighted_percent) - 100) < 1e-7)
  }
  result
}
table1_continuous <- function(design, variables) {
  output <- list()
  for (variable in variables) for (group in c('All', 'No', 'Yes')) {
    d <- if (group == 'All') design else subset(design, hypertension == group)
    f <- stats::as.formula(paste0('~', variable))
    est <- survey::svymean(f, d, na.rm = TRUE)
    raw <- d$variables[[variable]]
    output[[length(output) + 1L]] <- data.frame(variable = variable,
      hypertension_group = group, raw_n = sum(!is.na(raw)), raw_mean = mean(raw, na.rm = TRUE),
      raw_sd = stats::sd(raw, na.rm = TRUE), weighted_mean = as.numeric(stats::coef(est)[[1L]]),
      weighted_mean_se = as.numeric(survey::SE(est)[[1L]]))
  }
  do.call(rbind, output)
}

categorical_tests <- function(design, variables) {
  output <- list()
  cells <- list()
  for (variable in variables) {
    raw_table <- table(design$variables[[variable]], design$variables$hypertension)
    raw_table <- raw_table[rowSums(raw_table) > 0, colSums(raw_table) > 0, drop = FALSE]
    pearson <- stats::chisq.test(raw_table, correct = FALSE)
    formula <- stats::as.formula(paste('~', variable, '+ hypertension'))
    test_design <- design
    # Preserve zero-count Missing rows in Table1, but do not ask svychisq to
    # invert the covariance of unobserved factor levels.
    test_design$variables[[variable]] <- droplevels(test_design$variables[[variable]])
    test_design$variables$hypertension <- droplevels(test_design$variables$hypertension)
    rs <- survey::svychisq(formula, test_design, statistic = 'F')
    make_row <- function(method, statistic, p, df1 = NA_real_, df2 = NA_real_,
                         estimate = NA_real_, low = NA_real_, high = NA_real_) data.frame(
      variable = variable, method = method, statistic = statistic, df1 = df1, df2 = df2,
      p_value = p, odds_ratio = estimate, ci_low = low, ci_high = high,
      min_expected = min(pearson$expected), cells_expected_below5 = sum(pearson$expected < 5))
    output[[length(output) + 1L]] <- make_row('Naive Pearson chi-square',
      as.numeric(pearson$statistic), pearson$p.value, as.numeric(pearson$parameter))
    output[[length(output) + 1L]] <- make_row('Survey Rao-Scott adjusted F',
      as.numeric(rs$statistic), rs$p.value, as.numeric(rs$parameter[[1L]]),
      if (length(rs$parameter) > 1L) as.numeric(rs$parameter[[2L]]) else NA_real_)
    if (identical(dim(raw_table), c(2L, 2L))) {
      yates <- stats::chisq.test(raw_table, correct = TRUE)
      fisher <- stats::fisher.test(raw_table)
      output[[length(output) + 1L]] <- make_row('Naive Yates chi-square (2x2 only)',
        as.numeric(yates$statistic), yates$p.value, as.numeric(yates$parameter))
      output[[length(output) + 1L]] <- make_row('Fisher exact conditional MLE (2x2 only)',
        NA_real_, fisher$p.value, estimate = as.numeric(fisher$estimate),
        low = fisher$conf.int[[1L]], high = fisher$conf.int[[2L]])
      adbc <- (raw_table[1, 1] * raw_table[2, 2]) /
        (raw_table[1, 2] * raw_table[2, 1])
      output[[length(output) + 1L]] <- make_row('Raw cross-product OR ad/bc (no test)',
        NA_real_, NA_real_, estimate = adbc)
    }
    tidy_cells <- as.data.frame(raw_table, stringsAsFactors = FALSE)
    names(tidy_cells) <- c('level', 'hypertension', 'observed_n')
    tidy_cells$variable <- variable
    tidy_cells$expected_n <- as.vector(pearson$expected)
    tidy_cells$pearson_residual <- as.vector(pearson$residuals)
    tidy_cells$standardized_residual <- as.vector(pearson$stdres)
    cells[[length(cells) + 1L]] <- tidy_cells
  }
  list(tests = do.call(rbind, output), cells = do.call(rbind, cells))
}
continuous_tests <- function(design, variables) do.call(rbind, lapply(variables, function(variable) {
  formula <- stats::as.formula(paste(variable, '~ hypertension'))
  naive <- stats::t.test(formula, data = design$variables)
  weighted <- survey::svyttest(formula, design)
  data.frame(variable = variable, method = c('Naive Welch t', 'Survey design t'),
             statistic = c(as.numeric(naive$statistic), as.numeric(weighted$statistic)),
             df = c(as.numeric(naive$parameter), as.numeric(weighted$parameter)),
             p_value = c(naive$p.value, weighted$p.value))
}))

plot_categorical <- function(ctx, design, variable) {
  tab <- table(design$variables[[variable]], design$variables$hypertension)
  tab <- tab[rowSums(tab) > 0, , drop = FALSE]
  filename <- file.path(ctx$run_dir, 'figures', paste0('naive_', variable, '_mosaic_residual.png'))
  grDevices::png(filename, width = 1600, height = 900, res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(6, 5, 4, 2))
  graphics::mosaicplot(tab, main = paste(variable, 'and hypertension'),
                      xlab = 'Unweighted cells', ylab = 'Hypertension', shade = TRUE,
                      las = 2, cex.axis = .8)
  residual <- stats::chisq.test(tab, correct = FALSE)$residuals
  max_abs <- max(1, abs(residual))
  palette <- grDevices::colorRampPalette(c('#2166AC', 'white', '#B2182B'))(101L)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, ncol(tab)), ylim = c(0, nrow(tab)), xaxs = 'i', yaxs = 'i')
  for (row in seq_len(nrow(tab))) for (column in seq_len(ncol(tab))) {
    index <- max(1L, min(101L, round(51 + 50 * residual[row, column] / max_abs)))
    y <- nrow(tab) - row
    graphics::rect(column - 1, y, column, y + 1, col = palette[index], border = 'white')
    graphics::text(column - .5, y + .5, sprintf('%.2f', residual[row, column]))
  }
  graphics::axis(1, at = seq_len(ncol(tab)) - .5, labels = colnames(tab))
  graphics::axis(2, at = nrow(tab) - seq_len(nrow(tab)) + .5,
                 labels = rownames(tab), las = 2, cex.axis = .75)
  graphics::title('Naive Pearson residuals', xlab = 'Hypertension')
  invisible(filename)
}

# The model registry can be extended to Model2/3 after their mappings are approved.
# Categorical Missing levels provide indicators; continuous missing values should
# be represented by a filled value AND a separate missing indicator in later models.
model_registry <- function() list(Model1 = c('age', 'sex', 'race', 'education'))
fit_one_model <- function(design, exposure, covariates, outcome = 'hypertension_code') {
  formula <- stats::reformulate(c(exposure, covariates), response = outcome)
  fit <- survey::svyglm(formula, design = design, family = stats::quasibinomial())
  df <- fit$df.residual
  if (is.null(df) || length(df) != 1L || is.na(df) || df <= 0)
    stop('Nonpositive/undefined survey model residual degrees of freedom.')
  beta <- stats::coef(fit)
  se <- sqrt(diag(stats::vcov(fit)))
  q <- stats::qt(.975, df = df)
  t_stat <- beta / se
  coefficients <- data.frame(term = names(beta), log_odds = as.numeric(beta),
    se = as.numeric(se), odds_ratio = exp(as.numeric(beta)),
    ci_low = exp(as.numeric(beta - q * se)), ci_high = exp(as.numeric(beta + q * se)),
    t_statistic = as.numeric(t_stat), p_value = 2 * stats::pt(abs(t_stat), df = df, lower.tail = FALSE),
    design_df = survey::degf(design), model_residual_df = df,
    ci_method = 'Wald t with survey model residual degrees of freedom',
    is_exposure = startsWith(names(beta), exposure), stringsAsFactors = FALSE)
  list(fit = fit, coefficients = coefficients,
       metadata = list(formula = paste(deparse(formula), collapse = ' '),
         outcome = outcome, independent_variable = exposure,
         n = nrow(stats::model.frame(fit)), converged = isTRUE(fit$converged),
         design_df = survey::degf(design), residual_df = df,
         rank = fit$rank, aliased_terms = names(fit$aliased)[fit$aliased]))
}
plot_forest <- function(ctx, coefficients) {
  x <- coefficients[coefficients$is_exposure & is.finite(coefficients$odds_ratio) &
                      is.finite(coefficients$ci_low) & is.finite(coefficients$ci_high) &
                      coefficients$ci_low > 0, , drop = FALSE]
  if (!nrow(x)) stop('No estimable exposure coefficients for forest plot.')
  path <- file.path(ctx$run_dir, 'figures', 'model1_forest.png')
  grDevices::png(path, width = 1500, height = max(700L, 100L * nrow(x)), res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 17, 4, 2))
  y <- rev(seq_len(nrow(x)))
  graphics::plot(x$odds_ratio, y, log = 'x', xlim = range(c(.9, 1.1, x$ci_low, x$ci_high)),
                 ylim = c(.5, nrow(x) + .5), yaxt = 'n', xlab = 'Survey adjusted odds ratio (95% t CI)',
                 ylab = '', pch = 19, main = 'Model1: hypertension as the outcome')
  graphics::segments(x$ci_low, y, x$ci_high, y)
  graphics::abline(v = 1, lty = 2, col = '#777777')
  graphics::axis(2, at = y, labels = paste(x$exposure, x$term, sep = ': '), las = 2, cex.axis = .8)
  invisible(path)
}
run_models <- function(ctx, design) {
  rows <- list()
  metadata <- list()
  for (model_name in names(model_registry())) for (exposure in c('periodontal', 'oral_health')) {
    result <- fit_one_model(design, exposure, model_registry()[[model_name]])
    assert_invariant(ctx, paste0(model_name, '_', exposure, '_converged'), result$metadata$converged)
    assert_invariant(ctx, paste0(model_name, '_', exposure, '_n_matches_domain'),
                     result$metadata$n == nrow(design$variables))
    result$coefficients$model <- model_name
    result$coefficients$exposure <- exposure
    result$coefficients$outcome <- 'hypertension_code'
    result$coefficients$subgroup <- 'Overall'
    rows[[length(rows) + 1L]] <- result$coefficients
    name <- paste(model_name, exposure, sep = '_')
    metadata[[name]] <- result$metadata
    saveRDS(result$fit, file.path(ctx$run_dir, 'models', paste0(name, '.rds')))
    capture.output(summary(result$fit, df.resid = result$metadata$residual_df),
                   file = file.path(ctx$run_dir, 'models', paste0(name, '_summary.txt')))
  }
  coefficients <- do.call(rbind, rows)
  write_csv(coefficients, file.path(ctx$run_dir, 'tables', 'model1_coefficients.csv'))
  write_csv(coefficients[coefficients$is_exposure, ],
            file.path(ctx$run_dir, 'tables', 'table2_model1_candidate.csv'))
  write_json(metadata, file.path(ctx$run_dir, 'models', 'model_metadata.json'))
  plot_forest(ctx, coefficients)
  list(metadata = metadata, exposure_results = coefficients[coefficients$is_exposure, ])
}

load_input_run <- function(ctx) {
  input_dir <- file.path(ctx$analysis_dir, 'runs', ctx$options$input_run)
  required <- file.path(input_dir, c('derived/master.rds', 'report.json', 'sources_manifest.csv',
                                    'artifact_hashes.csv', 'status.json'))
  if (!all(file.exists(required))) stop('Input run lacks tested master/manifest/status: ', input_dir)
  status <- jsonlite::read_json(file.path(input_dir, 'status.json'), simplifyVector = TRUE)
  if (!identical(status$status, 'success')) stop('Input run did not complete successfully.')
  hashes <- utils::read.csv(file.path(input_dir, 'artifact_hashes.csv'), stringsAsFactors = FALSE)
  row <- hashes[hashes$file == 'derived/master.rds', , drop = FALSE]
  if (nrow(row) != 1L || !identical(row$sha256[[1L]], hash_file(required[[1L]])))
    stop('Input master hash does not match its artifact manifest.')
  input_report <- jsonlite::read_json(file.path(input_dir, 'report.json'), simplifyVector = TRUE)
  if (!identical(input_report$revision, '1.1')) stop('Input run has a different definition revision.')
  manifest <- utils::read.csv(file.path(input_dir, 'sources_manifest.csv'), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(manifest))) {
    if (!file.exists(manifest$file[[i]]) ||
        !identical(hash_file(manifest$file[[i]]), manifest$sha256[[i]]))
      stop('Immutable source cache differs from input manifest: ', manifest$file[[i]])
  }
  file.copy(file.path(input_dir, 'sources_manifest.csv'),
            file.path(ctx$run_dir, 'sources_manifest.csv'), overwrite = FALSE)
  list(master = readRDS(required[[1L]]), data_version = input_report$data_version,
       manifest = manifest, input_run = ctx$options$input_run)
}

finalize_artifacts <- function(ctx) {
  write_csv(ctx$warnings, file.path(ctx$run_dir, 'logs', 'warnings.csv'))
  write_csv(ctx$invariants, file.path(ctx$run_dir, 'tables', 'invariants.csv'))
  capture.output(sessionInfo(), file = file.path(ctx$run_dir, 'logs', 'sessionInfo.txt'))
  files <- list.files(ctx$run_dir, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  files <- files[!file.info(files)$isdir & basename(files) != 'artifact_hashes.csv']
  root_prefix <- paste0(normalizePath(ctx$run_dir, winslash = '/', mustWork = TRUE), '/')
  relative <- substring(normalizePath(files, winslash = '/', mustWork = TRUE), nchar(root_prefix) + 1L)
  hashes <- data.frame(file = relative, bytes = file.info(files)$size,
                        sha256 = vapply(files, hash_file, character(1L)), stringsAsFactors = FALSE)
  write_csv(hashes, file.path(ctx$run_dir, 'artifact_hashes.csv'))
}

run_pipeline <- function(ctx) {
  start <- utc_now()
  options(timeout = 180, survey.lonely.psu = 'fail', survey.adjust.domain.lonely = FALSE)
  log_event(ctx, 'Start task R-CAT-001 rev1.1; stage', ctx$options$stage)
  write_json(list(status = 'running', started_utc = start, options = ctx$options),
             file.path(ctx$run_dir, 'status.json'))
  write_json(definition_document(), file.path(ctx$run_dir, 'definitions.json'))
  # Preserve a copy of the exact executed script for the artifact hash manifest.
  file_arg <- grep('^--file=', commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg)) {
    source_path <- sub('^--file=', '', file_arg[[1L]])
    if (file.exists(source_path)) file.copy(source_path, file.path(ctx$run_dir, 'executed_script.R'),
                                           overwrite = FALSE)
  }
  check_derivation_fixture(ctx)
  acquired <- if (is.null(ctx$options$input_run)) acquire_data(ctx) else load_input_run(ctx)
  master <- if (is.null(ctx$options$input_run)) derive_records(acquired$master) else acquired$master
  master$data_version <- acquired$data_version
  qa <- write_qa(ctx, master)
  saveRDS(master, file.path(ctx$run_dir, 'derived', 'master.rds'))
  write_csv(master, file.path(ctx$run_dir, 'derived', 'master.csv'))
  designs <- build_survey_design(ctx, master)
  design <- designs$domain
  categorical <- c('periodontal', 'oral_health', 'smoking', 'sex', 'race', 'education', 'age_group')
  table_cat <- table1_categorical(ctx, design, categorical)
  table_cont <- table1_continuous(design, c('age', 'mean_sbp', 'mean_dbp'))
  write_csv(table_cat, file.path(ctx$run_dir, 'tables', 'table1_categorical.csv'))
  write_csv(table_cont, file.path(ctx$run_dir, 'tables', 'table1_continuous.csv'))
  tests <- categorical_tests(design, categorical)
  write_csv(tests$tests, file.path(ctx$run_dir, 'tables', 'categorical_tests.csv'))
  write_csv(tests$cells, file.path(ctx$run_dir, 'tables', 'pearson_cell_diagnostics.csv'))
  write_csv(continuous_tests(design, c('age', 'mean_sbp', 'mean_dbp')),
            file.path(ctx$run_dir, 'tables', 'continuous_tests.csv'))
  for (variable in c('periodontal', 'oral_health', 'smoking')) plot_categorical(ctx, design, variable)
  htn_est <- survey::svymean(~hypertension_code, design)
  models <- if (ctx$options$stage %in% c('all', 'model')) run_models(ctx, design) else NULL
  report <- list(task = 'R-CAT-001', revision = '1.1', run_id = ctx$options$run_id,
                 stage = ctx$options$stage, started_utc = start, completed_utc = utc_now(),
                 data_version = acquired$data_version,
                 source_input_run = if (is.null(ctx$options$input_run)) NULL else ctx$options$input_run,
                 source_cache_policy = 'Existing valid files are read only; corruption is a hard failure.',
                 qa = qa, survey_design = designs$metadata,
                 htn_weighted_percent = 100 * as.numeric(stats::coef(htn_est)[[1L]]),
                 htn_weighted_percent_se = 100 * as.numeric(survey::SE(htn_est)[[1L]]),
                 warnings_n = nrow(ctx$warnings), invariants_passed = sum(ctx$invariants$passed),
                 models = models, target_comparison = 'Published results visible during source review; no tuning against counts/ORs.',
                 scope = 'Core Table1 and separate Model1 candidate models; Model2/3 and strata require extension.')
  write_json(report, file.path(ctx$run_dir, 'report.json'))
  write_json(list(status = 'success', started_utc = start, completed_utc = utc_now(),
                  run_id = ctx$options$run_id, data_version = acquired$data_version),
             file.path(ctx$run_dir, 'status.json'))
  log_event(ctx, 'Success; artifacts:', ctx$run_dir)
  finalize_artifacts(ctx)
  invisible(report)
}

main <- function() {
  opts <- parse_cli(commandArgs(trailingOnly = TRUE))
  ctx <- new_context(opts)
  tryCatch(withCallingHandlers(run_pipeline(ctx), warning = function(w) {
    ctx$warnings <- rbind(ctx$warnings, data.frame(time_utc = utc_now(),
      message = conditionMessage(w), call = paste(deparse(conditionCall(w)), collapse = ' ')))
    log_event(ctx, 'WARNING:', conditionMessage(w))
    invokeRestart('muffleWarning')
  }), error = function(e) {
    log_event(ctx, 'FAILED:', conditionMessage(e))
    write_json(list(status = 'failed', failed_utc = utc_now(), error = conditionMessage(e),
                    run_id = opts$run_id), file.path(ctx$run_dir, 'status.json'))
    try(finalize_artifacts(ctx), silent = TRUE)
    stop(e)
  })
}

if (sys.nframe() == 0L) main()
