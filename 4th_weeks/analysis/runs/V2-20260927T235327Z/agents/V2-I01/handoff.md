# V2-I01 independent implementation handoff

Completed the four bounded checks in the approved V2-D01 plan with V2-Q01 clarifications. All writes are inside `analysis/tasks/V2-I01/rev-1/work/`. No publication results, target effects, or existing fitted-result files were read. Existing `model_extensions.R` was read only as a survey-parent/domain structure reference and was not sourced.

## Observations and execution

- Common complete-row rule yielded 9,786 participants, 1,910 binary outcomes, 133 strata and 271 nested PSUs; design df is 138. Parent positive-weight design has 88,062 participants. This N was observed, never asserted as a target.
- Four ln/log10 comparisons passed coefficient, entire covariance, SE, coefficient-CI transformation, Wald, p, fitted probability and linear predictor tolerances. Maximum fitted-probability discrepancy is below 6e-15.
- All four raw-marker type-7 quartile models completed; 12 Q2/Q1, Q3/Q1, Q4/Q1 rows are in `quartile_model1.csv`, with separate cutpoints and category totals.
- Original full DEMO-derived design-input age counts are >=50: 24,119; >50: 23,313; =50: 806. Common candidate counts are 9,786; 9,693; 93. Every cycle and overall count identity passed. Missing age is separately tabulated. Full raw DEMO source files were not reread: the authorized full design derivative supplies recorded ages.
- Four fixed natural-spline diagnostics were estimable. Each tested two nonlinear terms with design covariance, F=W/2 and denominator df=138. Basis-span errors are below 4.7e-14. Raw and n=4 Bonferroni/BH p values are recorded without selecting a preferred result.
- Plot uses 5th-95th raw-marker percentile range, log x axis, median reference, and full model-row covariance contrasts; exact reference contrast is zero. Confidence intervals are pointwise 95% t(df=138), including all reported model intervals.
- Synthetic basis nesting, independent binomial toy log-base covariance identity, and age-count identity checks ran before outcomes were read. All passed. Final plot was generated successfully; initial plot was visually inspected and its lower margin enlarged in final code.

## Attempts and limitations

Attempt 1 succeeded. Attempt 2 added an unnecessary reconstruction assertion based on absolute CBC counts and failed before analysis because that assertion did not hold across the supplied derived input. It did not change any input or model specification. The assertion was removed, and attempt 3 succeeded with the frozen marker columns. All three stdout/stderr logs are retained. This is not a marker-source validation: marker derivation/fallback logic was not read or independently certified, and no replacement marker formula was inferred. Parent review must retain that provenance limitation.

The operational complete-36-item FI and supplied pooled survey weights are frozen inputs, not author-identical definitions or independently rederived weights. Candidate input already restricts age>=50, so the common-candidate audit supports the exact 50-year boundary comparison only. Parent-supplied source wording conflict (`50 and older`, `younger than 50 excluded`, `over 50`) retains the existing >=50 operational predicate. No age-boundary models were added.

`execution.json` records final source/input/config/plan/review SHA-256 hashes, output hashes, child-process locale settings, attempt exit codes and provenance limits. `analysis_rows.csv` plus its recorded hash identifies the exact domain row set. `basis_transformations.rds` and JSON store knots, boundaries and the fixed training transformation; plotting never refits a basis on its grid. Statistical interpretation and final acceptance belong to independent Q review.
