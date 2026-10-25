# HR02 · PAPER — 시계와 ECG의 산점도와 상관

> 논문·실제 데이터 적용 페이지. 수치는 run `{{meta:run_id}}` `hr02_correlation.csv`에서 채웠다. 일반 개념은 [HR02-concept](HR02-concept.md).

## 입력
HR01의 88쌍을 기기별로 나눈 22쌍씩. x = ECG 평균 HR, y = 시계 평균 HR (bpm).

## 이번 질문
기기마다 ECG가 높은 사람일수록 시계도 높게 읽는가? 그 직선적 관계는 얼마나 강하고, n = 22에서 얼마나 불확실한가?

## 방법과 이유
- [원문] "Pearson (r) or Spearman rank correlation coefficients (rho), for normal- and non-normally distributed data, respectively". Table 1 각주: *가 붙은 값은 비정규 자료라 Spearman. HR에서는 **Samsung만** 0.67*로 Spearman이다. 어떤 정규성 판정(검정 종류, 무엇의 정규성)을 썼는지는 보고되지 않았다 (ISS-06).
- [과제] 6주차 명세: `cor`와 `lm`, 기기별 Pearson 상관 비교. 그래서 **네 기기 모두 Pearson r**을 주 결과로 하고, 원문과 비교하려고 Spearman ρ도 함께 계산했다 [분석자].
- 95% CI: R `cor.test`의 Fisher z (SE = 1/√(n−3)). ρ의 CI는 같은 공식을 ρ에 적용한 근사다.
- p값은 "ρ = 0"(관계 없음)에 대한 검정이라 측정 비교에서는 거의 정보가 없다. 관계가 있다는 것은 당연하고, 궁금한 것은 **얼마나 맞는가**다.

## 출력

{{t:corr}}

{{f:F1}}

- Apple Watch의 r이 가장 높고({{v:hr02_correlation|Apple|pearson_r|3}}), Samsung Gear S가 가장 낮다({{v:hr02_correlation|Samsung|pearson_r|3}}).
- **Samsung**: 과제의 Pearson r = **{{v:hr02_correlation|Samsung|pearson_r|3}}**, Spearman ρ = **{{v:hr02_correlation|Samsung|spearman_rho|3}}**. 원문 0.67*은 ρ이며, 우리 ρ와 반올림 범위에서 같다 (HR06). 두 값은 서로 다른 통계량이므로 **Pearson 0.743을 0.67로 바꾸거나 둘을 '불일치'로 세지 않는다** (ISS-05).
- 22명뿐이라 CI가 넓다. Fitbit의 CI {{v:hr02_correlation|Fitbit|pearson_lo|2}}–{{v:hr02_correlation|Fitbit|pearson_hi|2}}와 Mio의 {{v:hr02_correlation|Alpha|pearson_lo|2}}–{{v:hr02_correlation|Alpha|pearson_hi|2}}가 크게 겹치므로, r의 순서만으로 기기 간 차이를 주장할 수 없다. 기기 간 상관 차이 검정은 범위 밖이며 하지 않았다.

## 남은 질문
- 상관이 높다는 것은 "같은 값을 낸다"는 뜻이 아니다. F1에서 Fitbit 점들은 대부분 y = x 아래에 있다. 얼마나 아래인가는 HR03(기울기)과 HR04(오차)가 답한다.
- 참가자들의 평균 HR 범위({{v:hr04_error|Apple|ecg_mean|0}} ± {{v:hr04_error|Apple|ecg_sd|0}} bpm 수준)가 넓을수록 r은 커지기 쉽다. 평균 자료의 r을 운동 중 순간 정확도로 읽지 않는다.
- ISS-06: Samsung만 Spearman을 쓴 근거(정규성 판정 방법)는 미확인이다.
