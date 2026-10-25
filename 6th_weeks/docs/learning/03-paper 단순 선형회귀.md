# 단순 선형회귀 — 논문·실제 데이터 적용 (paper)

학습 단계: HR03 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

이번 과제는 각 시계 평균을 y, 동시 ECG 평균을 x로 둔 단순 OLS를 기기마다 적합했습니다. 질문은 관측 범위에서의 평균적 관계입니다. ECG를 시계로부터 예측하는 외부 보정 성능을 평가한 분석은 아닙니다.

## 논문 방법과 이번 과제의 구분

원문도 회귀를 사용하지만 차이·일치한계를 두 측정의 평균과 연결하는 Bland–Altman 회귀 맥락입니다. 여기의 시계~ECG 단순 OLS, 계수 CI·적합 R²는 과제 구현입니다. 이 결과를 원문의 동일 회귀계수 재현이라고 쓰지 않습니다.

## 이번 구현의 선택과 이유

R lm으로 절편을 포함해 22명 모두 적합했습니다. 산점도에는 OLS와 y=x, 평균반응 95%CI를 함께 그렸습니다. R²=r²를 수식 검산했으며 평균반응 음영을 개인 예측구간으로 해석하지 않았습니다.

## 출력·검토 결과

아래 실제 회귀식은 ECG가 100bpm일 때의 적합 평균도 보여 줍니다. 적합도가 높아도 y=x와 차이가 있으면 측정값의 일치는 별도로 확인해야 합니다. 회귀선 그림은 직전 산점도 패널과 공유합니다.

## 남은 의문과 다음 단계

S02·S05에 연결됩니다. ECG도 완전한 무오차 참값이라고 입증한 것은 아니며 작은 표본·공유 참가자·외부 평가 부재가 남습니다. 잔차 진단은 후속 보조 단계이고, 수치가 좋아지도록 표본을 삭제하지 않았습니다.

## 실제 산출물

| 기기 | 회귀식 (시계 = a + b×ECG) | 기울기 95%CI | R² | ECG100에서 적합값 |
| --- | --- | --- | --- | --- |
| Apple Watch | 6.33 + 0.926 × ECG | 0.788 ~ 1.063 | 0.908 | 98.89 |
| Fitbit Charge HR | 27.01 + 0.644 × ECG | 0.428 ~ 0.860 | 0.659 | 91.39 |
| Samsung Gear S | 22.19 + 0.709 × ECG | 0.411 ~ 1.007 | 0.551 | 93.09 |
| Mio Alpha | 1.17 + 0.946 × ECG | 0.696 ~ 1.196 | 0.757 | 95.77 |


출처 근거: course extension: device~ECG OLS; distinguish paper Statistical analysis / Bland–Altman regression

원본 결과: analysis/runs/R1-20261024/tables/device_summary.csv, analysis/runs/R1-20261024/tables/observation_diagnostics.csv

그림: 01_scatter_regression.png

문제 ID: S02, S05

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 03-concept 단순 선형회귀.md
