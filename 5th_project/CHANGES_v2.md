# v2 sample build

`R/11_build_analytic_sample_v2.R` replaces `R/11_build_analytic_sample.R` as
the source of the analysis data. The v1 script and its outputs
(`oral_htn_*.rds`, `exclusion_flow.csv`, `build_decisions.csv`,
`build_2x2_check.csv`) stay as committed.

## What changed and why

The ai-error-auditor found that v1 required a non-missing mean DBP. DBP
readings of 0 mean "not measurable" and are set to NA before averaging
(plan_revision.md item 5), which is correct. But 59 sample participants had
**all** DBP readings equal to 0, so their mean DBP was NA and v1 dropped them
as "without blood pressure", although they have SBP. The plan's own rule for
the validation step was "mean DBP > 0, NA allowed".

| | v1 | v2 |
|---|---|---|
| Blood pressure present | mean SBP **and** mean DBP | mean SBP |
| `htn_measured` | `sbp >= 140 \| dbp >= 90` (NA if DBP NA) | `sbp >= 140 \| (!is.na(dbp) & dbp >= 90)` |
| Outputs | `oral_htn_full.rds`, `exclusion_flow.csv`, ... | `oral_htn_full_v2.rds`, `exclusion_flow_v2.csv`, ... |

Everything else in the build is unchanged (diff the two scripts).

Downstream scripts were pointed at the v2 data in place rather than
duplicated, because only the input changed:

- `R/12_svydesign.R`: reads `oral_htn_full_v2.rds`.
- `R/13_validate_sample.R`: reads `oral_htn_analytic_v2.rds`. The DBP rule is
  now "> 0 where present (NA allowed)", and the `htn_measured` rule counts a
  missing DBP as < 90.
- `R/14_verify_validation_rules.R`: reads the v2 data and adds an
  `sbp_missing` mutation.
- `R/60_fill_ledger.R`: reads `exclusion_flow_v2.csv`.

The outputs of 12, 20, 30–34, 41 and 50 were regenerated. Their v1 versions
are in git history (commits up to `d2e784a`).

## Evidence

Sample:

| | v1 | v2 | Paper |
|---|---|---|---|
| Removed for no blood pressure | 1,945 | 1,879 | 19,398 |
| Removed for missing smoking/oral/perio | 680 | 687 | 1,090 |
| Analytic N | 21,417 | 21,476 | 21,800 |
| Analysis domain (HTN known) | 21,399 | 21,458 | 21,800 |
| HTN cases | 10,644 | 10,689 | 11,017 |

Validation (`R/13`, `R/14`): all hard rules pass on v2. The unmutated v2 data
(59 rows with DBP NA) does not stop, and every mutation still stops on its
own rule.

Effect on results (`30_models.csv`, v1 from git vs v2):

| | v1 | v2 |
|---|---|---|
| Max \|OR change\| over the 60 ORs | – | 0.0062 |
| Median \|OR change\| | – | 0.0008 |
| ORs within 0.03 of the paper | 39 / 60 | 39 / 60 |
| Table 2 all, Model 3, Poor | 1.4799 (1410/2448) | 1.4801 (1416/2457) |
| Table 2 all, Model 3, perio Yes | 1.2269 (2109/4014) | 1.2275 (2115/4023) |
| Table 2 non-smoking, Model 3, Poor | 1.6911 | 1.6849 |
| Model 3 OR/RR, median (`41_or_vs_rr.csv`) | 1.0908 | 1.0908 |

No conclusion changes:

- The swapped Model 1 cells, A14 and the P-interaction pattern are the same.
- Counts move by up to 15 cases and 21 participants per cell.

## Other audit findings handled in the same commit

- **Ledger tolerance.** The skill's half-unit rule is kept for `status`.
  OR rows that pass the plan's ±0.03 are flagged in `evidence`: 35 rows.
- **abs_diff precision.** Now written with 10 significant digits instead of 6.
- **CI comment in `model_utils.R`.** Corrected: `confint.svyglm` uses t on
  `df.residual`, not the normal distribution. No number changes.
