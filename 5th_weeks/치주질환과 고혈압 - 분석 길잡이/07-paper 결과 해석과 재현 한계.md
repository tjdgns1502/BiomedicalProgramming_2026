# 결과 해석과 재현 한계 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

이 프로젝트의 기준 원본은 본 Obsidian 호환 폴더의 concept/paper 파일입니다. 별도 HTML·최종 보고서를 만들지 않고 해당 단계의 구현·비교·검토·갱신 해석에 실행 결과를 반영합니다.

상류 자료·코딩·표본·가중치 변경은 downstream task/run/그림/문서를 stale로 표시합니다. 새 run_id에 재실행하고 정확한 버전으로 재검토합니다. 출판표의 모든 본문·보충 항목은 output_coverage.json에서 상태를 추적합니다.

**ISSUE-12:** 정의와 분모가 바뀐 분석 사이 일관성(implementation). 사용자께서 지적한 이전 FI/ANOVA 일관성 문제를 방지하기 위해 data→table→model→figure→note 의존 관계와 해시를 확인합니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

R-CAT-001 / `R2-20261004` / plan1.1 → R-EXT-002 / `E1-20261004` / plan1.4 → R-REPAIR-003 / `E2-20261004` / plan1.5. 주 후보 21,458명(고혈압10,689, 비고혈압10,769)를 공통 분모로 사용합니다. 상류 core 자료해시를 확장 실행이 확인하고 동일 사람의 코딩을 재사용했습니다. E1 원시 검사값 실행을 보존하고 E2에서 CDC 검사법 보정을 적용했습니다. 영향을 받지 않는 M1/M2의 재사용 출처와 모든 M3 하류 재계산을 기록했습니다.

필수 항목→stage→task→run→검토→표/그림→본 노트 경로를 output_coverage에 연결했습니다. 모든 초기 설명과 의문은 위에 보존하고 계산·검토를 해당 단계에 반영했습니다.

## 재현 비교

재현 판정: **부분 재현**. 기본 n과 선택/결측·공변량 후보가 다르며 모든 출판 수치가 반올림 오차 안에 일치하지 않습니다. 저자 설정 확인: **일부 확인/일부 식별 불가**. 계산 정확성의 독립 검토와 저자 설정의 확인을 구별합니다.

## 검토·추가 분석

| 검토 기록 | 판정 | 해시 |
| --- | --- | --- |
| [reviews/E1-20261004-q-review.json](../analysis/reviews/E1-20261004-q-review.json) | accept | cab140030972447f |
| [reviews/E1-data-review.json](../analysis/reviews/E1-data-review.json) | accept | 51c9554f0369a877 |
| [reviews/E2-20261004-data-review.json](../analysis/reviews/E2-20261004-data-review.json) | accept | 4295b25581cb19c8 |
| [reviews/E2-20261004-q-review.json](../analysis/reviews/E2-20261004-q-review.json) | accept | cf2095a869d7048e |
| [reviews/E2-plan1.5-code-q-review.json](../analysis/reviews/E2-plan1.5-code-q-review.json) | accept | e1d0fbb7210659c8 |
| [reviews/R2-20261004-q-review.json](../analysis/reviews/R2-20261004-q-review.json) | accept | e2336b63af67a54d |
| [reviews/R2-data-review.json](../analysis/reviews/R2-data-review.json) | accept | 74fd2969ca0efe26 |
| [reviews/V1-20261004-q-review.json](../analysis/reviews/V1-20261004-q-review.json) | accept | 7f2fc4957e3e1aed |

[비교·출처 해시](../analysis/comparisons/E2-20261004/comparison_manifest.json) / [산출물 coverage](../analysis/memory/output_coverage.json) / [확장 계획](../analysis/config/plan-v1.5.json)

노출 이력: 원문 정의를 확인할 때 구현자·검토자도 출판 수치가 포함된 웹 응답을 읽었습니다. 별도 인스턴스의 독립 감사이지만 맹검이라고 부르지 않습니다. 저자 결과값에 맞추기 위한 후보 탐색·변경은 하지 않았습니다. 검사법 보정은 공식 측정체계 근거에 따른 정의 수정이며 새 상류 정의에서 관련 하류 결과를 모두 갱신했습니다.

## 갱신된 해석

ISSUE-12 해결 범위: 주 분석과 하위집단·그림은 같은 검토된 자료 정의를 공유하고, 식이 민감도·보충표의 다른 분모는 별도 ID로 명시했습니다. 원자료와 run을 덮어쓰지 않았으며 R1 실패도 보존했습니다. 학습 결과는 연관과 통계 구조를 이해하고 후보 구현을 재실행할 수 있는 수준입니다. 인과효과나 저자의 미공개 코드를 확정한 결과가 아닙니다.

반영 시점: 2026-10-04T08:05:56.540689+00:00. 자료 버전 `nhanes-2009-2018-harmonizedJ-d8f04b7c96c89c31956a`; core는 `nhanes-2009-2018-7ad570c1e84a460b267c`.
