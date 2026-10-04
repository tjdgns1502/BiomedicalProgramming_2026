# 선정 결측과 복합표본 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

기본 설계는 WTMEC2YR/5, SDMVSTRA, SDMVPSU, nest=TRUE입니다. DEMO를 기준으로 각 주기의 OHQ/BPQ/BPX/SMQ를 SEQN one-to-one로 연결합니다. SEQN을 다른 주기와 임의로 섞지 않습니다. 원자료는 analysis/data/raw에 불변으로 저장하고 SHA256을 기록합니다.

원문은 혈압 결측19,398명과 흡연/구강상태/치주질환 결측1,090명 제외를 제시하지만 시작 표본과 자세한 순서를 충분히 공개하지 않았습니다. 두 제외 수와 최종 n을 더해 최초 모집 표본으로 단정하지 않습니다.

**ISSUE-04:** 원문 선정 flow와 재현 분모 차이(replication_config). **ISSUE-05:** 영양·TG 구성요소에 맞는 가중치(statistical_validity). 식이 day1은 WTDRD1, fasting TG는 WTSAF2YR가 관련됩니다. 본문 가중치 종류와 TG 변수가 미공개라 확인된 MEC 분석과 추가 후보를 구분합니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

계획 검토 후 실행 대기.

## 재현 비교

아직 실증 검토 전입니다.

## 검토·추가 분석

아직 결과 없음.

## 갱신된 해석

최초 설명은 검증 완료 판정이 아닙니다.
