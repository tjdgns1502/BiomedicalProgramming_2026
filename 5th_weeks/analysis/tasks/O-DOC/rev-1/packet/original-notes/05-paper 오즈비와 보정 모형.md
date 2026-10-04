# 오즈비와 보정 모형 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

Table2 Model1은 나이·성별·인종·교육을 보정합니다. 치주질환 Yes의 출판 OR는 M1 1.35(1.22–1.49), M2 1.20(1.08–1.34), M3 1.21(1.09–1.35)입니다. 첫 모형을 crude로 부르면 안 됩니다.

M2는 BMI·수면·음주·활동·CVD·당뇨·나트륨·지방을 추가하고 M3는 TC·creatinine·TG·HbA1c·HDL을 추가합니다. 결측은 범주/지시변수로 처리했다고 쓰지만 연속값 대체 규칙은 미공개입니다. Table3 각주는 다르게 구성되어 별도로 검토합니다.

**ISSUE-07:** 숨은 공변량 구현/가중치/결측 처리(replication_config). **ISSUE-08:** 교란·측정오류·역인과·비축약성(statistical_validity). 출판값에 가까운 후보를 통계적 개선으로 선택하지 않습니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

계획 검토 후 실행 대기.

## 재현 비교

아직 실증 검토 전입니다.

## 검토·추가 분석

아직 결과 없음.

## 갱신된 해석

최초 설명은 검증 완료 판정이 아닙니다.
