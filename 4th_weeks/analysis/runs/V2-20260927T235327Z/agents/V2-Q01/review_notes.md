# 독립 계획 검토: accept

V2-D01의 네 범위는 정의되어 있고 구현 가능하다. 기존 자료나 결과에 맞추어 방법을 조정할 여지를 제한하고, 공통 행 집합과 설계를 고정하며, 원문 재현과 분석자 진단을 구분한다. 원문 결과·현 모형 효과 추정치·원자료는 읽지 않았다. 허용된 재사용 감사에 들어 있는 코호트 건수 및 파일 목록은 보았다.

## 비선형 2개 제약의 이론

내부절점 2개인 `ns(..., intercept=FALSE)`는 3열을 반환한다. 절편을 더한 함수공간은 4차원이며, 그 안에 절편과 x의 2차원 선형공간이 포함된다. 따라서 spline 열을 `cbind(1,x)`에 투영한 잔차공간은 비퇴화 조건에서 정확히 2차원이다. 이를 rank-revealing QR로 추출하면 `nonlinear1=nonlinear2=0`은 선형 logit 모형이라는 귀무가설이다. 원래 ns의 임의 두 계수를 0으로 검정하는 것은 같은 귀무가설이 아니다. [R ns 공식 문서](https://stat.ethz.ch/R-manual/R-devel/library/splines/html/ns.html)

설계기반 공분산으로 두 항의 joint Wald 통계 W를 계산하고 F=W/2, 분모 df=degf(design)를 명시하는 안은 타당한 근사 추론이다. `regTermTest(method="Wald", df=...)`로 명시할 수 있다. 전체 모형행렬 rank 및 검정 대상 공분산의 가역성도 확인한다. 유한 공분산이라는 이유만으로 특이행렬을 통과시키면 안 된다. [survey 공식 매뉴얼](https://cran.r-project.org/web/packages/survey/refman/survey.html)

## 그림 추가안

동일 spline fit의 조건부 OR 곡선을 중앙값 기준, 5–95백분위 표시범위로 그리는 안도 승인한다. 범위와 기준은 공통 분석행의 marker만으로 미리 고정하고 새 검정은 추가하지 않는다. 원문 Figure 2 복제가 아닌 분석자 진단으로 표시한다.

새 x에서 학습 때 저장한 spline/QR 변환을 사용한다. 전체 모형행 차이 d=m(x,z)-m(reference,z)를 이용해 log OR=d beta, SE=sqrt(d V d')를 계산해야 기준값 추정의 공분산까지 반영된다. 새 grid에서 QR를 다시 계산하지 않는다. 점별 95% CI이며 동시 신뢰대역이 아니다. t 임계값의 자유도 등 CI 규칙을 적합 전에 고정한다. 기준에서 OR=1, contrast SE=0이다.

## 재사용 감사의 수용 범위

V2-E01의 조건부 artifact 재사용은 해시·절차기록 검토 범위에서 수용한다. 현재 output 해시는 과거 output 불변을 증명하지 않고, 현재 R/survey 확인은 역사적 전체 환경 동등성을 보장하지 않는다. 이 검토는 원시 로그 자체를 다시 감사하지 않았다. 성공 종료와 입력/code/config 해시 일치는 통계적 타당성, 저자와 동일한 FI, 정확한 NHANES pooling/domain 처리 또는 원문 출처의 독립 확인을 인증하지 않는다. 기존 추론적 제한과 source 확인 gate는 유지된다.

실질적인 계획 개정은 필요 없다. JSON에 적은 rank·공분산·고정 변환·CI 규칙을 구현 사양으로 기록한 뒤 제한된 구현을 시작할 수 있다.

추가 나이 gate 판정: 부모가 전달한 독립 출처 확인에서 `50 and older`, `younger than 50 excluded`, `over 50`가 함께 나타난다는 보고는 계획의 모호성 분기에 해당한다. 출처 보고와 문구 충돌을 기록하고 기존 >=50 운영 기준을 유지하면서 경계 인원만 감사하면 제한된 계획의 gate를 충족한다. 원저자 코드의 유일한 predicate 확인을 의미하지 않는다. Q는 원문을 직접 읽지 않았다. FI 역시 기존 analyst candidate 표기를 유지하는 조건부 분석이며 저자 동일 정의로 확정되지 않는다.

# 독립 결과 검토: accept_with_limits

V2-I01 코드, CSV, 저장 basis, 실행기록, 세 시도 로그 및 그림을 확인했다. 21개 output 해시와 8개 source/input/승인 해시는 결과 검토 보충 직전 모두 일치했다. 이 문서의 이후 보충으로 execution.json의 review_notes.md 해시는 과거 승인 시점의 해시가 된다.

별도 Q 스크립트 `review_numeric.R`로 저장 CSV의 로그 밑 계수/SE 변환, quartile OR/CI/p, nonlinear F p와 Bonferroni/BH, 곡선 OR/CI, 중앙값 기준 행, 나이 cycle 합계/차이, 행 ID 유일성, RDS/JSON basis 동등성을 재계산했다. 전부 통과했고 결과는 `result_numeric_checks.json`에 있다. Q가 전체 통계 모형을 별도로 재적합한 것은 아니다.

전체 양의 유한 가중치 parent design(88,062행)을 먼저 구성하고 9,786행 domain으로 subset하는 코드가 맞다. 133 strata/271 nested PSU/df=138이며, 기존 pooled weights와 upstream survey variable 생성은 독립 재도출하지 않았다. ln/log10 전체 공분산 검증은 실행된 assertion과 error maxima로 확인했고, fitted object 미저장 때문에 Q 별도 full covariance 재계산은 하지 않았다.

사분위는 raw type-7 경계와 동점 보존, Q1 대비 세 계수이고 12행이 완전하다. 모든 CI는 t(138) 점별 구간이다. spline의 2차원 비선형 공간·전체 adjusted rank·tested covariance Cholesky·고정 변환 재사용·reference 공분산 차이 구현은 계획에 맞다. 네 비선형 검정은 모두 Bonferroni 보정 후 0.05 미만이다. 이 결론은 운영 candidate FI와 고정 모형 내 logit 선형성 진단에 한정한다. 사분위 검정과 그림 CI에 familywise 보정이 적용되었다고 쓰면 안 된다.

나이 감사에서 full design derivative의 >=50/>50/=50은 24,119/23,313/806, 공통 domain은 9,786/9,693/93이다. 모든 cycle 및 합계 항등식이 맞다. raw DEMO 파일을 새로 읽은 결과가 아니라 derivative의 기록 나이이며, candidate는 이미 >=50이고 valid filtering 뒤 집계하므로 missing-age/younger-age 전체 eligibility 감사까지 했다고 주장할 수 없다.

시도 2는 `near(dat$NLR, dat$LBDNENO/dat$LBDLYMNO)` 실패로 중단되었다. 최종 코드는 추가 assertion을 제거하고 원래 frozen marker를 사용한다. 이 변경은 입력고정 범위에서 허용되지만 기존 marker 생성의 정확성을 인증하지 않는다. 로그만으로 실패가 missingness만 때문인지, fallback/다른 생성법 때문인지, 실제 불일치 때문인지 구별할 수 없다. 그 원인을 단정하거나 해소되었다고 쓰면 안 된다.

현재 bounded run의 차단 결함은 발견하지 않았다. 다른 데이터에서 log/quartile 실패가 나면 스크립트 전체가 중단되어 개별 실패 요약이 남지 않는다는 일반화 한계는 있다. 현재 네 비교/모형은 실제 성공하여 이 한계로 누락된 결과는 없다. 저자 동일 FI, marker 원천 생성, 가중치 원천 도출, 원논문 동일 재현 또는 인과 해석은 승인 범위 밖이다.

## 추가 marker assertion 감사 — 앞선 미확인 판단 갱신

부모의 명시적 추가 요청으로 `prepare_nhanes.py` 생성식 구간과 derived candidate의 절대 CBC/marker 열을 대조했다. 전체 9,814행에서 기존 `near()`는 NA를 반환하며 28개의 비유한 pair가 있었다. 네 marker 모두 유한 9,786행의 mismatch는 0이고, 공통 분석 9,786행에는 비유한 pair도 0이다. 최대 절대 산술 차이는 SII에서 약 4.55e-13로 선언 허용오차보다 작다. 따라서 시도 2의 assertion 실패는 unfiltered 자료의 NA-unsafe `all()`로 재현되며 marker 값 불일치의 증거가 아니다. 앞선 로그만으로 원인 미확정이라는 판단은 이 추가 수치 검증으로 갱신된다. `marker_assertion_reconciliation.json`에 결과를 보존했다. 다만 raw XPT 변수·단위·merge와 원천 생성 전 과정의 독립 인증은 여전히 범위 밖이다.
