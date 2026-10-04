# 선정 결측과 복합표본 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

기본 설계는 WTMEC2YR/5, SDMVSTRA, SDMVPSU, nest=TRUE입니다. DEMO를 기준으로 각 주기의 OHQ/BPQ/BPX/SMQ를 SEQN one-to-one로 연결합니다. SEQN을 다른 주기와 임의로 섞지 않습니다. 원자료는 analysis/data/raw에 불변으로 저장하고 SHA256을 기록합니다.

원문은 혈압 결측19,398명과 흡연/구강상태/치주질환 결측1,090명 제외를 제시하지만 시작 표본과 자세한 순서를 충분히 공개하지 않았습니다. 두 제외 수와 최종 n을 더해 최초 모집 표본으로 단정하지 않습니다.

**ISSUE-04:** 원문 선정 flow와 재현 분모 차이(replication_config). **ISSUE-05:** 영양·TG 구성요소에 맞는 가중치(statistical_validity). 식이 day1은 WTDRD1, fasting TG는 WTSAF2YR가 관련됩니다. 본문 가중치 종류와 TG 변수가 미공개라 확인된 MEC 분석과 추가 후보를 구분합니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

R-CAT-001 / `R2-20261004` / plan1.1 → R-EXT-002 / `E1-20261004` / plan1.4 → R-REPAIR-003 / `E2-20261004` / plan1.5. 주 후보 21,458명(고혈압10,689, 비고혈압10,769)를 공통 분모로 사용합니다. 상류 core 자료해시를 확장 실행이 확인하고 동일 사람의 코딩을 재사용했습니다. E1 원시 검사값 실행을 보존하고 E2에서 CDC 검사법 보정을 적용했습니다. 영향을 받지 않는 M1/M2의 재사용 출처와 모든 M3 하류 재계산을 기록했습니다.

| 선정 단계 | n | 직전 단계에서 제외 |
| --- | --- | --- |
| all_demo | 49,693 | — |
| age30 | 24,042 | 25651 |
| valid_measured_sbp_dbp | 22,163 | 1879 |
| observed_periodontal | 21,515 | 648 |
| observed_oral_health | 21,488 | 27 |
| observed_smoking | 21,476 | 12 |
| observed_hypertension | 21,458 | 18 |
| positive_mec_weight_valid_design | 21,458 | 0 |


## 재현 비교

| 집단 | 논문 n | 계산 n | 차이 |
| --- | --- | --- | --- |
| 전체 | 21800 | 21458 | -342 |
| 비고혈압 | 10783 | 10769 | -14 |
| 고혈압 | 11017 | 10689 | -328 |

비가중 고혈압 비율은 49.81%, 설계 가중 비율은 44.92%입니다. 이 두 비율은 분모와 표집 의미가 다릅니다.

## 검토·추가 분석

전체 양의MEC 가중치47,652명에서 design을 만든 뒤 대상자를 subset했습니다. 원래 SDMVSTRA/SDMVPSU를 보존했고 설계 자유도78을 확인했습니다. B는 양의 식이 day1 가중치 design을 먼저 만들고 신뢰 가능한 식이 응답 영역을 subset한 **dietary-weight sensitivity**입니다. A/B는 표본·가중치가 함께 달라지므로 숫자 차이를 방법의 우열로 판정하지 않습니다. 공변량 연속결측 대체값과 flag는 [결측 지시변수 기록](../analysis/runs/E2-20261004/tables/continuous_missing_indicators.csv)에 모두 기록했습니다.

## 갱신된 해석

ISSUE-04 미해결: 최종 표본수 차이와 저자의 제외 흐름은 정확히 일치하지 않습니다. ISSUE-05 부분 해결: 필요한 가중치의 공식 지침은 확인했고 A와B를 분리 실행했습니다. 범주/지시변수 방식은 저자 구현 후보이며 결측 편향을 해결한 것으로 간주하지 않습니다.

반영 시점: 2026-10-04T08:05:56.540689+00:00. 자료 버전 `nhanes-2009-2018-harmonizedJ-d8f04b7c96c89c31956a`; core는 `nhanes-2009-2018-7ad570c1e84a460b267c`.
