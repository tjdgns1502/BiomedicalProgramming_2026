## 09_multiplicity_inflation.R ---------------------------------------
## Verification 1: FWER = 1 - 0.95^k analytic vs simulation (within MC error).
##
## Condition grid via expand.grid(), iterated with Map().
## Out: output/tables/fwer_analytic_vs_sim.csv,
##      output/figures/multiplicity_inflation_curve.png
## ------------------------------------------------------------------------

source("R/00_setup.R")  # run from project root: Rscript R/<script>.R

## TODO: not implemented yet (structure only)
