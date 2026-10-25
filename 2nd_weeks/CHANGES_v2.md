# v2 — teammate 교차검증 반영

v1(`02_build_table1.R` + `03_table1_stats.R`)은 N·사분위 경계값·대부분의 변수를 논문과 거의 일치시켰지만, Triglycerides/LDL-C의 SD와 일부 변수(Education Q4, HBP, CHD 등)에서 논문과 소수 단위 이상의 잔차가 남아 있었습니다.

`Teammate_analysis/R/06_diagnose_discrepancies.R`는 이 잔차를 가설별로 점수화(Σ|재현값 − 논문값|, 132개 셀)하는 그리드서치로 원인을 찾았고, 우리 v1이 놓쳤던 3가지를 확인했습니다. 이를 반영해 `12_build_table1_v2.R` / `13_table1_stats_v2.R`을 새로 만들었습니다 (v1 파일은 그대로 둠).

## 무엇이 바뀌었나

| 항목 | v1 | v2 | 근거 |
|---|---|---|---|
| 가중치 | MEC 검진가중치(WTMEC2YR/WTMECPRP) + CDC 기간비례 재조정(2/9.2, 3.2/9.2) | **설문(interview) 가중치 WTINT2YR/WTINTPRP를 재조정 없이 원본 그대로** | 132개 셀 그리드서치에서 점수 13.57 → 1.0으로 급감 |
| 결측 처리 (PIR·Triglycerides·LDL-C·HDL-C·Total cholesterol) | 결측 제외 (available-case) | **전체(비가중) 평균으로 대치** 후 평균/SD 계산 | 대치 시 SD가 √(관측비율) 배만큼 줄어드는 이론값과 실제 감소폭이 일치 (예: TG 관측률 46% → 예상 축소배율 0.68, 실측과 일치). 음주량은 대치하지 않음(결측 유지) |
| 연속형 P-value | 복합표본설계 F검정 (`svyglm` + Wald/Rao-Scott) | **단순 가중회귀 F검정** (`lm(y ~ group, weights=w)` + `anova()`) | 유일하게 두 방법이 구분되는 값인 음주량 P=0.187이 단순 가중회귀에서만 정확히 재현됨 |
| 사분위 절단 | `cut(..., right=TRUE)` — 경계값과 같으면 **아래** 사분위 | `cut(..., right=FALSE)` — 경계값과 같으면 **위** 사분위 | n 패턴이 논문의 5,847/5,847/5,847/**5,848**(Q4가 1명 더 많음)과 정확히 일치 |

## 결과 비교 (일부)

| 변수 | v1 (paper와 차이) | v2 (paper와 차이) |
|---|---|---|
| N (Q1~Q4) | 5,848/5,847/5,847/5,847 | **5,847/5,847/5,847/5,848 — 정확히 일치** |
| Triglycerides | 93.90±87.54 (paper 107.49±63.03, SD 크게 다름) | **107.48±63.04 — 거의 완전 일치** |
| LDL-C | 106.55±33.30 (paper 109.30±22.37) | **109.30±22.37 — 완전 일치** |
| Average alcohol | 3.32±20.79, P=0.657 (paper 3.24±18.67, P=0.187) | **3.24±18.67, P=0.187 — 완전 일치** |
| PIR / HDL-C / Total cholesterol | paper와 소수점 이내지만 차이 있음 | **완전 일치** |

## 왜 v1의 시행착오(스크립트 07~09)가 틀렸나

v1 당시에는 Triglycerides/LDL-C SD가 작은 원인을 "공복 서브샘플 전용 가중치(WTSAF2YR/WTSAFPRP)를 안 써서"로 추정하고 `07_diagnose_fasting.R`에서 검증했지만, 실제로 적용해봐도 값이 거의 바뀌지 않아 기각했습니다(당시 결론: "가중치 문제가 아니다"). 이 결론 자체는 맞았지만, 그 다음 단계 — "그럼 무엇 때문인가"에 대한 답(평균 대치)을 못 찾은 채 남겨뒀던 것을 teammate의 그리드서치가 찾아냈습니다.

## 실행

```r
source("scripts/12_build_table1_v2.R")   # data/analytic_sample_v2.rds
source("scripts/13_table1_stats_v2.R")   # output/table1_v2.csv
```
