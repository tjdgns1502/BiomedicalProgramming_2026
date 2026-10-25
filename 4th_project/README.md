# Week 4 — Frailty index × CBC-derived inflammatory markers (NHANES)

Reproduction of the group comparisons and trend tests in
Han S, et al. *Correlations between frailty index and inflammatory markers
derived from blood cell count in the United States.* BMC Public Health
2024;24:3408. PMID 39695452. doi:[10.1186/s12889-024-20908-9](https://doi.org/10.1186/s12889-024-20908-9)

Data: NHANES 1999–2016, adults aged 50 or older (paper: n = 13,507; 3,729 frail).
Markers: NLR, MLR, SIRI, SII.

## Layout

```
4th_project/
├── R/                      numbered scripts, run in order from this folder
│   ├── 00_setup.R          packages, paths, global seed (sourced by all)
│   ├── 01_download_data.R
│   ├── 02_build_frailty_index.R
│   ├── 03_build_analytic_sample.R
│   ├── 04_group_comparisons.R        ANOVA, Welch, Kruskal-Wallis, Tukey
│   ├── 05_trend_tests.R
│   ├── 06_multiplicity_correction.R  Bonferroni, BH
│   ├── 07_figures_diagnostics.R      boxplots, 4 residual plots
│   ├── 08_null_pvalue_simulation.R   verification: p ~ U(0,1) under H0
│   └── 09_multiplicity_inflation.R   verification: 1 - 0.95^k vs simulation
├── data/
│   ├── raw/                .XPT downloads (git-ignored)
│   └── processed/          derived .rds (git-ignored)
└── output/
    ├── figures/
    └── tables/
```

## Running

```powershell
$RS = "..\bin\Rscript.exe"   # repo-local R 4.6.1
& $RS R\01_download_data.R   # ...then 02, 03, ... in order
```

Every script starts with `source("R/00_setup.R")`, which loads packages,
creates output folders, and sets the global seed (`20241218`).

## Packages

`haven`, `dplyr`, `tidyr`, `ggplot2`, `patchwork`. Everything else is base R
(`aov`, `oneway.test`, `kruskal.test`, `TukeyHSD`, `p.adjust`, `ks.test`,
`plot.lm`, `expand.grid`, `Map`).
