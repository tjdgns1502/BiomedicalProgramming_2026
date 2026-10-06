# 5주차 계획: 범주형 자료와 분할표

**논문.** Li Y et al. *The association of periodontal disease and oral health with hypertension, NHANES 2009–2018.* BMC Public Health 2023;23:1122 (PMID 37308938).
**재현 목표.** 분할표(표 1, 표 2·3의 증례/전체 수)와 보정 오즈비(표 2·3의 Model 1–3).
**검증 과제.** (1) Fisher 정확검정의 실제 유의수준이 명목 수준에 못 미침을 확인한다. (2) 유병률이 높은 결과에서 OR이 RR을 얼마나 과장하는지 산출한다.

---

## 0. 논문에서 이미 확인한 것

### 표 2·3 수치만으로 분할표를 그대로 복원할 수 있다

표 2·3의 "Cases/total"은 **비가중** 수이고, 서로 맞물려 합이 맞는다(Python으로 검산함).

| 검산 | 값 |
|---|---|
| 비흡연 구강건강 4단계 합 = 비흡연 치주질환 2단계 합 = 표 1 흡연 No | 11,882 = 11,882 = 11,882 |
| 표 3 연령 < 45 합 + ≥ 45 합 | 6,589 + 15,211 = 21,800 |

그래서 **NHANES를 내려받기 전에도** 2×2, 4×2, 2×2×2 분할표를 만들고 χ²·Fisher·OR·RR을 계산할 수 있다. 이것이 1단계다(아래 §2).

### 논문 수치로 본 비가중 조 OR vs RR (미리보기)

| 비교 | p₁ | p₀ | 조 OR | RR | OR/RR |
|---|---|---|---|---|---|
| 치주질환 유 vs 무 (전체) | 0.533 | 0.499 | 1.148 | 1.069 | 1.07 |
| 구강건강 Poor vs Excellent/VG (전체) | 0.582 | 0.471 | 1.565 | 1.236 | 1.27 |
| 구강건강 Poor, 연령 ≥ 45 | 0.665 | 0.587 | 1.393 | 1.132 | 1.23 |
| 치주질환, 연령 < 45 | 0.315 | 0.231 | 1.528 | 1.362 | 1.12 |

고혈압 유병률이 약 50%(연령 ≥ 45에서는 약 60%)라 OR을 RR로 읽으면 안 되는 상황이다. 검증 과제 (2)의 핵심 근거다. 위 값은 비가중 수치이고, 최종 값은 가중 분석으로 다시 낸다.

### 층별 비가중 조 OR vs 논문 Model 1 (구강건강 Good / Fair / Poor)

| 층 | P₀ (Excellent/VG) | 비가중 조 OR | 논문 Model 1 OR |
|---|---|---|---|
| 전체 | 0.471 | 1.12 / 1.24 / 1.57 | 1.23 / 1.48 / 1.84 |
| 비흡연 | 0.434 | 1.13 / 1.37 / 1.88 | 1.19 / 1.20 / 1.49 |
| **흡연** | 0.529 | **1.07 / 1.04 / 1.22** | **1.22 / 1.73 / 2.33** |

흡연층에서는 연령·성별·인종·교육만 보정했는데 Poor의 OR이 1.22에서 2.33으로 약 2배가 됐다. 이어서 Model 2에서는 1.29로 다시 떨어진다. 비흡연층은 오히려 1.88에서 1.49로 줄었다. 가중치와 연령 보정만으로 설명되는지, 아니면 열이 뒤바뀌는 등 논문 쪽 오류인지를 §3 단계 D(`34_stratum_or_decomposition.R`)에서 분해해 확인한다(A12).

### 재현 전에 표시해 둘 논문의 불일치·모호점

| # | 내용 | 대응 |
|---|---|---|
| A1 | 제외 흐름: 21,800 + 19,398 + 1,090 = 42,288. 2009–2018 30세 이상 인원과 맞지 않는다. "혈압 없음 19,398"에 30세 미만이 섞인 것으로 보인다 | 우리 흐름을 `exclusion_flow.csv`로 따로 산출하고 차이를 ledger에 기록 |
| A2 | 표 1 당뇨: Yes 5.8/21.9%, No 6.9/12.0%, **Missing 87/66%**. 일반적인 DIQ010 코딩으로는 나올 수 없다 | DIQ010 기준으로 정의하고, 논문 분포는 재현 불가 항목으로 기록 |
| A3 | 표 1 수면: < 7시간이 68%. SLD010H/SLD012 분포와 맞지 않아 범주 경계 오류가 의심된다 | 논문 정의대로 만들고 분포 차이를 기록 |
| A4 | 표 1 음주: "No drinks" 3–5%, Missing 26–32%. 2017–18 ALQ는 문항 체계가 바뀌었다(ALQ121) | 주기별 조화 규칙을 `build_decisions.csv`에 명시 |
| A5 | 가중치 미기재. 식이(나트륨·지방)는 WTDRD1, 중성지방은 공복 하위표본(WTSAF2YR)이다 | 주 분석은 WTMEC2YR/5. WTDRD1/5는 민감도 분석 |
| A6 | 표 2와 표 3의 모형 구성이 다르다(표 3 Model 1에 나이 없음, Model 2에 흡연은 있고 CVD·당뇨·나트륨·지방은 없음) | 각 표의 각주를 그대로 따른다 |
| A7 | 이분형 치주질환에 "P-trend"가 있다. Wald p와 같아야 한다 | 계산해 확인 |
| A8 | 결측 공변량은 "결측 범주 + 지시변수"로 처리했다. 연속형 검사값에도 이렇게 했는지는 불분명하다 | 연속형은 평균 대치 + 결측 지시변수로 하고 결정을 기록 |
| A9 | 교호작용 p가 4개 모두 < 0.001인데, 층별 OR은 서로 비슷하다(예: 치주 1.22 vs 1.16) | 곱셈항 Wald 검정(`regTermTest`)으로 다시 계산해 비교 |
| A10 | SAS 9.4 사용. 검정 옵션이 기재되지 않았다. PROC SURVEYFREQ의 `CHISQ` 기본값은 **1차 Rao-Scott 보정 χ²**이다 | R `svychisq(statistic = "Chisq")`(1차 보정)가 논문 p와 맞을 가능성이 가장 높다. 2차 보정(`"F"`)과 비보정 χ²도 함께 내서 비교 |
| A11 | 표 1 성별: 고혈압군 Male 5,412 + Female 5,606 = **11,018**인데, 고혈압군 전체는 11,017이다(비고혈압군은 5,140 + 5,643 = 10,783로 맞음) | 표 1 내부 불일치로 ledger에 기록. 우리 n과 비교할 때는 행 합계가 아니라 칸 값 기준 |
| A12 | 흡연층 구강건강 Poor: 비가중 조 OR 1.22 → 논문 Model 1 2.33 → Model 2 1.29. 비흡연층과 방향도 반대다 | `34_stratum_or_decomposition.R`에서 원인을 분해한다 |
| A14 | (`00_paper_consistency.R`에서 발견) 표 2 비흡연 구강건강 Model 3의 P-trend가 0.032다. 같은 모형에서 Fair 1.49 (1.26–1.77)의 Wald p는 4×10⁻⁶, Poor는 4×10⁻⁴이고 OR이 단조 증가하는데 추세 p만 크다. 반면 이분형 치주질환의 P-trend 12개는 모두 CI에서 역산한 Wald p와 반올림 범위 안에서 일치했다(A7 해소: P-trend = Wald p, CI = Wald CI) | 서열 점수 추세 검정으로 재계산해 비교. 논문 오기 가능성을 ledger에 기록 |
| A13 | 방법의 보정 변수 목록에는 흡연이 있지만, 표 2 Model 1–3 각주에는 흡연이 없다(표 3 Model 2에는 있음) | 주 재현은 각주대로 하고, 흡연을 추가한 모형은 민감도 분석으로 따로 낸다(`33_smoking_adjusted.R`) |

---

## 1. 작업 흐름 (저장소 관례를 따름)

1. **paper-target-extractor 에이전트** → `output/tables/paper_methods.csv`, 보고 수치 목록(표 1–3의 모든 수)
2. **nhanes-data-builder 에이전트** (nhanes-survey-data 스킬) → 원자료 다운로드 + 분석 표본
3. 분석 스크립트(아래 §3)
4. **ai-error-auditor 에이전트** → 결과를 ledger에 넣기 전에 감사
5. **paper-reproduction-ledger 스킬** → `output/tables/ledger.csv`에 우리 값/논문 값/불일치 원인 기록
6. 보고서(Rmd → HTML, 한/영) + 커밋. 이미 커밋한 분석을 고칠 때는 `_v2` 새 파일 + `CHANGES_v2.md`

## 2. 디렉터리

```
5th_project/
  PLAN.md
  paper/                     (논문, methods.md)
  R/
  data/raw/  data/processed/
  output/tables/  output/figures/  output/report/
```

## 3. 스크립트 계획

### 단계 A: 논문 수치만 사용 (다운로드 불필요)

| 스크립트 | 내용 | 산출물 |
|---|---|---|
| `00_paper_consistency.R` | 데이터 없이 논문 숫자끼리 맞는지 먼저 확인한다(scienceclaw-verification의 점검 항목을 R로 옮긴 것). ① OR ≈ √(CI 하한 × 상한) ② CI에서 SE = (ln 상한 − ln 하한)/3.92를 구해 Wald p를 역산하고, 이분형 치주질환의 P-trend와 비교(A7) ③ 표 1·2·3의 합계와 교차합(성별 합, 층별 합 = 전체, 증례 합). 불일치는 A 목록에 추가 | `00_paper_consistency.csv` |
| `01_tables_from_paper.R` | 표 2·3 증례/전체 수로 `table`/`xtabs` 객체 생성: 구강건강(4) × HTN, 치주(2) × HTN, 각각 × 흡연, × 연령의 3원표. `addmargins`, `prop.table(margin = 1)`로 조건부 확률 P(HTN \| 노출)와 P(노출 \| HTN)을 나열 | `01_contingency_from_paper.csv` |
| `02_tests_from_paper.R` | 각 표에 `chisq.test(correct = FALSE/TRUE)`, `fisher.test`, 조 OR(Woolf CI)·RR(log CI)·RD. 3원표에 `mantelhaen.test`(CMH OR)와 Breslow-Day 동질성 검정(`DescTools::BreslowDayTest`). 이것이 교호작용 p(A9)에 대한 비가중 기준선이 된다 | `02_crude_tests.csv` |

### 단계 B: NHANES 2009–2018 (F–J, 5주기)

**필요 파일:** DEMO, BPX(2017–18도 청진식 `BPX_J`. 오실로메트릭 `BPXO_J`는 섞지 않는다), BPQ, OHQ(OHQ835 = 잇몸병 자각, OHQ845 = 구강건강 자가평가), SMQ(SMQ020), ALQ, PAQ, SLQ, BMX, TCHOL, HDL, TRIGLY, GHB, BIOPRO(크레아티닌), DR1TOT(DR1TSODI, DR1TTFAT), MCQ(CVD: MCQ160B/C/D/E/F), DIQ.

| 스크립트 | 내용 |
|---|---|
| `10_download_data.R` | 위 파일 × 5주기 → `data/raw/*.rds` |
| `11_build_analytic_sample.R` | 30세 이상 → 혈압 있음 → 흡연·OHQ835·OHQ845 있음. HTN = 평균 SBP ≥ 140 또는 DBP ≥ 90 또는 BPQ020 = 1 또는 BPQ050A = 1. 구강건강은 Excellent + VG를 합쳐 4단계. `exclusion_flow.csv`, `build_decisions.csv` 작성. 목표 N = 21,800, 증례 11,017 |
| | **혈압 정리 규칙.** ① BPXDI1–4 = 0은 측정 불가이므로 평균 내기 **전에** NA로 바꾼다. ② BPQ050A(현재 혈압약 복용)는 BPQ040A = 1(BPQ040A는 다시 BPQ020 = 1)인 사람에게만 묻는다. 건너뛰기로 생긴 NA는 결측이 아니라 "복용 안 함"으로 처리하고, 결측 제외 대상에도 넣지 않는다. 진짜 결측은 77/99뿐이다. ③ 2017–18도 BPX_J만 쓴다 |
| `13_validate_sample.R` | **pointblank**로 분석 표본을 규칙 검사한다. 하나라도 실패하면 멈춘다(`stop_on_fail`). 규칙: SEQN 중복 없음(`rows_distinct`), 나이 ≥ 30, 주기 ∈ F–J, 평균 DBP > 0(NA 허용), BPQ040A ≠ 1이면 복용 = 0(`preconditions`), BPXO 열 없음, 구강건강 ∈ 1–4, 치주·흡연 ∈ {0, 1}, 가중치 > 0, 행 수와 HTN 증례 수(논문 21,800 / 11,017과의 차이는 실패가 아니라 경고로 둔다). 데이터프레임 단계에서 검사하고(`svydesign`은 검사 불가), 리포트는 `output/report/13_validation.html` |
| `12_svydesign.R` | `svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~WTMEC2YR/5, nest = TRUE)`. 30세 이상 표본은 `subset()`으로 잡는다(행을 먼저 지우지 않는다) |

### 단계 C: 표 1 재현 (분할표 + Rao-Scott)

| 스크립트 | 내용 |
|---|---|
| `20_table1.R` | 범주형: 비가중 n + 가중 %(`svytable`, `svymean`). 검정은 ① 가중 빈도에 단순 `chisq.test`(잘못된 방법, 비교용) ② `svychisq(statistic = "Chisq")`: 1차 Rao-Scott 보정으로, SAS `PROC SURVEYFREQ / CHISQ` 기본값과 같은 계열이다. **논문 p와 맞을 1순위 후보** ③ `svychisq(statistic = "F")`: 2차(Satterthwaite) Rao-Scott 보정. SAS의 `CHISQ(SECONDORDER)`에 해당 ④ 비가중 `chisq.test`. 연속형: `svyby` 평균(SE), `svyttest`. 논문 p와 ①–④를 나란히 놓는다 |

Rao-Scott 보정이 무엇을 바꾸는지가 이번 주 학습 포인트다. 가중 셀 빈도로 만든 순진한 χ²는 N이 모집단 크기로 부풀려져 p가 0으로 붕괴한다. 설계효과(deff)로 나눈 보정 통계량과 비교해 보인다.

### 단계 D: 보정 OR 재현 (표 2·3)

| 스크립트 | 내용 |
|---|---|
| `30_logistic_models.R` | `svyglm(family = quasibinomial)`. 표 2 Model 1–3 × {전체, 비흡연, 흡연} × {구강건강, 치주}. 표 3도 같은 방식으로 × {연령 < 45, ≥ 45}. P-trend는 구강건강 서열 점수(1–4)를 연속형으로 넣은 Wald p. P-interaction은 노출 × 흡연(또는 연령) 곱셈항의 `regTermTest` |
| `31_sensitivity_htn_def.R` | 보충표 I/II: HTN을 측정치만으로 정의(미진단) vs 진단·치료로 정의 |
| `33_smoking_adjusted.R` | (A13) 전체 표본의 표 2 Model 1–3에 흡연(SMQ020)을 추가한 민감도 분석. 흡연 층 안에서는 흡연이 상수이므로 전체 행에만 적용한다. 각주대로 한 OR과 나란히 놓는다 |
| `34_stratum_or_decomposition.R` | (A12) 흡연층·비흡연층에서 보정을 한 단계씩 추가한다: 비가중 조 OR → 가중 조 OR(`svyglm`, 공변량 없음) → + 나이 → + 성별 → + 인종 → + 교육(= Model 1). 어느 단계에서 1.22가 2.33으로 바뀌는지 찾는다. 다음 가설을 검토한다: 가중치 효과, 연령 교란, 비붕괴성(41 참조, 이것만으로는 2배를 설명하기 어려움), 논문 표의 열 또는 층 뒤바뀜. 흡연 × 연령 × 구강건강 3원표도 함께 본다 |
| `32_mcnemar.R` | **McNemar**(같은 사람의 짝지은 이분 판정): ① 측정 기반 HTN vs 자가보고 진단 HTN의 불일치 칸(b, c) ② (선택) 2009–2014 임상 치주 검사(OHXPER, CDC/AAP 정의) vs OHQ835 자가보고. `mcnemar.test(correct = TRUE/FALSE)`와 정확 이항검정 비교 |

### 단계 E: 검증 과제

**(1) Fisher 정확검정은 보수적이다. `40_fisher_size.R`** (monte-carlo-verification 스킬)

- 설계: 두 독립 이항, 귀무가설 p₁ = p₂ = π. 그룹당 n ∈ {5, 10, 20, 30, 50, 100}, π ∈ (0.05, 0.95) 격자, α = 0.05
- **정확 크기**: Fisher p 값은 π와 무관하게 (x₁, x₂)만으로 정해진다(주변합 조건부). 그래서 n마다 (n+1)² 결과에 대해 `fisher.test`를 **한 번만** 돌려 기각 지시 행렬 R[x₁, x₂]를 만든다. 크기(π) = Σ R · dbinom(x₁, n, π) · dbinom(x₂, n, π)이므로, π 격자 전체는 `outer(dbinom(0:n, n, π), dbinom(0:n, n, π))`와 R의 원소곱 합으로 계산한다. π마다 검정을 다시 돌리지 않는다. Pearson, Yates, mid-p도 p 값이 데이터만의 함수이므로 같은 방식으로 처리한다. 시뮬레이션 오차가 없다
- 몬테카를로(B = 10,000)로 교차 확인. 합격 기준: |MC − 정확| ≤ 3·√(α(1−α)/B)
- 비교 검정: Fisher, Pearson χ², Yates 보정 χ², Fisher mid-p, (선택) Boschloo
- 확인할 것: Fisher의 크기가 모든 격자점에서 α 이하이고 대개 크게 밑돈다. Yates는 더 보수적이고, Pearson은 작은 n에서 α를 넘기도 한다. n = 21,800 수준에서는 차이가 사라진다는 점도 함께 보인다(이번 논문에 Fisher가 필요 없는 이유)
- 산출물: `40_fisher_size.csv`, 그림 **검정 크기 곡선**(x = π, y = 실제 크기, 검정별 선, α = 0.05 기준선, n별 패널)

**(2) OR이 RR을 얼마나 과장하는가. `41_or_vs_rr.R`**

- 같은 모형 구성으로 가중 **보정 RR**을 추정한다: `svyglm(family = quasipoisson(link = "log"))`(수정 포아송, 설계 기반 SE). 수렴하면 log-binomial도 함께
- 각 대비(구강건강 3개, 치주 1개 × 층 × 모형)에 대해 OR, RR, **과장률 = OR/RR**, (OR − 1)/(RR − 1)
- Zhang–Yu 변환 RR ≈ OR / (1 − P₀ + P₀·OR)과 직접 추정한 RR을 비교한다. 보정 모형에서 이 근사가 편향된다는 점을 보인다
- 이론 곡선: P₀ ∈ [0.01, 0.9]에서 OR/RR. 점은 **대비마다 그 대비의 기준군 P₀**로 찍는다. 같은 층이라도 구강건강 대비(기준 Excellent/VG)와 치주질환 대비(기준 치주질환 없음)는 P₀가 다르다. 논문 표 2·3에서 구한 비가중 P₀는 다음과 같다(가중 P₀로 다시 계산한다)

  | 층 | 구강건강 대비 P₀ (Excellent/VG) | 치주질환 대비 P₀ (없음) |
  |---|---|---|
  | 전체 | 3185/6769 = 0.471 | 8839/17717 = 0.499 |
  | 비흡연 | 1801/4151 = 0.434 | 4664/10018 = 0.466 |
  | 흡연 | 1384/2618 = 0.529 | 4175/7699 = 0.542 |
  | 연령 < 45 | 415/2053 = 0.202 | 1243/5381 = 0.231 |
  | 연령 ≥ 45 | 2770/4716 = 0.587 | 7596/12336 = 0.616 |

- **비붕괴성(non-collapsibility).** OR은 교란이 전혀 없어도 결과를 예측하는 공변량을 추가하면 1에서 멀어진다. RR(log link)은 붕괴 가능하다. 따라서 "보정 후 OR 변화 = 교란"이라는 해석이 틀릴 수 있다.
  - 시뮬레이션: 노출과 **독립**인 공변량 Z(교란 아님)가 결과에 강하게 작용하는 경우. 주변 OR과 Z 조건부 OR은 다르고, 주변 RR과 Z 조건부 RR은 같음을 보인다. P₀와 Z 효과 크기를 바꿔 가며 차이를 그린다
  - 실제 자료: Model 1 → 2 → 3으로 갈 때 OR의 변화와 RR의 변화를 나란히 놓는다. RR은 거의 그대로인데 OR만 움직이면 그 변화의 일부는 비붕괴성이다
  - `34_stratum_or_decomposition.R`의 단계별 변화를 해석할 때도 이 결과를 쓴다
- 산출물: `41_or_vs_rr.csv`, `41_noncollapsibility_sim.csv`, 효과 척도 **forest plot**(같은 대비의 OR과 RR을 나란히), 비붕괴성 그림

### 단계 F: 도표

| 스크립트 | 그림 |
|---|---|
| `50_figures.R` | **mosaic plot**: 구강건강 × HTN (흡연별 패널). `vcd::mosaic(shade = TRUE)` |
| | **Pearson 잔차도**: `chisq.test()$residuals`(필요하면 `stdres`) 히트맵 또는 `vcd::assoc` |
| | **forest plot**: 표 2·3 OR(논문 vs 우리) + 41의 OR vs RR |
| | **검정 크기 곡선**: 40에서 |

### 단계 G: ledger와 보고서

- `60_fill_ledger.R`: 표 1(n, %, 평균, p), 표 2·3(증례/전체, OR, CI, P-trend, P-interaction)을 논문 값 대 우리 값으로 기록하고, 불일치마다 원인을 A1–A13에 연결
- `output/report/week5_report.Rmd`(+ `_ko`)

---

## 4. 판정 기준

| 대상 | 일치로 볼 기준 |
|---|---|
| 표 2·3 증례/전체 수 | 정확 일치가 목표. 아니면 제외 흐름 차이(A1)로 설명 |
| 가중 % | ±1%p |
| 보정 OR | 소수 둘째 자리 ±0.03, CI 경계 ±0.05 |
| p 값 | 같은 유의성 판정(< 0.05)과 같은 보고 구간(< 0.001 등) |
| Fisher 크기 | 정확 크기 ≤ 0.05 (전 격자점), MC가 정확값의 3 SE 이내 |

## 5. 위험 요소

- 2017–18 주기의 ALQ·PAQ·SLQ 문항 변경. 조화 실패 시 공변량 분포가 달라진다(A3, A4)
- 결측 범주 처리 방식(A8)이 Model 3 OR을 0.01–0.03 정도 움직일 수 있다
- 표 1 당뇨 분포(A2)는 원리상 재현이 안 될 가능성이 높다. 시간을 들이지 않고 원인만 기록한다
- `svyglm` 수정 포아송은 적합값이 1을 넘을 수 있다. 확인 후 기록한다
- A12(흡연층 OR 2배)가 논문 표의 오류로 판명되면, 흡연층 Model 1은 재현 불가 항목으로 기록하고 그 근거(분해 결과)를 보고서에 싣는다

## 6. 개정 이력

| 날짜 | 근거 | 변경 |
|---|---|---|
| 2026-10-07 | 초안 | — |
| 2026-10-07 | `plan_revision.md` 1–10 | 1 → A11 (표 1 성별 합 11,018). 2 → A12 + 층별 조 OR 표 + `34_stratum_or_decomposition.R`. 3 → A13 + `33_smoking_adjusted.R`. 4–6 → `11_build_analytic_sample.R` 혈압 정리 규칙(BPQ050A 건너뛰기, DBP 0 → NA, BPX_J만). 7 → A10과 `20_table1.R`의 χ² 설명 정정(SAS 기본 = 1차 Rao-Scott = `svychisq("Chisq")`). 8 → `40_fisher_size.R` 기각역 1회 계산. 9 → `41_or_vs_rr.R` 비붕괴성 추가. 10 → 대비별 P₀ 표, 0.62는 치주질환 기준군 값이었음을 정정 |
| 2026-10-07 | 외부 스킬 검토 | pointblank → `13_validate_sample.R`. scienceclaw-verification의 점검 항목 → `00_paper_consistency.R`(스킬은 설치하지 않음). review-paper-code와 paper-review-skills는 사용하지 않음 |
