# 분할표와 검정 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

Table1의 n은 비가중, %는 고혈압 상태별 가중 백분율입니다. 출판된 치주질환 분할표는 Yes: 비고혈압1905/고혈압2178; No:8878/8839입니다. 두 열의 분모는10783과11017이며 전체21800명입니다.

동일한 원자료에서 비가중 2×2/4×2표, 고혈압 열별 가중%, Pearson/Yates/Fisher 교육 비교와 Rao–Scott 설계 기반 검정을 계산합니다. 원문은 survey χ²라고만 적고 보정 구현 상세를 충분히 적지 않았습니다.

**ISSUE-06:** 독립 표집 검정과 복합표본 추론 구별(statistical_validity). 원문 표 n을 이용한 일반 Fisher 결과는 NHANES 모집단 추론을 재현한 결과가 아닙니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

R-CAT-001 / `R2-20261004` / plan1.1 → R-EXT-002 / `E1-20261004` / plan1.4 → R-REPAIR-003 / `E2-20261004` / plan1.5. 주 후보 21,458명(고혈압10,689, 비고혈압10,769)를 공통 분모로 사용합니다. 상류 core 자료해시를 확장 실행이 확인하고 동일 사람의 코딩을 재사용했습니다. E1 원시 검사값 실행을 보존하고 E2에서 CDC 검사법 보정을 적용했습니다. 영향을 받지 않는 M1/M2의 재사용 출처와 모든 M3 하류 재계산을 기록했습니다.

| 자가보고 치주질환 | 비고혈압 n (가중%) | 고혈압 n (가중%) |
| --- | --- | --- |
| No | 8861 (83.46%) | 8574 (80.06%) |
| Yes | 1908 (16.54%) | 2115 (19.94%) |


## 재현 비교

출판 분할표와 계산 표는 서로 다른 선정분모입니다. 원문 n은 비가중, %는 설계가중입니다. 전체 공변량의 기술표를 계산했고 [Table1 범주 비교](../analysis/comparisons/E2-20261004/table1_categorical_comparison.csv)와 [Table1 평균·SE 비교](../analysis/comparisons/E2-20261004/table1_continuous_comparison.csv)에 연결했습니다. HbA1c LBXGH는 %이며 원문의 mg/dl 표기와 구별합니다.

## 검토·추가 분석

| 검정 | 통계량 | p |
| --- | --- | --- |
| Naive Pearson chi-square | 15.077 | 0.000103196 |
| Survey Rao-Scott adjusted F | 26.885 | 1.65716e-06 |
| Naive Yates chi-square (2x2 only) | 14.942 | 0.00011088 |
| Fisher exact conditional MLE (2x2 only) | — | 0.00011053 |

![[assets/R2-20261004/naive_periodontal_mosaic_residual.png]]

자가보고 치주질환×고혈압. 21,458명 비가중 탐색용 모자이크·Pearson 잔차. 모집단 검정은 표의 Rao–Scott F를 사용합니다. 각 셀의 색은 독립 기대빈도에서의 방향과 차이를 나타냅니다.
![[assets/R2-20261004/naive_oral_health_mosaic_residual.png]]

구강상태4범주×고혈압, 동일 21,458명 비가중 탐색. 셀 n·기대빈도·잔차는 pearson_cell_diagnostics.csv에 연결됩니다.


## 갱신된 해석

ISSUE-06 해결 범위: 일반 Pearson/Yates/Fisher를 교육용 비교, Rao–Scott를 설계 기반 추론으로 구분했습니다. p가 더 작다는 이유로 더 좋은 검정을 선택하지 않습니다. 방향·효과 크기·설계·불확실성을 함께 읽어야 합니다. 연속변수 비교 CSV의 naive Welch t는 No−Yes, survey t는 Yes−No 방향이므로 부호가 반대일 수 있습니다. 양측 p는 방향 반전의 영향을 받지 않습니다.

반영 시점: 2026-10-04T08:05:56.540689+00:00. 자료 버전 `nhanes-2009-2018-harmonizedJ-d8f04b7c96c89c31956a`; core는 `nhanes-2009-2018-7ad570c1e84a460b267c`.


원문 Table1 출처 점검: 고혈압 남성5,412+여성5,606=11,018명으로 표의 총계11,017명과1명 다릅니다. 단순 산술 불일치이며 어느 셀이 맞는지는 저자 코드 없이 확정하지 않습니다. 원문 당뇨 No732/1,232 및 Missing9,177/6,913은 DIQ010 후보와 크게 다르므로 저자의 실제 문항·결측 매핑은 미확인으로 남깁니다. 출판 수치를 맞추기 위해 원자료 응답을 변경하지 않았습니다. [공식 정의·출처 감사](../analysis/reviews/source-definition-audit.md)에 근거를 기록했습니다.
