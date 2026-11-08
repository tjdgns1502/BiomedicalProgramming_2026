<!-- 자동 생성: analysis/templates/HR01-paper.md 에서 run R1-20261025 / R2-20261025 표로 채움. 직접 고치지 말고 템플릿을 고칠 것. -->
# HR01 · PAPER — 공개 HR 자료의 구조와 88쌍 만들기

> 논문·실제 데이터 적용 페이지. 수치는 run `R1-20261025`의 표에서 자동으로 채웠다. 일반 개념은 [HR01-concept](HR01-concept.md).
> 근거 표기: [원문] paper_reported · [코드북] codebook_verified · [관측] observed_data · [분석자] analyst_assumption

## 입력
- 원자료: `analysis/data/raw/pone.0154420.s001.xlsx` (SHA-256 `50cae0d20ded94e43b956fc9f86a286cdf227eafe549906442fe21445570fcff`). `6th_project/dataset/`의 사용자 제공 파일을 그대로 복사했다. 공식 주소(doi 10.1371/journal.pone.0154420.s001)에서 다시 받아 대조하지는 않았다 (ISS-18).
- 사용한 시트: `Heart_Rate` (헤더 1행 + 참가자 22행 × 13열), 코드북 `Key` 시트 72–83행.
- [원문] Methods: 참가자는 세 번 방문했고, 2·3회차(trial 1, 2)에 한 번에 두 기기를 양팔에 하나씩 찼다(무작위·균형 배정). ECG와 기기 HR을 약 58분 protocol 동안 **15초마다 수기 기록**했다. Results: 모든 참가자가 각 기기를 한 번씩 찼다.

## 이번 질문
한 행은 무엇이고, 시계 HR을 어느 ECG 값과 짝지어야 하는가? 분석의 분모는 몇인가?

## 방법과 이유
1. **열 매핑은 헤더가 아니라 위치로** 했다. 헤더에 문제가 두 개 있기 때문이다.
   - `Trial_number`가 네 번 중복된다 (ISS-02). 이름으로 읽으면 R이 `Trial_number...4` 같은 임시 이름을 붙인다.
   - F열 헤더가 `Fitbit_metamax`인데 [코드북] Key 76행은 이 열을 "Heart rate measured from electrocardiography while wearing the Fitbit Charge HR (bpm)"로 정의한다 (ISS-01).

| 기기 | 시계 열 | ECG 열 | trial 열 | 원래 헤더(시계 / ECG / trial) | Key 정의(ECG 열) |
|---|---|---|---|---|---|
| Apple Watch | B | C | D | Apple_device / Apple_ECG / Trial_number | Key 73행: ECG HR |
| Fitbit Charge HR | E | F | G | Fitbit_device / **Fitbit_metamax** / Trial_number | Key 76행: ECG HR |
| Samsung Gear S | H | I | J | Samsung_device / Samsung_ECG / Trial_number | Key 79행: ECG HR |
| Mio Alpha | K | L | M | Alpha_device / Alpha_ECG / Trial_number | Key 82행: ECG HR |

2. **ECG 짝의 확인** [관측]: 같은 참가자가 같은 trial에 찬 두 기기는 같은 ECG 기록을 공유해야 한다. 참가자 × trial 44개 조합 중 44개에서 두 기기의 ECG 값이 정확히 같았다. F열(`Fitbit_metamax`) 값도 같은 trial의 상대 기기 ECG 값과 같으므로, F열이 ECG HR이라는 코드북 정의를 자료가 지지한다.
3. **값의 정밀도**: 엑셀은 일부 값을 2진 표현 그대로 저장한다. 예: H2(Samsung, ID 1)는 파일 안에서 `78.069999999999993`이고 표시값은 78.07이다. 176개 HR 값이 모두 소수 둘째 자리 값이며, **반올림하지 않고 저장된 값 그대로** 분석했다 [분석자].
4. **긴 표로 변환**: 기기마다 `id, device, trial, device_hr, ecg_hr`와 원래 셀 위치(`cell_device`, `cell_ecg`), 원래 헤더, 저장 문자열을 남겼다. 오차 `error = device_hr − ecg_hr`(음수 = 시계가 낮게 잼).
5. **선정·결측·제외**: 없음. 입력 88쌍 = 사용 88쌍, 제외 0, 대체 0.

## 출력
처음 두 참가자의 8쌍(실제 ID·셀 예시):

| pair_id | 기기 | trial | 시계 셀 | xlsx 저장 문자열 | 시계 HR | ECG 셀 | ECG 헤더 | ECG HR | 오차 |
|---|---|---|---|---|---|---|---|---|---|
| P01-Apple | Apple Watch | 1 | B2 | 116.34 | 116.34 | C2 | Apple_ECG | 118.29 | -1.95 |
| P02-Apple | Apple Watch | 1 | B3 | 104.93 | 104.93 | C3 | Apple_ECG | 109.62 | -4.69 |
| P01-Fitbit | Fitbit Charge HR | 1 | E2 |  92.43 | 92.43 | F2 | Fitbit_metamax | 118.29 | -25.86 |
| P02-Fitbit | Fitbit Charge HR | 2 | E3 |  83.84 | 83.84 | F3 | Fitbit_metamax | 105.13 | -21.29 |
| P01-Samsung | Samsung Gear S | 2 | H2 |  78.07 | 78.07 | I2 | Samsung_ECG | 107.37 | -29.30 |
| P02-Samsung | Samsung Gear S | 2 | H3 |  92.48 | 92.48 | I3 | Samsung_ECG | 105.13 | -12.65 |
| P01-Alpha | Mio Alpha | 2 | K2 | 104.09 | 104.09 | L2 | Alpha_ECG | 107.37 | -3.28 |
| P02-Alpha | Mio Alpha | 1 | K3 | 106.60 | 106.60 | L3 | Alpha_ECG | 109.62 | -3.02 |

자료 점검 결과:

| 점검 | 결과 |
|---|---|
| rows == 88 | 통과 |
| 22 per device | 통과 |
| no missing values | 통과 |
| trial in {1,2} | 통과 |
| device_hr <= 2 decimals | 통과 |
| ecg_hr <= 2 decimals | 통과 |
| each id x trial has 2 devices | 통과 |
| devices in same trial share one ECG value | 통과 |

- 파생자료: `analysis/data/derived/wallen-hr-331013dc4e56eb03e99b/hr_pairs_88.csv` (버전 = 이 CSV의 SHA-256 앞 20자리).
- **관측 단위** = 참가자 1명 × 기기 1개의 protocol 평균 HR 쌍. **88쌍은 22명이 4기기를 찬 반복 구조**이므로 독립 표본 88개가 아니다. 이후 모든 통계는 **기기별 n = 22**로 계산한다 (ISS-12).
- 6주차 프롬프트에 적힌 자료 버전 `wallen-hr-355eb8cf25fa3f49fd17`은 이 저장소에 없는 이전 실행(R1-20261024)의 것으로, 같은 방식으로 만든 버전인지 확인할 수 없다 (ISS-17).

## 남은 질문
- ISS-03: 공개 HR은 참가자별 protocol 평균값 하나뿐이다. 15초 기록과 활동별(누움·걷기·자전거) HR은 공개되지 않아 활동별 정확도는 이 자료로 볼 수 없다.
- ISS-04: 평균을 몇 개 기록으로, 빠진 기록을 어떻게 처리해 만들었는지 원문에 없다.
- ISS-13: Key 시트의 Gender 코딩(0/1)이 자료 헤더(1/2)와 다르고, Worksheet_5 설명이 한 줄씩 밀려 있다. HR 분석에는 쓰지 않는 열이라 영향이 없다.
