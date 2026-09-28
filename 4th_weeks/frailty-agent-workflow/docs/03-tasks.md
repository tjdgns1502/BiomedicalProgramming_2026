> **이전 v1 설계 보관 문서입니다.** 아래 내용은 당시의 계획이며 현재 실행 지시가 아닙니다. 현재의 역할·경로·우선순위·완료 기준은 [v2 실행 프롬프트](05-prompts.md)를 따릅니다. 당시 “미연결/미실행”은 현재 분석 상태를 뜻하지 않습니다.

# 학습자료의 질문을 실제 작업으로 바꾸기

상태는 모두 **계획됨**입니다. 작업 설명을 작성한 것을 통계 분석 완료로 세지 않습니다. 입력이 확보되고 의존 산출물이 검수되면 실행할 수 있습니다.

| 작업 | 범위·역할 | 학습 단계 | 해결할 질문 | 선행 작업 |
|---|---|---|---|---|
| S01 | required / S | 01–10·원문·과제 | 과제·논문·학습자료에서 확정 사실과 제안을 어떻게 구별하는가? | 없음 |
| S02 | required / S | 01 | 분석할 개인별 자료와 R 환경이 실제로 있는가? | 없음 |
| S03 | required / S | 01–02 | 개인 키·단위·혈구 기반 지표의 계산은 신뢰할 수 있는가? | S01, S02 |
| S04 | required / S | 03 | FI는 어떤 항목·분모·코딩으로 만들어지고 Fried와 무엇이 다른가? | S01, S02 |
| S05 | required / S | 04 | 표본·결측·조사설계는 어떤 규칙으로 정할 것인가? | S03, S04 |
| S06 | required / S | 05 | 모형을 정하기 전에 어떤 분포·품질 정보를 볼 수 있는가? | S05 |
| B00 | required / B | 전체 | 자료가 없어도 정할 수 있는 질문과 분석 범위는 무엇인가? | S01 |
| B01 | required / B | 06–09 | 추정 대상·검정·비교 가족·경향 점수·변경 규칙을 무엇으로 고정하는가? | B00, S05, S06 |
| A01 | reproduction / A | 04–09 | 공개되지 않은 설정의 어떤 후보를 비교할 근거가 있는가? | S01, S05 |
| A02 | reproduction / A | 05・08・09 | Table 1–3과 선정 흐름의 어떤 출력이 어떤 후보에서 일치하는가? | A01 |
| A03 | optional / A | 10 | 곡선과 하위집단 도표는 보고된 정보로 어느 정도 재현 가능한가? | A02 |
| C01 | required / C | 09・과제 | FI 사분위군에 누가 들어가는가? | B01 |
| C02 | required / C | 05–07・과제 | FI 네 군에서 네 염증지표의 평균 또는 분포가 다른가? | C01 |
| C03 | required / C | 과제 | 어느 군 쌍이 다르며 다중검정 후 무엇을 주장할 수 있는가? | C02 |
| C04 | required / C | 09・과제 | 정한 군 점수에 따른 경향이 있는가? | C01 |
| C05 | required / C | 05・07・과제 | 집단 분포와 잔차 진단은 어떤 가정·영향점을 보여주는가? | C02 |
| M00 | required / M | 과제 | 실제 자료 없이 검정 절차를 평가할 모의실험을 어떻게 설계하는가? | S01 |
| M01 | required / M | 과제 | 독립 전역 귀무에서 p값과 1−0.95^k가 검증되는가? | M00 |
| M02 | required / M | 02・과제 | 상관된 지표/공유 쌍별 비교에서 오류 통제가 어떻게 달라지는가? | M00 |
| M03 | optional / M | 과제 확장 | 혼합 귀무·대립과 가정 위반에서 FDR와 검정력은 어떠한가? | M00 |
| M04 | required / M | 과제 통합 | 실제 과제 코드의 선택·사후검정·보정 절차가 검증 코드와 같은가? | B01, C03, M01, M02 |
| V01 | optional / V | 03 | FI 이분화 기준이나 점수 모형에서 해석이 얼마나 달라지는가? | B01 |
| V02 | optional / V | 02–03・08・10 | 혈소판 등 구성 항목 중복이 연관성에 영향을 주는가? | B01 |
| V03 | optional / V | 04・07・09 | 결측·변환·가중치·동점 규칙에서 결론은 얼마나 변하는가? | B01 |
| V04 | optional / V | 02–03 | Fried·CRP·IL-6 대안은 이 자료에서 실제 계산 가능한가? | S04 |
| G01 | required / G | 전체 | 과제 결과의 흐름·검정·도표·근거가 일관되는가? | C03, C04, C05, M04 |
| G02 | required / G | 전체 | 과제·재현·방법 검증의 결론과 남은 한계를 어떻게 분리 보고하는가? | G01 |

## 작업별 완료 증거

### S01 — 과제·논문·학습자료에서 확정 사실과 제안을 어떻게 구별하는가?

- 산출물: `runs/S01/evidence-register.json`, `runs/S01/requirement-map.md`, `runs/S01/methods-handoff.md`, `runs/S01/paper-targets.json`
- 검수: 요구사항마다 원본 위치; 원문 미기재/충돌/제안 분리; 목표 수치는 paper-targets에만 저장하고 공통 인계문에서 제외

### S02 — 분석할 개인별 자료와 R 환경이 실제로 있는가?

- 산출물: `runs/S02/data-inventory.json`, `runs/S02/environment.txt`
- 검수: 파일·해시·주기·코드북·R 실행 경로 기록; 없으면 needs_input과 필요한 최소 열 목록; 원자료를 임의로 생성하지 않음

### S03 — 개인 키·단위·혈구 기반 지표의 계산은 신뢰할 수 있는가?

- 산출물: `runs/S03/variable-map.json`, `runs/S03/cbc-checks.json`, `runs/S03/row-lineage.md`
- 검수: 주기별 변수 매핑, 단위, 특수결측, 분모 0, join 중복 검사; N/L, M/L, N*M/L, P*N/L의 표본 행 계산 검증

### S04 — FI는 어떤 항목·분모·코딩으로 만들어지고 Fried와 무엇이 다른가?

- 산출물: `runs/S04/fi-contract.json`, `runs/S04/measurement-rationale.md`
- 검수: 36항목 매핑/분모/부분결측 근거; 미제공 항목은 검증 불가; Fried를 FI의 하위항목으로 넣지 않음; 대안 측정 검토 범위 기록

### S05 — 표본·결측·조사설계는 어떤 규칙으로 정할 것인가?

- 산출물: `runs/S05/cohort-contract.json`, `runs/S05/missingness.json`, `runs/S05/survey-design.md`, `runs/S05/cohort-flow.json`
- 검수: 연령·주기·순차 제외·모형별 결측·설계 변수·가중치 선택 근거; 미보고 처리 후보와 타당한 기본 결정을 분리

### S06 — 모형을 정하기 전에 어떤 분포·품질 정보를 볼 수 있는가?

- 산출물: `runs/S06/limited-diagnostics.json`, `runs/S06/exposure-log.json`
- 검수: 범위·동점·끝값·군별 가능 인원·결측 진단; 관계 탐색 또는 결과를 보면 노출로 기록; 학습용 가상값을 실제값으로 사용하지 않음

### B00 — 자료가 없어도 정할 수 있는 질문과 분석 범위는 무엇인가?

- 산출물: `runs/B00/design-draft.md`, `runs/B00/pending-decisions.json`
- 검수: 과제 방향(FI군→염증)과 재현 방향(염증→노쇠) 구별; 입력 없는 사항을 확정하지 않은 초안

### B01 — 추정 대상·검정·비교 가족·경향 점수·변경 규칙을 무엇으로 고정하는가?

- 산출물: `runs/B01/analysis-plan.json`, `runs/B01/analysis-plan.md`, `runs/B01/plan-lock.json`
- 검수: 방법·대상·변환·결측·가중/비가중·동점·가족·CI·민감도·중단 기준·사전 노출·해시 완비; A 목표 p값을 선택 근거로 쓰지 않음

### A01 — 공개되지 않은 설정의 어떤 후보를 비교할 근거가 있는가?

- 산출물: `runs/A01/candidate-register.json`, `runs/A01/target-tolerances.json`
- 검수: 후보·근거·각 출력 허용오차·탐색 상한·식별 한계·추가 후보 규칙 등록; 임의 행 삭제 금지

### A02 — Table 1–3과 선정 흐름의 어떤 출력이 어떤 후보에서 일치하는가?

- 산출물: `runs/A02/reproduce.R`, `runs/A02/all-attempts.json`, `runs/A02/comparison.json`, `runs/A02/reproduction-report.md`
- 검수: 모든 시도·실패·수렴·n·CI·오차 보존; 미일치 원인 명시; 일치해도 저자 설정 확정/타당성 성공으로 승격하지 않음

### A03 — 곡선과 하위집단 도표는 보고된 정보로 어느 정도 재현 가능한가?

- 산출물: `runs/A03/figure-reconstruction.R`, `runs/A03/figure-limitations.md`
- 검수: RCS 매듭·기준값 후보, 상호작용 검정, 모호한 그림 표기·본문 충돌 기록; 과제의 필수 요구인지 먼저 판단

### C01 — FI 사분위군에 누가 들어가는가?

- 산출물: `runs/C01/make-groups.R`, `runs/C01/group-boundaries.json`, `runs/C01/group-counts.json`
- 검수: 기준집단·가중 여부·분위수 알고리즘·동점·경계 규칙 고정; 동일 FI 처리·빈 군 검사; 지표마다 경계를 새로 만들지 않음

### C02 — FI 네 군에서 네 염증지표의 평균 또는 분포가 다른가?

- 산출물: `runs/C02/omnibus.R`, `runs/C02/summary.json`, `runs/C02/omnibus-results.json`
- 검수: ANOVA/Welch/KW 전부 구현, 추정 대상 구별, 주/보완 라벨, 실패·실제 n·CI/효과 크기; 최소 p값 방법 선택 금지

### C03 — 어느 군 쌍이 다르며 다중검정 후 무엇을 주장할 수 있는가?

- 산출물: `runs/C03/posthoc.R`, `runs/C03/pairwise-results.json`, `runs/C03/family-register.json`
- 검수: Tukey와 가정에 맞는 대안 비교; 가족 단위·원/보정 p값·차이/CI; Bonferroni/BH 대상 일치; 중복 보정 경고

### C04 — 정한 군 점수에 따른 경향이 있는가?

- 산출물: `runs/C04/trend.R`, `runs/C04/trend-results.json`
- 검수: 1–4 또는 FI 중앙값 점수, 척도, 추정치/CI·가족·보정·선형 경향의 한계; 단조성 또는 모든 인접 차이 유의로 과장하지 않음

### C05 — 집단 분포와 잔차 진단은 어떤 가정·영향점을 보여주는가?

- 산출물: `runs/C05/plots.R`, `runs/C05/boxplots.html`, `runs/C05/diagnostics.html`, `runs/C05/diagnostic-notes.md`
- 검수: 네 지표 상자그림과 적합 모형별 잔차 4종; 축·변환·n·진단의 의미; 영향점 자동 삭제 금지

### M00 — 실제 자료 없이 검정 절차를 평가할 모의실험을 어떻게 설계하는가?

- 산출물: `runs/M00/simulation-plan.json`, `runs/M00/simulation-lock.json`
- 검수: DGP·귀무/대립·n·k·분산·의존·B·seed/난수 스트림·선택 절차·오류 정의·MCSE·실행예산 고정

### M01 — 독립 전역 귀무에서 p값과 1−0.95^k가 검증되는가?

- 산출물: `runs/M01/simulate-independent.R`, `runs/M01/null-p-histogram.html`, `runs/M01/inflation-independent.html`, `runs/M01/mc-results.json`
- 검수: expand.grid/Map 실행·seed·로그; 유효 독립 검정·전역 귀무; FWER와 이론값·MCSE/구간; 보정 p값 균등성으로 혼동하지 않음

### M02 — 상관된 지표/공유 쌍별 비교에서 오류 통제가 어떻게 달라지는가?

- 산출물: `runs/M02/simulate-dependent.R`, `runs/M02/inflation-dependent.html`, `runs/M02/dependent-results.json`
- 검수: 의존 생성 근거·공유 자료·무보정/Bonferroni/BH·범위; 독립 공식 불일치를 자동 오류로 보지 않음

### M03 — 혼합 귀무·대립과 가정 위반에서 FDR와 검정력은 어떠한가?

- 산출물: `runs/M03/simulate-alternatives.R`, `runs/M03/power-fdr-results.json`
- 검수: 알려진 참/거짓 가설, V/R, FWER·FDR·검정력·각 MCSE; 전역 귀무에서 FDR=FWER라는 한계 해소

### M04 — 실제 과제 코드의 선택·사후검정·보정 절차가 검증 코드와 같은가?

- 산출물: `runs/M04/procedure-audit.md`, `runs/M04/procedure-check.R`, `runs/M04/procedure-check-results.json`
- 검수: 계획/실제 함수/모의 함수 비교; 사후검정 선별 등 다르면 전체 절차 재모의; 결과 공개 후 변경은 새 계획 버전

### V01 — FI 이분화 기준이나 점수 모형에서 해석이 얼마나 달라지는가?

- 산출물: `runs/V01/fi-sensitivity-plan.md`, `runs/V01/fi-sensitivity.R`, `runs/V01/fi-sensitivity-results.json`
- 검수: 근거 있는 기준, fractional logit/beta의 끝값·이산 FI·설계 고려; 평균 FI 차이와 OR 직접 비교 금지; 과제와 별도

### V02 — 혈소판 등 구성 항목 중복이 연관성에 영향을 주는가?

- 산출물: `runs/V02/overlap-map.json`, `runs/V02/overlap-sensitivity.R`, `runs/V02/overlap-results.json`
- 검수: SII와 FI 혈소판 중복·질환 공변량 중복; 제외 FI의 새 분모/추정 대상 기록; 원자료 항목 미제공이면 needs_input

### V03 — 결측·변환·가중치·동점 규칙에서 결론은 얼마나 변하는가?

- 산출물: `runs/V03/pipeline-sensitivity.R`, `runs/V03/sensitivity-matrix.json`
- 검수: 정한 후보만 실행·전체 결과 공개·척도와 분석 대상 변화 표시; 정당한 근거 없이 무조건 대치/변환 금지

### V04 — Fried·CRP·IL-6 대안은 이 자료에서 실제 계산 가능한가?

- 산출물: `runs/V04/alternative-availability.json`, `runs/V04/alternative-scope.md`
- 검수: 필요 항목/주기 가용성 확인; 없음을 열람으로 입증; CRP/IL-6를 동등 지표로 단정하지 않음; 비교 필요성·실행 여부 결정

### G01 — 과제 결과의 흐름·검정·도표·근거가 일관되는가?

- 산출물: `runs/G01/audit-findings.json`, `runs/G01/requirement-evidence.json`
- 검수: 필수 항목마다 실제 파일/로그/해시 대조; 값/분모/축/가족/실패 확인; 미완료를 완료로 승격하지 않음

### G02 — 과제·재현·방법 검증의 결론과 남은 한계를 어떻게 분리 보고하는가?

- 산출물: `runs/G02/final-report.md`, `runs/G02/completion-matrix.json`, `runs/G02/submission-manifest.json`
- 검수: 필수 C/M 충족 확인; A와 V는 수행 상태/선택 제외 이유를 별도로 수집; 재현 미실행을 성공으로 쓰지 않음; 재실행 명령·환경·근거 포함

## 학습자료의 제안이 배정된 곳

| 학습 단계 | 실행에서 해결할 사항 | 담당 |
|---|---|---|
| 01 한 행·변수 역할 | ID·주기 병합, 연속/범주, 흡연 등 조작적 정의 | S02–S03 |
| 02 CBC 지표 | 단위·분모·지표 공유 성분·CRP/IL-6 비교 가능성 | S03, M02, V04 |
| 03 FI·Fried·이분화 | FI 코딩/분모, 측정법 이유, 점수 모형·기준 민감도 | S04, V01, V04 |
| 04 표본·결측·설계 | 50세 적용 대상, 음주 결측, 주기별 가중치·PSU·층 | S05, A01, V03 |
| 05 Table 1 | weighted 각주 충돌·본문/표 불일치·분포 요약 | S01, S06, A02, C02 |
| 06 OR | 결과와 단위·log 밑·OR/확률 구별 | B01, A01–A02, G01 |
| 07 전처리·가정 | 정규성 이유와 실제 가정, log·극단값·수렴 | S03, B01, C05, V03 |
| 08 공변량 | Model 1/2 재적합, 구성 항목과 공변량 중복 | A02, V02 |
| 09 사분위 | FI군과 염증지표군 구별, 동점·가중 분위수·경향 점수 | A01, C01, C04 |
| 10 곡선·상호작용·민감도 | 미보고 RCS 설정, 본문/그림 충돌, 과도한 보정 | A03, V02, G01 |

Fried나 CRP 자료가 없으면 없는 근거와 확보 필요성을 보고합니다. 분석 가능한 척하지 않습니다. 선택 확장은 실행 여부를 판단하는 것까지가 최소 과업이며 실제 재분석에는 추가 자료와 계획이 필요합니다.
