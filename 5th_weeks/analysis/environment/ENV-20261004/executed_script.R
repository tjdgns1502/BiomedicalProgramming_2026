Sys.setlocale('LC_ALL', 'English_United States.utf8')
# Read-only environment inspection; writes only a NEW analysis/environment/ID.
# Rscript analysis/src/collect_environment.R . ENV_ID --check-run=R2-20261004

env_main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  positional <- args[!startsWith(args, '--')]
  if (length(positional) > 2L) stop('Arguments: project_root and new snapshot_id.')
  root <- normalizePath(if (length(positional)) positional[[1L]] else '.',
                        winslash = '/', mustWork = TRUE)
  id <- if (length(positional) >= 2L) positional[[2L]] else
    paste0('ENV-', format(Sys.time(), '%Y%m%dT%H%M%SZ', tz = 'UTC'))
  check_run <- NULL
  for (arg in args[startsWith(args, '--')]) {
    if (!startsWith(arg, '--check-run=')) stop('Supported option: --check-run=ID.')
    check_run <- sub('^--check-run=', '', arg)
  }
  for (value in c(id, check_run))
    if (!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$', value) || value %in% c('.', '..'))
      stop('IDs must be safe ASCII directory names.')
  analysis <- file.path(root, 'analysis')
  project_lib <- file.path(analysis, 'r-library')
  if (!dir.exists(project_lib)) stop('Project R library is missing: ', project_lib)
  .libPaths(c(project_lib, .libPaths()))
  required <- c('jsonlite', 'digest')
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) stop('Required installed packages: ', paste(missing, collapse = ', '))
  out <- file.path(analysis, 'environment', id)
  if (file.exists(out)) stop('Environment snapshot already exists; refusing overwrite: ', out)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out)) stop('Cannot create environment snapshot: ', out)
  sha256 <- function(path) digest::digest(file = path, algo = 'sha256', serialize = FALSE)
  write_json <- function(x, name) jsonlite::write_json(x, file.path(out, name),
    pretty = TRUE, auto_unbox = TRUE, null = 'null', na = 'null')
  write_csv <- function(x, name) utils::write.csv(x, file.path(out, name), row.names = FALSE, na = '')
  packages <- function(lib) {
    matrix <- utils::installed.packages(lib.loc = lib, fields = c('Depends', 'Imports', 'LinkingTo'), noCache = TRUE)
    keep <- intersect(c('Package', 'Version', 'LibPath', 'Priority', 'Built', 'Depends', 'Imports', 'LinkingTo'), colnames(matrix))
    as.data.frame(matrix[, keep, drop = FALSE], stringsAsFactors = FALSE, row.names = NULL)
  }
  project_packages <- packages(project_lib)
  visible_packages <- packages(.libPaths())
  write_csv(project_packages, 'project_packages.csv')
  write_csv(visible_packages, 'visible_packages.csv')
  writeLines(.libPaths(), file.path(out, 'library_paths.txt'), useBytes = TRUE)
  capture.output(sessionInfo(), file = file.path(out, 'sessionInfo.txt'))
  major <- c('survey', 'haven', 'jsonlite', 'digest', 'Matrix', 'survival',
              'Rcpp', 'minqa', 'numDeriv', 'mitools', 'DBI')
  descriptions <- lapply(major, function(package) {
    location <- find.package(package, quiet = TRUE)
    if (!length(location)) return(data.frame(package = package, version = NA_character_,
      package_path = NA_character_, description_path = NA_character_, bytes = NA_real_, sha256 = NA_character_))
    path <- file.path(location[[1L]], 'DESCRIPTION')
    data.frame(package = package, version = as.character(utils::packageVersion(package, lib.loc = dirname(location[[1L]]))),
      package_path = normalizePath(location[[1L]], winslash = '/', mustWork = TRUE),
      description_path = normalizePath(path, winslash = '/', mustWork = TRUE),
      bytes = file.info(path)$size, sha256 = sha256(path), stringsAsFactors = FALSE)
  })
  write_csv(do.call(rbind, descriptions), 'major_description_hashes.csv')
  plans <- list.files(file.path(analysis, 'config'), pattern = '^plan-v.*[.]json$', full.names = TRUE)
  if (length(plans)) write_csv(data.frame(file = normalizePath(plans, winslash = '/'),
    bytes = file.info(plans)$size, sha256 = vapply(plans, sha256, character(1L))), 'plan_hashes.csv')
  run_check <- NULL
  if (!is.null(check_run)) {
    run_path <- file.path(analysis, 'runs', check_run)
    if (!dir.exists(run_path)) stop('Requested run does not exist: ', check_run)
    status_path <- file.path(run_path, 'status.json')
    status <- if (file.exists(status_path)) jsonlite::read_json(status_path, simplifyVector = TRUE) else NULL
    manifest_path <- file.path(run_path, 'artifact_hashes.csv')
    run_check <- list(run_id = check_run, status = status,
      scope = 'Artifact bytes only; this is not an independent statistical validation.')
    if (file.exists(manifest_path)) {
      manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
      if (!all(c('file', 'sha256') %in% names(manifest))) stop('Unsupported artifact manifest columns.')
      base <- paste0(normalizePath(run_path, winslash = '/', mustWork = TRUE), '/')
      checked <- lapply(seq_len(nrow(manifest)), function(i) {
        path <- file.path(run_path, manifest$file[[i]])
        resolved <- normalizePath(path, winslash = '/', mustWork = FALSE)
        inside <- startsWith(tolower(resolved), tolower(base))
        exists <- inside && file.exists(path)
        actual <- if (exists) sha256(path) else NA_character_
        data.frame(file = manifest$file[[i]], inside_run = inside, exists = exists,
          expected_sha256 = manifest$sha256[[i]], actual_sha256 = actual,
          matches = exists && identical(tolower(actual), tolower(manifest$sha256[[i]])))
      })
      checks <- do.call(rbind, checked)
      write_csv(checks, 'checked_run_artifacts.csv')
      run_check$artifact_manifest_sha256 <- sha256(manifest_path)
      run_check$checked_n <- nrow(checks)
      run_check$all_hashes_match <- all(checks$matches)
    } else {
      run_check$all_hashes_match <- NULL
      run_check$reason <- 'No final artifact manifest; the run may still be executing or use another schema.'
    }
  }
  script_arg <- grep('^--file=', commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_arg)) {
    script_path <- sub('^--file=', '', script_arg[[1L]])
    if (file.exists(script_path)) file.copy(script_path, file.path(out, 'executed_script.R'), overwrite = FALSE)
  }
  write_json(list(snapshot_id = id, captured_utc = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC'),
    project_root = root, R = as.list(R.version), R_home = R.home(),
    locale = Sys.getlocale(), library_paths = .libPaths(), sys_info = as.list(Sys.info()),
    project_package_n = nrow(project_packages), visible_package_n = nrow(visible_packages),
    package_policy = 'Inspection only: no installation, update, lock, or library modification.',
    run_check = run_check), 'environment.json')
  write_json(list(status = 'success', snapshot_id = id, completed_utc = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')),
             'status.json')
  files <- list.files(out, full.names = TRUE, recursive = TRUE)
  write_csv(data.frame(file = basename(files), bytes = file.info(files)$size,
    sha256 = vapply(files, sha256, character(1L))), 'artifact_hashes.csv')
  message('Environment snapshot: ', out)
  invisible(out)
}

if (sys.nframe() == 0L) env_main()
