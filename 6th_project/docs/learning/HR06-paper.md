<!-- 자동 생성: analysis/templates/HR06-paper.md 에서 run R1-20261025 / R2-20261025 표로 채움. 직접 고치지 말고 템플릿을 고칠 것. -->
# HR06 · PAPER — 원문 Table 1과의 비교

> 논문·실제 데이터 적용 페이지. 수치는 run `R1-20261025` `hr06_paper_comparison.csv`와 탐색적 run `R2-20261025` `hr06_rounding_candidates.csv`에서 채웠다. 일반 개념은 [HR06-concept](HR06-concept.md).

## 입력
- [원문] Table 1의 Heart rate 블록. PDF 5쪽에서 손으로 옮겨 `analysis/config/paper_table1_hr.csv`에 두었다(52개 셀). 별도 문맥 검토자가 PDF와 대조해 일치를 확인했다.
- 우리 값: HR02(상관), HR04(평균·SD·bias·LoA).

## 이번 질문
같은 공개 자료와 같은 정의로 계산하면 원문 Table 1의 HR 숫자가 나오는가? 다르면 왜 다른가?

## 방법과 이유
- **허용오차는 결과를 보기 전에** `plan_R1-20261025.json`에 고정했다(2026-10-25 16:48 KST). 보고 자릿수의 반 단위: 소수 첫째 자리 값은 ±0.05, 둘째 자리 값은 ±0.005, N은 정확히 일치.
- **같은 정의끼리만** 비교한다.
  - Samsung r/ρ는 원문이 Spearman이므로 우리 Spearman ρ와 비교하고, Pearson r은 따로 '비교 불가'로 둔다.
  - Mio LoA는 원문이 회귀식이므로 '비교 불가'다.
  - ICC는 범위 밖이라 계산하지 않았다.
- r의 CI 계산법은 원문에 없다 (ISS-07). Fisher z를 기본으로 가정했다 [분석자].

## 출력
### 사전 규칙에 따른 비교 (R1)

| 기기 | 항목 | 통계량 | 원문 표기 | 우리 값 | 차이 | 허용오차 | 판정 |
|---|---|---|---|---|---|---|---|
| Apple Watch | N | same definition | 22 | 22 | 0.0 | 0 | 반올림 일치 |
| Fitbit Charge HR | N | same definition | 22 | 22 | 0.0 | 0 | 반올림 일치 |
| Samsung Gear S | N | same definition | 22 | 22 | 0.0 | 0 | 반올림 일치 |
| Mio Alpha | N | same definition | 22 | 22 | 0.0 | 0 | 반올림 일치 |
| Apple Watch | 시계 평균 | same definition | 100.7 ±14.0 | 100.70 | 0.003 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | 시계 평균 | same definition | 92.7 ± 11.5 | 92.66 | -0.043 | 0.05 | 반올림 일치 |
| Samsung Gear S | 시계 평균 | same definition | 93.4 ± 13.9 | 93.44 | 0.043 | 0.05 | 반올림 일치 |
| Mio Alpha | 시계 평균 | same definition | 97.7 ± 14.6 | 97.65 | -0.048 | 0.05 | 반올림 일치 |
| Apple Watch | 시계 SD | same definition | 100.7 ±14.0 | 13.99 | -0.007 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | 시계 SD | same definition | 92.7 ± 11.5 | 11.51 | 0.012 | 0.05 | 반올림 일치 |
| Samsung Gear S | 시계 SD | same definition | 93.4 ± 13.9 | 13.94 | 0.040 | 0.05 | 반올림 일치 |
| Mio Alpha | 시계 SD | same definition | 97.7 ± 14.6 | 14.57 | -0.027 | 0.05 | 반올림 일치 |
| Apple Watch | ECG 평균 | same definition | 102.0 ± 14.4 | 101.96 | -0.037 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | ECG 평균 | same definition | 102.0 ± 14.5 | 101.97 | -0.025 | 0.05 | 반올림 일치 |
| Samsung Gear S | ECG 평균 | same definition | 100.5 ± 14.6 | 100.49 | -0.009 | 0.05 | 반올림 일치 |
| Mio Alpha | ECG 평균 | same definition | 102.0 ± 13.4 | 101.99 | -0.007 | 0.05 | 반올림 일치 |
| Apple Watch | ECG SD | same definition | 102.0 ± 14.4 | 14.41 | 0.006 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | ECG SD | same definition | 102.0 ± 14.5 | 14.52 | 0.021 | 0.05 | 반올림 일치 |
| Samsung Gear S | ECG SD | same definition | 100.5 ± 14.6 | 14.60 | -0.001 | 0.05 | 반올림 일치 |
| Mio Alpha | ECG SD | same definition | 102.0 ± 13.4 | 13.41 | 0.006 | 0.05 | 반올림 일치 |
| Apple Watch | r/ρ | Pearson r (CI: Fisher z) | 0.95 (0.88 to 0.98) | 0.953 | 0.0029 | 0.005 | 반올림 일치 |
| Fitbit Charge HR | r/ρ | Pearson r (CI: Fisher z) | 0.81 (0.59 to 0.92) | 0.812 | 0.0020 | 0.005 | 반올림 일치 |
| Samsung Gear S | r/ρ | Spearman rho (CI: Fisher z, SE=1/sqrt(n-3)) | 0.67* (0.35 to 0.85) | 0.670 | 0.0002 | 0.005 | 반올림 일치 |
| Mio Alpha | r/ρ | Pearson r (CI: Fisher z) | 0.87 (0.71 to 0.94) | 0.870 | 0.0002 | 0.005 | 반올림 일치 |
| Apple Watch | r/ρ CI 하한 | Pearson r (CI: Fisher z) | 0.95 (0.88 to 0.98) | 0.888 | 0.0081 | 0.005 | 불일치 |
| Fitbit Charge HR | r/ρ CI 하한 | Pearson r (CI: Fisher z) | 0.81 (0.59 to 0.92) | 0.594 | 0.0037 | 0.005 | 반올림 일치 |
| Samsung Gear S | r/ρ CI 하한 | Spearman rho (CI: Fisher z, SE=1/sqrt(n-3)) | 0.67* (0.35 to 0.85) | 0.347 | -0.0034 | 0.005 | 반올림 일치 |
| Mio Alpha | r/ρ CI 하한 | Pearson r (CI: Fisher z) | 0.87 (0.71 to 0.94) | 0.709 | -0.0015 | 0.005 | 반올림 일치 |
| Apple Watch | r/ρ CI 상한 | Pearson r (CI: Fisher z) | 0.95 (0.88 to 0.98) | 0.981 | 0.0006 | 0.005 | 반올림 일치 |
| Fitbit Charge HR | r/ρ CI 상한 | Pearson r (CI: Fisher z) | 0.81 (0.59 to 0.92) | 0.919 | -0.0010 | 0.005 | 반올림 일치 |
| Samsung Gear S | r/ρ CI 상한 | Spearman rho (CI: Fisher z, SE=1/sqrt(n-3)) | 0.67* (0.35 to 0.85) | 0.851 | 0.0013 | 0.005 | 반올림 일치 |
| Mio Alpha | r/ρ CI 상한 | Pearson r (CI: Fisher z) | 0.87 (0.71 to 0.94) | 0.945 | 0.0051 | 0.005 | 불일치 |
| Apple Watch | 평균차 | same definition | -1.3 ± 4.4 | -1.26 | 0.040 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | 평균차 | same definition | -9.3 ± 8.5 | -9.32 | -0.018 | 0.05 | 반올림 일치 |
| Samsung Gear S | 평균차 | same definition | -7.1 ± 10.3 | -7.05 | 0.052 | 0.05 | 불일치 |
| Mio Alpha | 평균차 | same definition | -4.3 ± 7.2 | -4.34 | -0.040 | 0.05 | 반올림 일치 |
| Apple Watch | 평균차 SD | same definition | -1.3 ± 4.4 | 4.38 | -0.024 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | 평균차 SD | same definition | -9.3 ± 8.5 | 8.48 | -0.021 | 0.05 | 반올림 일치 |
| Samsung Gear S | 평균차 SD | same definition | -7.1 ± 10.3 | 10.26 | -0.043 | 0.05 | 반올림 일치 |
| Mio Alpha | 평균차 SD | same definition | -4.3 ± 7.2 | 7.22 | 0.017 | 0.05 | 반올림 일치 |
| Apple Watch | LoA 상한 | fixed LoA = bias +/- 1.96 SD | 7.3 | 7.32 | 0.016 | 0.05 | 반올림 일치 |
| Fitbit Charge HR | LoA 상한 | fixed LoA = bias +/- 1.96 SD | 7.4 | 7.30 | -0.099 | 0.05 | 불일치 |
| Samsung Gear S | LoA 상한 | fixed LoA = bias +/- 1.96 SD | 13.1 | 13.06 | -0.044 | 0.05 | 반올림 일치 |
| Mio Alpha | LoA 상한 | fixed LoA = bias +/- 1.96 SD | -0.44.avg + 52.69† | 9.80 | — | — | 비교 불가 |
| Apple Watch | LoA 하한 | fixed LoA = bias +/- 1.96 SD | -9.9 | -9.84 | 0.063 | 0.05 | 불일치 |
| Fitbit Charge HR | LoA 하한 | fixed LoA = bias +/- 1.96 SD | -26.0 | -25.94 | 0.064 | 0.05 | 불일치 |
| Samsung Gear S | LoA 하한 | fixed LoA = bias +/- 1.96 SD | -27.3 | -27.15 | 0.148 | 0.05 | 불일치 |
| Mio Alpha | LoA 하한 | fixed LoA = bias +/- 1.96 SD | 0.4.avg—61.2† | -18.49 | — | — | 비교 불가 |
| Apple Watch | ICC | ICC (not computed) | 0.98 (0.94 to 0.99) | — | — | — | 비교 불가 |
| Fitbit Charge HR | ICC | ICC (not computed) | 0.78 (-0.02 to 0.93) | — | — | — | 비교 불가 |
| Samsung Gear S | ICC | ICC (not computed) | 0.80 (0.40 to 0.93) | — | — | — | 비교 불가 |
| Mio Alpha | ICC | ICC (not computed) | 0.91 (0.72 to 0.97) | — | — | — | 비교 불가 |
| Samsung Gear S | Pearson r (Samsung) | Pearson r (CI: Fisher z) | 0.67* (Spearman) | 0.743 | — | — | 비교 불가 |

요약: 비교 가능한 값 중 **39개 반올림 일치, 7개 불일치**이고, 비교 불가가 7개다. 이 판정은 사전 규칙대로 남기고, 아래 탐색 결과로 바꾸지 않는다.

- 표본수, 시계·ECG 평균과 SD, 4기기의 r/ρ 점추정, bias의 SD는 모두 일치한다. 공개 자료와 원문 Table 1이 **같은 22명 × 4기기 자료**라는 강한 정황이다.
- 불일치 7개는 모두 **다른 값에서 파생된 값**이다(r의 CI 경계, bias, LoA). 원본 요약(평균·SD·r)은 맞는다.

### 탐색적: 반올림된 중간값으로 계산했다면? (R2, post-result)
R1 결과를 **본 뒤** 불일치 패턴을 보고 만든 후보 4개다(`plan_R2-20261025.json`, 후보 수 고정, 추가 탐색 없음). 근거 유형은 **reproduction_candidate**다.

| 후보 | 기기 | 항목 | 계산 | 후보 값 | 원문 값 | 판정 |
|---|---|---|---|---|---|---|
| C1 | Apple Watch | corr_lo | Fisher z on r rounded = 0.95 | 0.881 |   0.88 | 반올림 일치 |
| C1 | Apple Watch | corr_hi | Fisher z on r rounded = 0.95 | 0.979 |   0.98 | 반올림 일치 |
| C2 | Apple Watch | bias | 100.7 - 102.0 | -1.300 |  -1.30 | 반올림 일치 |
| C3 | Apple Watch | bias | -1.2605 -> -1.26 -> -1.3 | -1.300 |  -1.30 | 반올림 일치 |
| C4 | Apple Watch | loa_upper | -1.3 +/- 1.96 x 4.4 | 7.324 |   7.30 | 반올림 일치 |
| C4 | Apple Watch | loa_lower | -1.3 +/- 1.96 x 4.4 | -9.924 |  -9.90 | 반올림 일치 |
| C1 | Fitbit Charge HR | corr_lo | Fisher z on r rounded = 0.81 | 0.590 |   0.59 | 반올림 일치 |
| C1 | Fitbit Charge HR | corr_hi | Fisher z on r rounded = 0.81 | 0.918 |   0.92 | 반올림 일치 |
| C2 | Fitbit Charge HR | bias | 92.7 - 102.0 | -9.300 |  -9.30 | 반올림 일치 |
| C3 | Fitbit Charge HR | bias | -9.3177 -> -9.32 -> -9.3 | -9.300 |  -9.30 | 반올림 일치 |
| C4 | Fitbit Charge HR | loa_upper | -9.3 +/- 1.96 x 8.5 | 7.360 |   7.40 | 반올림 일치 |
| C4 | Fitbit Charge HR | loa_lower | -9.3 +/- 1.96 x 8.5 | -25.960 | -26.00 | 반올림 일치 |
| C1 | Samsung Gear S | corr_lo | Fisher z on r rounded = 0.67 | 0.346 |   0.35 | 반올림 일치 |
| C1 | Samsung Gear S | corr_hi | Fisher z on r rounded = 0.67 | 0.851 |   0.85 | 반올림 일치 |
| C2 | Samsung Gear S | bias | 93.4 - 100.5 | -7.100 |  -7.10 | 반올림 일치 |
| C3 | Samsung Gear S | bias | -7.0482 -> -7.05 -> -7.1 | -7.100 |  -7.10 | 반올림 일치 |
| C4 | Samsung Gear S | loa_upper | -7.1 +/- 1.96 x 10.3 | 13.088 |  13.10 | 반올림 일치 |
| C4 | Samsung Gear S | loa_lower | -7.1 +/- 1.96 x 10.3 | -27.288 | -27.30 | 반올림 일치 |
| C1 | Mio Alpha | corr_lo | Fisher z on r rounded = 0.87 | 0.708 |   0.71 | 반올림 일치 |
| C1 | Mio Alpha | corr_hi | Fisher z on r rounded = 0.87 | 0.945 |   0.94 | 반올림 일치 |
| C2 | Mio Alpha | bias | 97.7 - 102.0 | -4.300 |  -4.30 | 반올림 일치 |
| C3 | Mio Alpha | bias | -4.3405 -> -4.34 -> -4.3 | -4.300 |  -4.30 | 반올림 일치 |

- C1(r을 둘째 자리로 반올림한 뒤 Fisher z CI)은 4기기 CI 경계 8개를 모두 재현한다. Mio 상한은 0.94499로, 경계에서 1.2e-5 차이로 통과한다.
- C4(반올림된 bias와 SD로 LoA 계산)는 Apple·Fitbit·Samsung의 LoA 6개를 모두 재현한다.
- Samsung bias −7.1은 C2(반올림한 평균끼리 뺌: 93.4 − 100.5)와 C3(이중 반올림: −7.048 → −7.05 → −7.1)가 **둘 다** 재현한다. 어느 경로인지는 **식별 불가**다 (ISS-08).

### 판정
- **재현 수준 (Table 1 HR 블록)**: 사전 규칙으로는 **부분 일치**(7개 불일치). 탐색적 후보까지 포함하면 비교 가능한 값이 모두 **반올림 경로와 호환**된다.
- **저자 설정 확인도**: 낮음. 원문은 CI 공식, 반올림 순서, 정규성 판정을 쓰지 않았다. 호환되는 경로를 찾았다는 것이 **저자가 그렇게 계산했다는 증거는 아니다**.
- **비교하지 않은 것**: Mio 가변 LoA(회귀식), ICC, 피부 유형 하위집단 상관, 에너지 소비·걸음 수.

## 남은 질문
- ISS-07, ISS-09: 반올림된 중간값으로 파생값을 계산하면 보고값이 최대 0.01(r 경계)에서 0.15 bpm(Samsung LoA 하한)까지 움직인다. 해석에 영향은 작지만, 표의 숫자끼리 정확히 다시 계산되지 않는 이유가 된다.
- ISS-11: 원문 본문은 Fitbit HR에도 체계적 편향이 있다고 했으나, Table 1은 Fitbit HR LoA를 회귀식이 아닌 점추정(7.4, −26.0)으로 보고했다. 원문 내부의 상충이며 해결할 수 없다.
- ISS-10: Mio 가변 LoA 식의 계산 세부는 보고되지 않았고, 과제 범위 밖이라 재현하지 않았다.
