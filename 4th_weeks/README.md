# 4주차 — 다군 비교·다중검정과 염증–노쇠 논문 재현

`doyun`의 로컬 분석 코드, 저장된 결과, 검토 기록, 실행 프롬프트와 Obsidian 학습 문서입니다. 이 업로드는 기존 실행의 공유용 스냅샷이며 새 분석을 실행한 것이 아닙니다.

논문: Han et al. (2024), *Correlations between frailty index and inflammatory markers derived from blood cell count in the United States*. [원문과 보충자료](https://pmc.ncbi.nlm.nih.gov/articles/PMC11653688/), DOI: 10.1186/s12889-024-20908-9.

## 먼저 읽을 파일

- [학습 문서 시작](4주차/염증과%20노쇠%20-%20분석%20길잡이/00-start%20처음부터%20따라가는%20분석%20흐름.md): 개인 원자료에서 표·그림까지, 통계 개념과 논문 적용을 구분한 설명. Obsidian에서 폴더를 열면 위키 링크와 Mermaid를 읽기 쉽습니다.
- [실행 안내](analysis/README.md): 환경과 다운로드·분석 명령.
- [오케스트레이션 실행 프롬프트](frailty-agent-workflow/docs/05-prompts.md): 역할, 독립성, 작업 명세, 검토와 기록 규칙. 자동 실행 서버는 아닙니다.
- [현재 논문 분석 출력 목록](analysis/tasks/V3-I01/rev-1/work/coverage_manifest.json)과 [독립 검토](analysis/tasks/V3-Q01/rev-1/work/result_review.json).

## 과제 분석과 논문 분석의 버전 구분

| 분석 | FI·표본 | 질문과 결과 위치 |
|---|---|---|
| 초기 과제 A01 | 초기 완전36항목 후보, 실제 분석 9,786명 | FI 사분위군별 염증지표 비교: [ANOVA/Welch/KW](analysis/runs/A01-groups/omnibus.csv), [24개 쌍별 비교](analysis/runs/A01-groups/pairwise.csv), [Tukey](analysis/runs/A01-groups/tukey.csv), [경향성](analysis/runs/A01-groups/trend.csv) |
| 초기 민감도 A02/A03 | 초기 FI 후보 | 연령·FI 절단값·fractional·코딩 민감도: [A02](analysis/runs/A02-models/), [A03](analysis/runs/A03-coding/) |
| 최신 논문 후보 V3 | 설문 분기를 반영한 complete36, 참조 표본 13,252명, Model 2 10,874명 | [회귀](analysis/tasks/V3-I01/rev-1/work/continuous_models.csv), [비선형성](analysis/tasks/V3-I01/rev-1/work/spline_tests.csv), [상호작용](analysis/tasks/V3-I01/rev-1/work/interactions.csv), Table 1·3 및 보충 분석 |

**A01 ANOVA를 최신 V3 FI로 다시 실행한 상태는 아닙니다.** 두 결과를 동일 표본·동일 FI 분석처럼 합치면 안 됩니다. 새 FI가 과제 군 비교에 미치는 영향은 후속 검토 사항입니다. 이 버전 차이를 숨기거나 기존 결과를 새 실행으로 덮어쓰지 않습니다.

Welch가 과제 주검정이고 일반 ANOVA와 Kruskal–Wallis는 비교용입니다. 과제 군 비교는 FI로 군을 나누며, 논문 회귀는 염증지표로 노쇠 여부를 설명합니다. 인과효과 또는 저자의 정확한 FI 복원을 입증하지 않았습니다.

## 모의실험과 그림

- [M01](analysis/runs/M01-simulation/): 다중검정 원리, 독립/상관 조건, B=10,000.
- [M02](analysis/runs/M02-procedure/): 실제 군 비교 코드를 이용한 검정 절차 모의실험, 조건당 B=2,000. 모든 조건에서 명목 유의수준이 유지된 것은 아닙니다.
- [과제 상자그림](analysis/runs/A01-groups/boxplots.png), [평균과 CI](analysis/runs/A01-groups/means_with_pointwise_CI.png).
- [최신 곡선](analysis/tasks/V3-I01/rev-1/work/Figure2_Model2_curves.png), [하위집단 그림](analysis/tasks/V3-I01/rev-1/work/Figure3_subgroup_forest.png).

## 실행 환경과 포함 범위

작업 디렉터리를 이 `4th_weeks/`로 두고 `analysis/README.md`를 따릅니다. 기존 환경은 Windows, R 4.6.1, survey 4.5이며 Python은 `uv`를 사용합니다. 개인 PC의 R 실행 경로는 다른 환경에서 수정해야 합니다. 최초 실행 환경·로그·해시는 당시 기록으로 보존되어 로컬 절대경로를 포함할 수 있습니다.

원자료 XPT, 개인별 파생 CSV, RDS 중간객체, 다운로드된 논문/보충자료, 임시파일과 백업은 제외했습니다. 원자료는 다운로드 코드로 재생성합니다. V3 실행은 추가 입력과 준비 과정도 필요하므로 해당 작업의 packet, prepare.R, 실행 기록을 함께 확인해야 합니다. 다른 컴퓨터에서 전체 파이프라인의 재실행을 검증한 패키지는 아닙니다.

학습 문서에 남아 있는 원논문 PDF·보충 DOCX 링크는 위 원문에서 별도로 받아 연결해야 합니다. 로그·검토 manifest가 가리키는 제외된 대용량 파일은 업로드 누락 오류가 아니라 재생성 대상입니다. 과거 검토 해시는 당시 전체 로컬 산출물 기준이며, 공유 파일 목록·해시는 `publication_manifest.json`에 있습니다.

## 남은 한계

FI의 미공개 점수화·결측 규칙, 정확한 저자 표본, 원래 스플라인 설정은 미확인입니다. 현재 후보의 결과 일치/불일치만으로 논문 오류를 확정하지 않습니다. 독립 검토는 주요 모형 재적합과 수치 검사를 포함하지만 모든 모형의 과학적 타당성을 보증하지 않습니다. 실행 프롬프트의 목표와 실제 수행 범위를 구별해서 읽어야 합니다.
