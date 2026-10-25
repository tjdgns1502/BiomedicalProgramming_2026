# 자료·변수·관측 단위 — 논문·실제 데이터 적용 (paper)

학습 단계: HR01 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

논문은 건강한 참가자의 소비자용 시계를 ECG 기준과 비교합니다. 이번 입력은 S1의 Heart_Rate와 Key입니다. “공개된 참가자별 평균 심박수에서 시계와 해당 trial ECG의 관계·차이가 어떠한가?”로 과제 범위를 고정했습니다.

## 논문 원문·공개 자료에서 확인한 사실

공개 HR 시트는 22명의 protocol 평균입니다. 기기별 시계·ECG·trial 블록이 네 개이고, 15초 HR 시계열이나 활동별 HR 열은 없습니다. 논문의 세밀한 측정 절차와 공개 파일의 집계 수준을 구분했습니다.

## 이번 구현의 선택과 이유

원래 열 위치를 고정해 기기별 동시 ECG와 짝지었습니다. F1의 Fitbit_metamax는 Key Worksheet_4에서 ECG bpm으로 정의되어 그 근거로 매핑했습니다. ID·원래 헤더·행·셀·trial을 남겼으며 소수 정밀도를 유지했습니다. 22×4=88쌍을 모두 사용했고 제외·대체·추가 축약은 0입니다.

## 출력·검토 결과

아래 열 매핑과 실제 참가자 1의 변환은 공개 파일에 근거한 적용 예입니다. 가상 예제가 아닙니다. 원본 SHA256과 R·Python 대조는 자료·계산의 무결성 확인 범위이며 통계적 타당성 전체의 증명은 아닙니다.

## 남은 의문과 다음 단계

D01–D05·S01을 연결했습니다. 공개되지 않은 시간·활동 HR과 성별 코드 모순은 임의로 보완하지 않았습니다. 다음에는 이 관측 단위에서 산점도와 상관을 읽습니다.

## 실제 산출물

| 기기 | 시계 | 동시 ECG | trial |
| --- | --- | --- | --- |
| Apple Watch | B | C | D |
| Fitbit Charge HR | E | F | G |
| Samsung Gear S | H | I | J |
| Mio Alpha | K | L | M |

실제 결과: 22명, 기기별 22쌍, 총 88쌍; 주 분석 제외·대체·추가 축약 0. 원본 Heart_Rate 행 2–23.


출처 근거: S1 Dataset: Heart_Rate A1:M23, Key Worksheet_4; paper Methods / Experimental protocol

원본 결과: analysis/runs/R1-20261024/tables/heart_rate_pairs.csv

그림: 직접 연결 그림 없음

문제 ID: D01, D02, D03, D04, D05, S01

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 01-concept 자료·변수·관측 단위.md
