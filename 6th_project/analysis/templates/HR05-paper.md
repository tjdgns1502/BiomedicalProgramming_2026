# HR05 · PAPER — 잔차 진단, 영향점, 한 명씩 제외 민감도

> 논문·실제 데이터 적용 페이지. 수치는 run `{{meta:run_id}}` `hr05_*.csv`에서 채웠다. 일반 개념은 [HR05-concept](HR05-concept.md).

## 입력
HR03의 기기별 OLS 모형 4개, HR04의 오차.

## 이번 질문
기기별 OLS가 가정을 크게 어기는가? 특정 한 사람이 r·기울기·bias·LoA를 좌우하는가?

## 방법과 이유
- [원문] 잔차 진단이나 영향점 분석을 보고하지 않았다. 이 단계는 **과제의 보조 진단**이며 원문 재현이 아니다.
- 잔차 대 적합값, 표준화 잔차 Q–Q, Cook's distance (참조선 4/n = 0.18은 경험칙).
- 한 명씩 제외: 기기마다 22번, 매번 1명을 빼고 21명으로 다시 계산. **주 분석(22명 전원)은 그대로 두고** 별도 시나리오로만 보인다. 이 범위는 CI가 아니고, 새 사람에 대한 예측을 재는 교차검증도 아니다.

## 출력

{{f:F5}}

{{f:F6}}

{{f:F7}}

Cook's D > 4/n 또는 |표준화 잔차| > 2인 경우:

{{t:influential}}

한 명씩 제외한 결과의 범위:

{{t:loo}}

### 읽는 법
- **Apple Watch ID 20**은 ECG가 가장 낮은 사람(레버리지 큼)이라 Cook's D가 가장 크다. 빼면 기울기가 {{v:hr05_loo_summary|Apple,metric=slope|full_value|3}}에서 {{v:hr05_loo_summary|Apple,metric=slope|loo_max|3}}까지 움직인다. **Apple ID 14**는 오차가 큰 사람(시계 {{v:hr05_diagnostics|Apple,id=14|device_hr|2}} vs ECG {{v:hr05_diagnostics|Apple,id=14|ecg_hr|2}})으로, 빼면 LoA 하한이 {{v:hr05_loo_summary|Apple,metric=loa_lower|full_value|1}}에서 {{v:hr05_loo_summary|Apple,metric=loa_lower|loo_max|1}}로 좁아진다. 그래도 Apple의 r은 어떤 한 명을 빼도 {{v:hr05_loo_summary|Apple,metric=pearson_r|loo_min|3}} 이상이다.
- **Fitbit ID 14**는 시계가 ECG보다 **높게** 읽은 드문 사람이다. 빼면 LoA 상한이 {{v:hr05_loo_summary|Fitbit,metric=loa_upper|full_value|1}}에서 {{v:hr05_loo_summary|Fitbit,metric=loa_upper|loo_min|1}}로 줄어든다. 그래도 Fitbit bias는 {{v:hr05_loo_summary|Fitbit,metric=bias|loo_min|1}} ~ {{v:hr05_loo_summary|Fitbit,metric=bias|loo_max|1}} 범위에 머문다.
- **Mio ID 10**(시계 {{v:hr05_diagnostics|Alpha,id=10|device_hr|2}} vs ECG {{v:hr05_diagnostics|Alpha,id=10|ecg_hr|2}})이 Mio의 큰 음의 꼬리를 대표한다. 빼면 LoA 하한이 {{v:hr05_loo_summary|Alpha,metric=loa_lower|full_value|1}}에서 {{v:hr05_loo_summary|Alpha,metric=loa_lower|loo_max|1}}로 바뀐다.
- Q–Q(F6)에서 Apple·Mio의 아래쪽 꼬리가 직선에서 벗어난다. n = 22에서는 결정적 근거가 아니지만, HR04의 LoA를 '정확히 95%'로 읽지 말아야 할 이유다.
- **결론**: 어떤 한 명을 빼도 bias의 부호(음수)와 기기들의 대략적인 순서는 바뀌지 않는다. LoA 폭은 한두 사람에 민감하다. 영향이 큰 사람은 시계가 실제로 크게 틀린 사례일 수 있으므로 **주 분석에서 지우지 않았다** (ISS-14).

## 남은 질문
- 왜 이 사람들에서 크게 틀렸는가(움직임, 착용 위치, 피부 유형)는 평균 자료로 알 수 없다. 원문은 피부 유형 하위집단 상관을 보고했지만 범위 밖이다.
- 등분산 가정은 F5에서 크게 어긋나 보이지 않지만 검정하지 않았다.
