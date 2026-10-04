# 통계 검증 과제 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

과제 확장 V-FISHER는 논문 자료를 생성한 실험이 아닙니다. 독립 이항표집 n=5/10/20/50과 null p=.05/.2/.5에서 Fisher/Pearson/Yates 기각확률을 확인합니다. all-zero/all-success는 정보 없는 표로 비기각 처리합니다. 실제 분석 코드의 Fisher 규칙과 동일한 양측 probability-ordering을 사용합니다.

V-EFFECT는 원문/재현 crude 표의 OR와 PR를 비교하고 baseline prevalence 곡선을 만듭니다. 원문 adjusted OR를RR로 해석하지 않습니다. V-PAIRED는 강의의 가상100명 표(40,25;5,30)를 사용하며 실제 NHANES 분석과 구분합니다.

**ISSUE-09:** Fisher의 명목 .05와 실제 기각확률(assignment_extension). **ISSUE-10:** 흔한 결과에서 OR 오해(assignment_extension). **ISSUE-11:** paired structure 부재(McNemar 실제 적용 not_applicable).

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

계획 검토 후 실행 대기.

## 재현 비교

아직 실증 검토 전입니다.

## 검토·추가 분석

아직 결과 없음.

## 갱신된 해석

최초 설명은 검증 완료 판정이 아닙니다.
