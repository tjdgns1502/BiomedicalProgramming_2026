# v2 simulation scripts

`R/11_multiplicity_inflation_v2.R` and `R/12_pvalue_uniformity_v2.R` replace
`R/01_*` and `R/02_*` for the final B = 10000 run. The simulation, targets,
pass rules and figures are unchanged; only how the work is executed changed.
The v1 scripts and their B = 1000 outputs stay as committed.

## What changed

| | v1 | v2 |
|---|---|---|
| Condition grid | `Map()`, sequential | `future.apply::future_Map()`, 7 workers (Windows: `multisession`), one future per condition |
| RNG | Mersenne-Twister, `set.seed(SEED0 + i)` per condition | `RNGkind("L'Ecuyer-CMRG")`, condition i gets the i-th `parallel::nextRNGStream()`; `--rng=legacy` keeps the v1 seeding for verification |
| JT test (12 only) | `PMCMRplus::jonckheereTest` | `jt_p()` in `R/00_sim_utils.R`: J from rank sums instead of an R double loop |
| Arguments | B fixed in the script | `--B`, `--rng`, `--workers`, `--outdir` |
| Outputs | `01_*.csv`, `02_*.csv` | `11_*_v2_B<B>.csv`, `12_*_v2_B<B>.csv` (+ figures) |

Shared code lives in `R/00_sim_utils.R`.

## Evidence

**JT replacement** (`R/10_verify_jt_fast.R` -> `output/tables/10_jt_fast_equivalence.csv`):
1500 random data sets over 6 designs (every design the simulation uses, plus
random k = 2..6 with unequal n, with and without a trend; p down to 1.6e-16).
`identical()` on 1500 / 1500, max |diff| = 0. One call at n = 200 per group:
0.155 s -> 0.0006 s.

**Parallel execution** (`R/13_verify_parallel.R` -> `output/tables/13_parallel_verification.csv`),
B = 1000, line-for-line comparison of the CSVs:

| check | 11 (multiplicity) | 12 (uniformity) |
|---|---|---|
| legacy RNG, 7 workers vs committed v1 CSV | identical | identical |
| streams RNG, 1 worker vs 7 workers | identical | identical |

The first row shows the parallel code (and, for 12, the JT swap) changes no
number. The second shows streams-mode results don't depend on the number of
workers.

The first attempt at this check failed on every data line: the legacy `seed`
column was written as a character, so `write.csv` quoted it (`"20260929"` vs
`20260929`). All other columns already matched. Fixed in `sim_seeds()` by
keeping the legacy label an integer; the check was rerun unchanged and passed.

## Why the streams results differ from v1

L'Ecuyer-CMRG and Mersenne-Twister draw different random numbers, so the
B = 10000 streams run is a new, independent Monte Carlo sample. Its estimates
are compared with the analytical targets, not with the v1 estimates.

## Timing (B = 1000, this laptop, 8 logical / 4 physical cores)

| | v1 sequential | v2, 7 workers |
|---|---|---|
| 11 multiplicity | 216-323 s | 57-58 s |
| 12 uniformity | 206-278 s | 13-39 s |
