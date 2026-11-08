# HR03 · PAPER — 시계 ~ ECG 단순 선형회귀

> 논문·실제 데이터 적용 페이지. 수치는 run `{{meta:run_id}}` `hr03_ols.csv`에서 채웠다. 일반 개념은 [HR03-concept](HR03-concept.md).

## 입력
기기별 22쌍. 모형 `lm(device_hr ~ ecg_hr)` (반응 = 시계, 설명 = ECG). 모형 객체는 `runs/{{meta:run_id}}/models/ols_models.rds`.

## 이번 질문
ECG가 1 bpm 오를 때 시계는 평균 몇 bpm 오르는가(기울기)? 완벽한 시계라면 절편 0, 기울기 1인데, 어디서 벗어나는가?

## 방법과 이유
- **[과제]의 회귀와 [원문]의 회귀는 다르다.**
  - 과제: 시계 ~ ECG OLS. "ECG 값에 따라 시계가 평균적으로 어떻게 읽히는가"를 본다.
  - 원문: "systematic bias was assessed using linear regression to determine whether mean difference and/or limits of agreement varied across average values" — Bland–Altman의 **차이 ~ 평균** 회귀다. Mio HR의 LoA 식(−0.44·avg + 52.69 등)이 여기서 나왔다. 원문은 시계 ~ ECG OLS를 보고하지 않았으므로 이 페이지의 결과는 **원문과 비교할 대상이 없다**.
- 계수 95% CI = `confint` (t 분포, 자유도 20). 그림의 띠는 평균반응 95% CI이고, 개인 예측구간(`hr03_ols_bands.csv`의 pred_lo/pred_hi)은 표로만 남겼다. 두 구간을 섞지 않는다.

## 출력

{{t:ols}}

F1(산점도)의 실선이 이 회귀선이고, 점선이 y = x다.

- **Apple Watch**: 기울기 {{v:hr03_ols|Apple|slope|3}} (95% CI {{v:hr03_ols|Apple|slope_lo|3}}–{{v:hr03_ols|Apple|slope_hi|3}}), R² = {{v:hr03_ols|Apple|r2|3}}. 기울기 CI에 1이, 절편 CI에 0이 들어가 y = x와 다르다는 근거가 약하다.
- **Fitbit Charge HR**: 기울기 {{v:hr03_ols|Fitbit|slope|3}} (CI {{v:hr03_ols|Fitbit|slope_lo|3}}–{{v:hr03_ols|Fitbit|slope_hi|3}})로 **CI가 1을 포함하지 않는다**. ECG가 높은 사람일수록 시계가 더 많이 낮게 읽는 비례적 과소측정과 호환되는 모양이다. 절편 {{v:hr03_ols|Fitbit|intercept|1}}은 기울기가 1보다 작은 것을 보상하는 값이며 단독으로 해석하지 않는다.
- **Samsung Gear S**: 기울기 {{v:hr03_ols|Samsung|slope|3}}이고 CI {{v:hr03_ols|Samsung|slope_lo|3}}–{{v:hr03_ols|Samsung|slope_hi|3}}가 넓다. 잔차 SE {{v:hr03_ols|Samsung|sigma|1}} bpm으로 네 기기 중 흩어짐이 가장 크다.
- **Mio Alpha**: 기울기 {{v:hr03_ols|Alpha|slope|3}}로 1에 가깝지만, 선 전체가 y = x 아래에 있다(체계적 과소측정, HR04).
- R² = r²이므로 HR02의 상관과 같은 정보다. R²는 **이 22명에 대한 적합도**이며, 이 식을 다른 사람의 시계 값 보정에 써도 된다는 검증 성능이 아니다.

## 남은 질문
- 기울기 CI에 1이 들어간다고 "기울기가 1이다"라고 결론 내리지 않는다. n = 22에서는 CI가 넓다.
- ECG도 평균값이라 측정 잡음이 있다. x에 오차가 있으면 OLS 기울기는 1보다 작아지는 쪽으로 치우칠 수 있다(희석). 방법 비교 회귀(Deming 등)는 범위 밖이다.
- 원문의 차이 ~ 평균 회귀 세부(절대잔차 회귀 여부, 유의 기준)는 보고되지 않았고 재현하지 않았다 (ISS-10).
