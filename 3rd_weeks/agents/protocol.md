# 에이전트 교환 규약

각 라운드의 전달물:

```text
round, family, alignment, reps, local_rate, paper_rate, difference, z, verdict, cause
```

최종 라운드에는 `mae_pp`, `rmse_pp`, `max_abs_error_pp`, `pearson_r`, `r_squared`, `lin_ccc`, `regression_slope`, `mc_pass_percent`를 추가한다.

`verdict=pass`이면 해당 family를 고정한다. `fail`이면 실험 에이전트가 아직 시험하지 않은 정렬 후보 하나만 실행한다. 두 family가 모두 통과하면 종료한다. 최대 3라운드 후에는 `unresolved`로 종료하며 논문과 다르다는 사실을 보존한다.
