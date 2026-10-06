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
| A10 | SAS 9.4 사용. χ² 검정이 Rao-Scott 보정 버전인지 기재가 없다 | 비보정 χ²와 Rao-Scott χ²를 둘 다 내서 어느 쪽이 논문 p와 맞는지 본다 |

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
| `01_tables_from_paper.R` | 표 2·3 증례/전체 수로 `table`/`xtabs` 객체 생성: 구강건강(4) × HTN, 치주(2) × HTN, 각각 × 흡연, × 연령의 3원표. `addmargins`, `prop.table(margin = 1)`로 조건부 확률 P(HTN \| 노출)와 P(노출 \| HTN)을 나열 | `01_contingency_from_paper.csv` |
| `02_tests_from_paper.R` | 각 표에 `chisq.test(correct = FALSE/TRUE)`, `fisher.test`, 조 OR(Woolf CI)·RR(log CI)·RD. 3원표에 `mantelhaen.test`(CMH OR)와 Breslow-Day 동질성 검정(`DescTools::BreslowDayTest`). 이것이 교호작용 p(A9)에 대한 비가중 기준선이 된다 | `02_crude_tests.csv` |

### 단계 B: NHANES 2009–2018 (F–J, 5주기)

**필요 파일:** DEMO, BPX, BPQ, OHQ(OHQ835 = 잇몸병 자각, OHQ845 = 구강건강 자가평가), SMQ(SMQ020), ALQ, PAQ, SLQ, BMX, TCHOL, HDL, TRIGLY, GHB, BIOPRO(크레아티닌), DR1TOT(DR1TSODI, DR1TTFAT), MCQ(CVD: MCQ160B/C/D/E/F), DIQ.

| 스크립트 | 내용 |
|---|---|
| `10_download_data.R` | 위 파일 × 5주기 → `data/raw/*.rds` |
| `11_build_analytic_sample.R` | 30세 이상 → 혈압 있음 → 흡연·OHQ835·OHQ845 있음. HTN = 평균 SBP ≥ 140 또는 DBP ≥ 90 또는 BPQ020 = 1 또는 BPQ050A = 1. 구강건강은 Excellent + VG를 합쳐 4단계. `exclusion_flow.csv`, `build_decisions.csv` 작성. 목표 N = 21,800, 증례 11,017 |
| `12_svydesign.R` | `svydesign(ids = ~SDMVPSU, strata = ~SDMVSTRA, weights = ~WTMEC2YR/5, nest = TRUE)`. 30세 이상 표본은 `subset()`으로 잡는다(행을 먼저 지우지 않는다) |

### 단계 C: 표 1 재현 (분할표 + Rao-Scott)

| 스크립트 | 내용 |
|---|---|
| `20_table1.R` | 범주형: 비가중 n + 가중 %(`svytable`, `svymean`). 검정은 ① 가중 빈도에 단순 `chisq.test`(잘못된 방법, 비교용) ② `svychisq(statistic = "Chisq")` ③ `svychisq(statistic = "F")` (Rao-Scott 2차 보정) ④ 비가중 `chisq.test`. 연속형: `svyby` 평균(SE), `svyttest`. 논문 p와 ①–④를 나란히 놓는다 |

Rao-Scott 보정이 무엇을 바꾸는지가 이번 주 학습 포인트다. 가중 셀 빈도로 만든 순진한 χ²는 N이 모집단 크기로 부풀려져 p가 0으로 붕괴한다. 설계효과(deff)로 나눈 보정 통계량과 비교해 보인다.

### 단계 D: 보정 OR 재현 (표 2·3)

| 스크립트 | 내용 |
|---|---|
| `30_logistic_models.R` | `svyglm(family = quasibinomial)`. 표 2 Model 1–3 × {전체, 비흡연, 흡연} × {구강건강, 치주}. 표 3도 같은 방식으로 × {연령 < 45, ≥ 45}. P-trend는 구강건강 서열 점수(1–4)를 연속형으로 넣은 Wald p. P-interaction은 노출 × 흡연(또는 연령) 곱셈항의 `regTermTest` |
| `31_sensitivity_htn_def.R` | 보충표 I/II: HTN을 측정치만으로 정의(미진단) vs 진단·치료로 정의 |
| `32_mcnemar.R` | **McNemar**(같은 사람의 짝지은 이분 판정): ① 측정 기반 HTN vs 자가보고 진단 HTN의 불일치 칸(b, c) ② (선택) 2009–2014 임상 치주 검사(OHXPER, CDC/AAP 정의) vs OHQ835 자가보고. `mcnemar.test(correct = TRUE/FALSE)`와 정확 이항검정 비교 |

### 단계 E: 검증 과제

**(1) Fisher 정확검정은 보수적이다. `40_fisher_size.R`** (monte-carlo-verification 스킬)

- 설계: 두 독립 이항, 귀무가설 p₁ = p₂ = π. 그룹당 n ∈ {5, 10, 20, 30, 50, 100}, π ∈ (0.05, 0.95) 격자, α = 0.05
- **정확 크기**: 모든 (x₁, x₂) 결과를 열거하고 기각된 결과의 이항 확률을 더한다. 시뮬레이션 오차가 없다
- 몬테카를로(B = 10,000)로 교차 확인. 합격 기준: |MC − 정확| ≤ 3·√(α(1−α)/B)
- 비교 검정: Fisher, Pearson χ², Yates 보정 χ², Fisher mid-p, (선택) Boschloo
- 확인할 것: Fisher의 크기가 모든 격자점에서 α 이하이고 대개 크게 밑돈다. Yates는 더 보수적이고, Pearson은 작은 n에서 α를 넘기도 한다. n = 21,800 수준에서는 차이가 사라진다는 점도 함께 보인다(이번 논문에 Fisher가 필요 없는 이유)
- 산출물: `40_fisher_size.csv`, 그림 **검정 크기 곡선**(x = π, y = 실제 크기, 검정별 선, α = 0.05 기준선, n별 패널)

**(2) OR이 RR을 얼마나 과장하는가. `41_or_vs_rr.R`**

- 같은 모형 구성으로 가중 **보정 RR**을 추정한다: `svyglm(family = quasipoisson(link = "log"))`(수정 포아송, 설계 기반 SE). 수렴하면 log-binomial도 함께
- 각 대비(구강건강 3개, 치주 1개 × 층 × 모형)에 대해 OR, RR, **과장률 = OR/RR**, (OR − 1)/(RR − 1)
- Zhang–Yu 변환 RR ≈ OR / (1 − P₀ + P₀·OR)과 직접 추정한 RR을 비교한다. 보정 모형에서 이 근사가 편향된다는 점을 보인다
- 이론 곡선: P₀ ∈ [0.01, 0.9]에서 OR/RR. 논문의 층(< 45: P₀ ≈ 0.23, ≥ 45: P₀ ≈ 0.62)을 점으로 찍는다
- 산출물: `41_or_vs_rr.csv`, 효과 척도 **forest plot**(같은 대비의 OR과 RR을 나란히)

### 단계 F: 도표

| 스크립트 | 그림 |
|---|---|
| `50_figures.R` | **mosaic plot**: 구강건강 × HTN (흡연별 패널). `vcd::mosaic(shade = TRUE)` |
| | **Pearson 잔차도**: `chisq.test()$residuals`(필요하면 `stdres`) 히트맵 또는 `vcd::assoc` |
| | **forest plot**: 표 2·3 OR(논문 vs 우리) + 41의 OR vs RR |
| | **검정 크기 곡선**: 40에서 |

### 단계 G: ledger와 보고서

- `60_fill_ledger.R`: 표 1(n, %, 평균, p), 표 2·3(증례/전체, OR, CI, P-trend, P-interaction)을 논문 값 대 우리 값으로 기록하고, 불일치마다 원인을 A1–A10에 연결
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
