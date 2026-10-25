# 진단·영향점·민감도 — 논문·실제 데이터 적용 (paper)

학습 단계: HR05 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

이번 잔차·Q–Q·Cook·한 명씩 제외하는 분석은 과제의 추가 진단입니다. 원문에서 동일한 진단 결과를 보고했다고 주장하지 않습니다. 주 분석 22명씩은 그대로 두고 관측 하나에 대한 민감도를 확인했습니다.

## 이번 구현의 선택과 이유

기기별 22개 제외 시나리오, 총 88개 보조 적합에서 상관·기울기 등의 범위를 저장했습니다. 더 높은 r를 만드는 시나리오를 최종 결과로 고르지 않았습니다. 오차~두 측정 평균 진단선도 크기 의존성을 살피는 보조 요약입니다.

## 출력·검토 결과

아래 범위와 그림은 실제 저장된 전체·제외 시나리오 결과입니다. STYLE1의 축·기기명·ID 표시 수정은 같은 잔차 CSV를 다시 그린 서식 수정이며 통계 재적합은 없었습니다. 수치와 최초 그림은 run 안에 보존됩니다.

## 남은 의문과 다음 단계

S03–S05에 연결됩니다. 작은 표본의 진단은 정규성·등분산·외부 예측을 입증하지 못합니다. 원문과의 차이는 다음 단계에서 같은 정의·통계 종류인지 먼저 대조합니다.

## 실제 산출물

| 기기 | 한 명씩 제외 r 범위 | 기울기 범위 | 가장 큰 r 변화 ID |
| --- | --- | --- | --- |
| Apple Watch | 0.944 ~ 0.985 | 0.911 ~ 0.998 | 14 |
| Fitbit Charge HR | 0.747 ~ 0.874 | 0.561 ~ 0.725 | 20 |
| Samsung Gear S | 0.697 ~ 0.797 | 0.641 ~ 0.770 | 1 |
| Mio Alpha | 0.848 ~ 0.915 | 0.908 ~ 1.000 | 10 |


출처 근거: analyst supplemental diagnostics; frozen R1 tables and STYLE1 rendering manifest

원본 결과: analysis/runs/R1-20261024/tables/observation_diagnostics.csv, analysis/runs/R1-20261024/tables/sensitivity_summary.csv

그림: 04_regression_residuals.png, 05_residual_qq.png, 06_leave_one_out.png

문제 ID: S03, S04, S05

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 05-concept 진단·영향점·민감도.md
