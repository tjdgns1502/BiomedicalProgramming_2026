# 측정오차·일치도 — 논문·실제 데이터 적용 (paper)

학습 단계: HR04 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

이번 계산은 시계−ECG를 오차로 고정했습니다. 네 기기에 대해 22쌍씩 bias·MAE·RMSE·오차 SD·평균오차 t CI·MAPE와 고정 Bland–Altman LoA를 계산했습니다. 음수는 이 정의에서 과소추정입니다.

## 논문 방법과 이번 구현의 구분

원문은 Bland–Altman 일치도를 다룹니다. 특히 Mio의 상·하한은 평균 크기의 함수로 제시되어 있습니다. 이번 고정 LoA·MAE·RMSE·공통 구간 히스토그램은 과제의 기술·보조 분석이며 원문의 가변 한계까지 완전히 재현한 결과가 아닙니다.

## 출력·검토 결과

아래 실제 결과에서 네 기기의 표본 bias는 음수였습니다. Apple도 bias가 비교적 작다는 사실만으로 순간 측정이나 임상 사용에서 오차가 없다고 할 수 없습니다. 같은 축의 오차 분포와 차이 대 평균 그림을 함께 확인합니다.

## 남은 의문과 다음 단계

S02·S03·C03에 연결됩니다. 집계된 평균의 오차이고 임상 허용 기준은 정하지 않았습니다. 고정 LoA의 분포 가정과 크기 의존성은 진단을 통해 제한을 점검하되 불확실성이 해소되었다고 단정하지 않습니다.

## 실제 산출물

| 기기 | n | Pearson r | r의 95%CI | 평균오차 bpm | MAE bpm | RMSE bpm |
| --- | --- | --- | --- | --- | --- | --- |
| Apple Watch | 22 | 0.953 | 0.888 ~ 0.981 | -1.26 | 2.53 | 4.46 |
| Fitbit Charge HR | 22 | 0.812 | 0.594 ~ 0.919 | -9.32 | 10.55 | 12.47 |
| Samsung Gear S | 22 | 0.743 | 0.467 ~ 0.887 | -7.05 | 9.74 | 12.25 |
| Mio Alpha | 22 | 0.870 | 0.709 ~ 0.945 | -4.34 | 4.81 | 8.28 |

| 기기 | 평균오차 | 평균오차 95%CI | 오차 SD | 고정 LoA 하한 | 고정 LoA 상한 | MAPE % |
| --- | --- | --- | --- | --- | --- | --- |
| Apple Watch | -1.26 | -3.20 ~ 0.68 | 4.38 | -9.84 | 7.32 | 2.70 |
| Fitbit Charge HR | -9.32 | -13.08 ~ -5.56 | 8.48 | -25.94 | 7.30 | 10.09 |
| Samsung Gear S | -7.05 | -11.60 ~ -2.50 | 10.26 | -27.15 | 13.06 | 9.63 |
| Mio Alpha | -4.34 | -7.54 ~ -1.14 | 7.22 | -18.49 | 9.80 | 4.72 |


출처 근거: paper Statistical analysis, Table 1, Figure 2; S1 Heart_Rate

원본 결과: analysis/runs/R1-20261024/tables/device_summary.csv, analysis/runs/R1-20261024/tables/heart_rate_pairs.csv

그림: 02_error_histograms.png, 07_bias_and_mae.png, 03_bland_altman.png

문제 ID: S02, S03, C03

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 04-concept 측정오차·일치도.md
