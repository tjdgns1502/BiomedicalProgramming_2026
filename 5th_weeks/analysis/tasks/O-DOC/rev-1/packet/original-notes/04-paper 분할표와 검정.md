# 분할표와 검정 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

Table1의 n은 비가중, %는 고혈압 상태별 가중 백분율입니다. 출판된 치주질환 분할표는 Yes: 비고혈압1905/고혈압2178; No:8878/8839입니다. 두 열의 분모는10783과11017이며 전체21800명입니다.

동일한 원자료에서 비가중 2×2/4×2표, 고혈압 열별 가중%, Pearson/Yates/Fisher 교육 비교와 Rao–Scott 설계 기반 검정을 계산합니다. 원문은 survey χ²라고만 적고 보정 구현 상세를 충분히 적지 않았습니다.

**ISSUE-06:** 독립 표집 검정과 복합표본 추론 구별(statistical_validity). 원문 표 n을 이용한 일반 Fisher 결과는 NHANES 모집단 추론을 재현한 결과가 아닙니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

계획 검토 후 실행 대기.

## 재현 비교

아직 실증 검토 전입니다.

## 검토·추가 분석

아직 결과 없음.

## 갱신된 해석

최초 설명은 검증 완료 판정이 아닙니다.
