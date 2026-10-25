# HR04 · PAPER — 측정오차(시계 − ECG)의 평균과 분포, Bland–Altman

> 논문·실제 데이터 적용 페이지. 수치는 run `{{meta:run_id}}` `hr04_error.csv`에서 채웠다. 일반 개념은 [HR04-concept](HR04-concept.md).

## 입력
기기별 22개 오차 e = 시계 − ECG (bpm). 음수 = 시계가 낮게 잼.

## 이번 질문
시계는 ECG와 평균적으로 얼마나 다른가(bias)? 사람마다 얼마나 흩어지는가(SD, LoA)? **상관이 높은 기기도 값이 어긋날 수 있는가?** (6주차 검증 과제)

## 방법과 이유
- [과제] 오차 = 시계 − 기준. [원문]도 같은 방향이다(Table 1 "Mean difference"가 음수이고 "underestimated"로 서술).
- bias 95% CI = t 분포 (자유도 21). 고정 95% LoA = bias ± 1.96 × SD (SD는 n − 1). 둘은 다른 질문에 답한다: CI는 **평균 오차**의 불확실성, LoA는 **한 사람의 오차**가 놓일 범위다.
- `bias/ECG 평균 (%)`는 **부호가 있는** 백분율이다(음수 = 과소측정). 계획서는 |bias|라고 적었으나 코드는 부호를 유지했다. 크기는 같다 (ISS-20).
- [원문] Mio HR은 "systematically biased"로 판단해 LoA를 평균값의 함수(Upper = −0.44·avg + 52.69, Lower = 0.4·avg − 61.2)로 보고했다. 이 **가변 LoA**는 이 페이지의 **고정 LoA와 추정 대상이 다르므로 같은 결과로 비교하지 않는다** (HR06, ISS-10).

## 출력

{{t:err}}

{{f:F2}}

{{f:F3}}

{{f:F4}}

### 상관이 높아도 일치하지 않는다 (검증 과제)
- **Fitbit Charge HR**: r = {{v:hr02_correlation|Fitbit|pearson_r|2}}로 '강한' 상관(원문 기준 r ≥ 0.7)이지만, 평균오차 {{v:hr04_error|Fitbit|bias|1}} bpm (95% CI {{v:hr04_error|Fitbit|bias_lo|1}} ~ {{v:hr04_error|Fitbit|bias_hi|1}})이다. 22명 중 {{v:hr04_error|Fitbit|n_negative|int}}명에서 시계가 낮게 읽었다.
- **Mio Alpha**는 r = {{v:hr02_correlation|Alpha|pearson_r|2}}로 Fitbit보다 상관이 높지만 bias {{v:hr04_error|Alpha|bias|1}} bpm으로 0과 구별되고, LoA 하한이 {{v:hr04_error|Alpha|loa_lower|1}} bpm이다. F2에서 대부분은 0 근처에 몰려 있지만 몇 사람이 −15 ~ −25 bpm으로 크게 낮다. 평균과 LoA는 이 소수의 꼬리에 끌린다(중앙값 {{v:hr04_error|Alpha|median|1}}).
- **Apple Watch**만 bias {{v:hr04_error|Apple|bias|1}} bpm의 95% CI({{v:hr04_error|Apple|bias_lo|1}} ~ {{v:hr04_error|Apple|bias_hi|1}})가 0을 포함한다. 그래도 개인 오차는 LoA {{v:hr04_error|Apple|loa_lower|1}} ~ {{v:hr04_error|Apple|loa_upper|1}} bpm 범위다.
- **Samsung Gear S**는 LoA 폭이 가장 넓다({{v:hr04_error|Samsung|loa_lower|1}} ~ {{v:hr04_error|Samsung|loa_upper|1}}). 원문도 Samsung을 HR 변동이 가장 큰 기기로 보고했다.
- 네 기기 모두 평균 오차가 음수다. 원문의 "All devices underestimated" 및 "1–9%"와 같은 방향·크기다(bias/ECG 평균 = Apple {{v:hr04_error|Apple|pct_bias|1}}% ~ Fitbit {{v:hr04_error|Fitbit|pct_bias|1}}%, 음수 = 과소측정).

F4가 이 대비를 한눈에 보여 준다. 왼쪽 상관 순서와 오른쪽 오차 크기의 순서가 같지 않다.

## 남은 질문
- 몇 bpm까지 허용할지는 사용 목적(운동 강도 처방, 에너지 소비 추정)이 정해야 하며, 이 분석은 허용 기준을 정하지 않았다. 따라서 "임상적으로 교환 가능하다/불가능하다"는 판정을 내리지 않는다.
- 이 오차는 **약 58분 평균 HR**의 오차다. 순간 HR이나 활동별 오차는 더 클 수 있으나 공개 자료로는 볼 수 없다 (ISS-03).
- 오차 분포가 꼬리를 가지면(Mio, Apple) ±1.96 SD의 '95%' 해석은 근사다. LoA의 CI는 계산하지 않았다.
