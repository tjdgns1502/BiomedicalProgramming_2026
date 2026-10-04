# 한 사람의 원자료와 코딩 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

OHQ835=자가인지 gum disease: 1 Yes,2 No,7/9 결측. OHQ845=치아·잇몸 전반 상태: 1 Excellent와2 Very good를 합쳐 기준군,3 Good,4 Fair,5 Poor. RIDAGEYR는 연령, RIAGENDR 성별, RIDRETH1 5범주 인종, DMDEDUC2 1/2 <고졸,3 고졸,4/5 >고졸입니다.

고혈압은 BPQ020 진단 Yes 또는 BPQ050A 현재 약물 Yes 또는 평균 SBP≥140/DBP≥90으로 정의합니다. 평균은 1–4회 가용 측정을 사용합니다. 주 후보는 SBP>0, DBP≥0을 유효값으로 하며 각각 한 개 이상을 요구합니다. 이 상세 규칙은 analyst_assumption이며 저자와 완전히 동일한 구현이라고 주장하지 않습니다.

**ISSUE-02:** 평균과 약물 skip 처리(replication_config). **ISSUE-03:** 흡연 yes/no의 ever/current 정의 미공개(replication_config). 기본 후보 SMQ020 100개비 평생흡연을 사용하며 현재흡연과 구별합니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

계획 검토 후 실행 대기.

## 재현 비교

아직 실증 검토 전입니다.

## 검토·추가 분석

아직 결과 없음.

## 갱신된 해석

최초 설명은 검증 완료 판정이 아닙니다.
