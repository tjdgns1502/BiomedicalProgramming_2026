## 03_build_analytic_sample.R ----------------------------------------
## Merge cycles, apply inclusion criteria (age >= 50), derive NLR/MLR/SIRI/SII, define comparison groups.
##
## In : data/raw/*.XPT, data/processed/frailty_index.rds
## Out: data/processed/analytic.rds, output/tables/flowchart.csv
## ------------------------------------------------------------------------

source("R/00_setup.R")  # run from project root: Rscript R/<script>.R

## TODO: not implemented yet (structure only)
