# 산점도·Pearson 상관 — 논문·실제 데이터 적용 (paper)

학습 단계: HR02 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

기기마다 x=동시 trial ECG의 참가자 평균, y=해당 시계의 참가자 평균으로 두고 22쌍을 사용했습니다. 네 기기를 합친 88행에서 독립표본 상관 검정을 수행하지 않았습니다.

## 논문 원문에서 사용한 분석

원문은 Pearson 또는 Spearman 상관을 사용합니다. Table 1 각주상 Samsung의 0.67은 Spearman입니다. 이 구분 없이 과제 Pearson과 직접 비교하면 불일치 원인을 잘못 설명하게 됩니다.

## 이번 구현의 선택과 이유

수정된 과제가 요구하는 Pearson을 네 기기 모두에 계산하고, Fisher z 방식 95%CI와 산점도를 보고했습니다. Spearman은 원문과 같은 종류의 수치를 대조하는 보조 값입니다. 산점도의 회귀선·동일값 선은 다음 회귀·오차 단계에서도 함께 읽습니다.

## 출력·검토 결과

아래는 실제 22명에서 계산한 값입니다. 모두 양의 상관이지만 상관 크기만으로 시계가 ECG와 같은 값을 낸다고 판단하지 않습니다. Samsung의 과제 Pearson은 약 0.743, 원문과 비교한 보조 Spearman은 약 0.670입니다.

## 남은 의문과 다음 단계

S01·S02·C01에 연결됩니다. 평균 집계가 개인 내 변동을 가릴 수 있고 표본 범위가 제한됩니다. 직선 관계를 원래 bpm 단위에서 기술하는 OLS는 다음 단계, 실제 차이의 크기는 오차 단계에서 다룹니다.

## 실제 산출물

| 기기 | n | Pearson r | 95%CI |
| --- | --- | --- | --- |
| Apple Watch | 22 | 0.952930 | 0.888146 ~ 0.980578 |
| Fitbit Charge HR | 22 | 0.812046 | 0.593699 ~ 0.919015 |
| Samsung Gear S | 22 | 0.742585 | 0.467269 ~ 0.886612 |
| Mio Alpha | 22 | 0.870193 | 0.708531 ~ 0.945073 |


출처 근거: paper Statistical analysis and Table 1 footnote; S1 Heart_Rate

원본 결과: analysis/runs/R1-20261024/tables/device_summary.csv

그림: 01_scatter_regression.png

문제 ID: S01, S02, C01

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 02-concept 산점도·Pearson 상관.md
