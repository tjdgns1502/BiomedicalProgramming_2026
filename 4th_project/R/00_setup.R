## 00_setup.R ------------------------------------------------------------
## Shared setup sourced at the top of every numbered script:
## packages, project paths, global seed.
##
## Required packages (all CRAN):
##   haven     - read NHANES .XPT (SAS transport) files
##   dplyr     - data wrangling
##   tidyr     - reshaping (long format for boxplots / grids)
##   ggplot2   - figures
##   patchwork - combining ggplot panels
## Everything else is base R:
##   stats::aov, oneway.test (Welch), kruskal.test, TukeyHSD,
##   lm / prop.trend.test (trend), p.adjust (Bonferroni, BH),
##   ks.test (uniformity check), plot.lm (4 residual plots),
##   expand.grid, Map (condition grids)
## ------------------------------------------------------------------------

pkgs <- c("haven", "dplyr", "tidyr", "ggplot2", "patchwork")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       "\nInstall with: install.packages(c(",
       paste0('"', missing, '"', collapse = ", "), "))")
}
invisible(lapply(pkgs, library, character.only = TRUE))

## Project root = parent of R/, whether run via Rscript or interactively.
PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))

RAW_DIR  <- file.path(PROJ, "data", "raw")
PROC_DIR <- file.path(PROJ, "data", "processed")
FIG_DIR  <- file.path(PROJ, "output", "figures")
TAB_DIR  <- file.path(PROJ, "output", "tables")
for (d in c(RAW_DIR, PROC_DIR, FIG_DIR, TAB_DIR)) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

## Global seed. RNGkind is pinned too so results do not depend on the
## R version's default sampler.
SEED <- 20241218  # paper publication date
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(SEED)
