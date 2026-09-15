# NHANES WWI-Stroke Table 1 재현

Ye et al. 2023 (BMC Public Health), *"Association between the weight-adjusted waist index and stroke: a cross-sectional study"* 의 **Table 1**을 NHANES 2011-2020 원자료로 직접 재현하는 프로젝트입니다.

## 실행 순서

작업 디렉터리를 `2nd_weeks/`로 맞춘 뒤 실행하세요 (스크립트 내 경로가 `2nd_weeks/` 기준 상대경로입니다).

```r
source("scripts/01_download_data.R")   # NHANES 4개 cycle(G/H/I/P) 원자료 다운로드 (CDC 서버, ~82MB)
source("scripts/02_build_table1.R")    # 병합 + 변수 생성 + 제외기준 적용 -> data/analytic_sample.rds
source("scripts/03_table1_stats.R")    # survey 패키지로 가중 Table 1 계산 -> output/table1.csv
source("scripts/11_qqplot_theory.R")   # WWI Q-Q plot + 이론분위수 공식 검증 -> output/qqplot_wwi.png
```

`scripts/04~10_*.R`은 논문 수치와의 차이를 추적한 진단 스크립트입니다(N 불일치, 당뇨/음주 변수 코딩, 공복 가중치 검증 등). 실행 순서와 무관하게 각 파일 상단 주석에 검증 목적이 적혀 있습니다.

## 핵심 결과

- 최종 N = 23,389 (paper와 정확히 일치), 뇌졸중 이벤트 893명 일치, WWI 사분위 경계값(10.51/11.09/11.67) 일치.
- 대부분의 변수(연령, 성별, 인종, 교육수준, 흡연, 고혈압, 관상동맥질환, 암, BMI, 허리둘레, PIR, 체중, HDL-C, 총콜레스테롤)가 paper와 소수점 한두 자리 이내로 일치.
- **당뇨병**: DIQ010의 "borderline(=3)"을 Yes로 포함해야 paper·팀원 값과 일치함을 확인.
- **음주량**: paper는 ALQ130의 결측코드(777/999)를 정제하지 않고 그대로 평균에 포함시킨 것으로 추정됨(동일하게 재현하면 평균·SD·유의성 모두 일치).
- **중성지방/LDL-C**: 공복 서브샘플 전용 가중치(WTSAF2YR/WTSAFPRP)를 적용해도 paper와의 잔차가 해소되지 않음 — paper의 미기재 처리 방식으로 추정, 팀원 재현치와는 일치.

자세한 진단 과정과 근거는 대화 로그 및 `scripts/02_build_table1.R` 내 주석 참고.

## 데이터

`data/` 안의 NHANES 원자료(XPT)와 병합 결과(`analytic_sample.rds`)는 용량 문제로 git에 포함하지 않았습니다(`.gitignore` 처리). `01_download_data.R` → `02_build_table1.R`을 실행하면 누구나 동일하게 재현할 수 있습니다. `output/table1.csv`, `output/qqplot_wwi.png`는 용량이 작아 결과 확인용으로 git에 포함했습니다.

## v2 업데이트 (거의 완전 재현)

teammate의 독립 재현(`Teammate_analysis/`)과 대조해 3가지를 더 고쳐 132개 셀 대부분이 논문과 완전히 일치하는 버전을 추가했습니다. 위 v1 스크립트/결과는 그대로 두고, 새 파일로 분리했습니다:

- `scripts/12_build_table1_v2.R`, `scripts/13_table1_stats_v2.R` → `output/table1_v2.csv`
- 무엇이, 왜 바뀌었는지는 [`CHANGES_v2.md`](CHANGES_v2.md) 참고.
