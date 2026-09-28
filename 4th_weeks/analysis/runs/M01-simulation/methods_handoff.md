# M01: 다중검정 모의실험 인계

이 폴더의 모든 수치와 그림은 **simulation**이다. 원자료를 읽지 않으며, 논문의 관찰 결과나 실제 Frailty Index의 타당성을 검증한 결과가 아니다. 단측 정규 z 검정은 다중검정 원리를 확인하는 독립적인 층이다. 실제 과제의 ANOVA/Welch 검정과 절차가 동일하다는 검증으로 해석하면 안 된다.

## 실행 전에 고정한 결정

`initial_plan.txt`를 첫 시뮬레이션 실행 전에 작성했다. master seed는 20260928, 셀 seed는 master seed + design_id이며 `design_and_seeds.csv`에 기록된다. 기본 B=10000, pilot B=1000, alpha=.05, n=30, 알려진 주변 표준편차=1이다. 파일럿은 실행 검증에만 사용했으며 결과에 맞추어 seed를 바꾸지 않았다. 파일럿과 본실행은 같은 master seed를 사용하지만, 행렬 차원이 달라지므로 모든 비교가 공통 난수를 사용하는 설계는 아니다.

## 자료생성 및 p값

각 반복에서 n명의 사람, k개 지표라는 정상모형을 가정한다.

X_ij = delta_j + sqrt(rho) U_i + sqrt(1-rho) E_ij.

U_i와 E_ij는 모두 독립 표준정규변수다. 한 사람의 지표들은 공통 U_i를 공유하므로 상관은 rho이며 사람들은 독립이다. 알려진 분산에서 Z_j = sqrt(n) mean_i(X_ij)의 분포는 delta_j sqrt(n) + sqrt(rho) A + sqrt(1-rho) B_j와 정확히 같다. 코드는 이 충분통계량을 직접 생성하여 원자료 배열 할당을 줄인다. 즉 균등 p값을 임의로 생성한 것이 아니라 유효한 정규 z 검정통계량에서 `pnorm(z, lower.tail=FALSE)`로 단측 p값을 계산한다. 귀무가설 delta=0에서 주변 p값은 균등분포다.

rho=0은 검정 간 독립, rho=.5는 같은 개인에게서 측정한 지표의 상관을 표현한다. 이는 반복된 같은 개인을 독립 표본으로 세는 의사반복이 아니다. n명의 독립 개인을 가정한 표본평균의 상관만 모형화한다. 실제 FI 지표의 결측, 이분형 분포, 군집, 조사설계는 모형화하지 않는다.

전역귀무의 k는 1,5,10,20,50,100이다. 혼합귀무에서는 k=5,10,20,50,100이며 처음 floor(.2*k)개 지표에 delta=.5를 부여한다. 이는 효과크기에 따른 민감도를 완전히 탐색한 연구가 아니라 FDR와 power의 의미를 구분하기 위한 보조 예시다.

## 검정군과 오류지표

각 반복의 k개 검정이 하나의 검정군이다. `p.adjust`는 이 군 안에서만 Bonferroni 또는 BH로 실행한다. 서로 다른 반복이나 설계셀 사이에 p값을 모아 보정하지 않는다. `expand.grid`가 22개 설계셀을 만들고 `Map`이 실제로 각 셀의 모의실험을 실행한다.

R=총 기각수, V=참 귀무가설 기각수, S=참 대립가설 기각수이다. FWER는 mean(V>0), FDR는 mean(V/max(R,1)), power는 mean(S/m1)로 추정한다. R=0일 때 FDP=0이다. 전역귀무에서는 FDR=FWER이며 power는 정의되지 않아 NA로 기록한다. 혼합귀무에서 FDR와 power는 서로 다른 분모를 사용한다.

독립 전역귀무의 무보정 FWER는 1-(1-alpha)^k이다. 이 공식을 rho=.5에 적용하지 않는다. Bonferroni는 유효한 주변 p값에 대해 의존성에도 FWER를 통제한다. BH는 FDR 제어 방법이며 전역귀무 밖에서 FWER를 .05 이하로 제어한다는 의미가 아니다. rho=.5 결과를 임의의 모든 의존구조에서 BH가 유효하다는 증거로 확대하면 안 된다.

## Monte Carlo 불확실성

FWER 표준오차는 sqrt(p_hat*(1-p_hat)/B), 95% 구간은 Wilson 구간이다. 전역귀무 FDR는 같은 사건이므로 같은 구간을 쓴다. 혼합귀무 FDR 및 power는 반복별 비율의 표준편차/sqrt(B)로 MCSE를 계산하며 평균 +/- 1.96 MCSE를 [0,1]로 제한한 근사구간을 기록한다. 이 구간들은 반복수에 따른 **Monte Carlo** 불확실성만 나타내며 실제 환자자료의 신뢰구간이 아니다. 구간은 pointwise이고 동시구간이 아니다. 이론값이 모든 95% 구간에 들어가야 한다는 요구는 부적절하다. 다중 시점에서 일부 구간이 이론값을 놓치는 것은 확률적으로 정상이며 seed를 골라서 일치시키지 않는다.

## 검증과 기록

`analysis/tests/test_simulation.R`은 p값 변환, 독립/상관 생성, rho=1 극한, n 및 효과크기 스케일, 손계산 V/R 및 S/m1, 무기각 처리, k=1 차원 경계, 보정법, 고정 seed 이론 검사를 수행한다. 처음 k=1 검사에서 행렬 차원이 유지되지 않는 버그가 발견되어 수정했다. 실패 로그 `test_log.txt`와 통과 로그 `test_log_after_fix.txt`를 모두 보존했다. 이 수정은 통계 결과에 맞추기 위한 seed 변경이 아니다. 확률적 검사는 사전 지정된 6 이론 표준오차 허용범위를 사용하며 수학적 증명으로 간주하지 않는다.

`execution.log`, `warnings.txt`, `sessionInfo.txt`, `run_parameters.txt`에 실행환경을 남긴다. R 4.6.1의 base/recommended 구성만 사용하고 추가 패키지는 사용하지 않았다. 현재 Windows의 잘못된 LANG/LC_ALL 환경값에 따른 시작 경고를 피하기 위해 실행 프로세스에서만 LANG=C, LC_ALL=C를 설정했다. 사용자 전역 환경은 수정하지 않았다.

`simulation_summary.csv`는 모든 오류지표, MCSE, 구간을 포함한다. `simulation_replicates.rds`에는 반복별 R/V/S/FDP/power와 설계/seed가 있다. `theory_comparison.csv`는 독립 전역귀무 무보정 결과만 비교한다. `generator_diagnostics.csv`에는 통계량 평균/분산/상관 및 주변 p<.05 비율이 있다. 세 종류의 그림은 각각 PNG와 PDF로 제공된다. 그림 제목에 SIMULATION을 표시했다.

## 재실행

PowerShell (작업폴더 기준):

```powershell
$env:LANG='C'
$env:LC_ALL='C'
& 'C:/Program Files/R/R-4.6.1/bin/Rscript.exe' 'analysis/tests/test_simulation.R'
& 'C:/Program Files/R/R-4.6.1/bin/Rscript.exe' 'analysis/src/simulation.R' --out-dir 'analysis/runs/M01-simulation' --B 10000 --seed 20260928
```

함수만 가져오려면 `source('analysis/src/simulation.R')`를 사용한다. source는 본실행을 자동 시작하지 않는다.

## 확인한 공식 R 문서

- [Normal distribution: rnorm/pnorm](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/Normal.html)
- [p.adjust: Bonferroni/BH와 오류율 정의](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html)
- [Map: 함수형 반복](https://stat.ethz.ch/R-manual/R-devel/library/base/html/funprog.html)

위 문서를 2026-09-28에 확인했다. p.adjust 문서가 연결하는 Benjamini & Yekutieli (2001)는 의존구조에서의 FDR 통제에 관한 원문이다.

## 본실행 결과와 예상 밖의 점추정치

B=10000 본실행은 22개 설계셀, 66개 방법별 요약을 산출했고 경고가 없었다. 독립 전역귀무 무보정 FWER는 k=1,5,10,20,50,100에서 .0497, .2192, .4008, .6420, .9266, .9945였다. 해당 이론값은 모두 이번 pointwise 95% 구간에 포함되었지만 이것이 매 실행 보장되는 것은 아니다. rho=.5 및 k=100의 무보정 FWER는 .5620이었다.

독립 전역귀무 k=100에서 Bonferroni 추정치는 .0556 (95% MC 구간 .05128-.06026), BH 추정치는 .0573 (.05291-.06203)으로 목표 .05보다 높았다. 따라서 모든 보정 결과가 경험적으로 .05 이하였다고 보고하면 안 된다. 이 셀의 이론적 Bonferroni FWER는 1-(1-.05/100)^100=.04878247이며 관측편차는 이론 MCSE의 3.16배이다. 독립 연속 전역귀무 BH의 이론값 .05에 대한 편차는 3.35 MCSE이다. 이런 결과를 확인하고도 seed나 반복수를 선택하여 바꾸지 않았다.

이를 계기로 `postrun_audit.R`에서 같은 원래 seed 20260934로 통계량을 재생성하고, `p.adjust` 결과를 별도 구현한 min(p)<=alpha/k 및 정렬 p_(i)<=i*alpha/k 사건과 대조했다. 10000회 모두 일치했다 (`postrun_audit.log`). 이는 구현 오류 점검이며, 특정 확률편차의 원인을 수학적으로 증명하거나 이 실행의 점추정치를 목표 이하로 만드는 조치가 아니다. 후속 연구에서 정밀도를 더 높이려면 별도의 사전 고정 확장계획을 사용할 수 있으나, 이 과제 결과는 원계획 B=10000 그대로 보존했다.

혼합귀무 독립 k=100에서 BH의 FDR=.039918, power=.597265, FWER=.4025였다. Bonferroni는 FDR=.006369, power=.289655, FWER=.0374였다. 따라서 FDR 제어가 FWER 제어와 같지 않다는 것을 보여준다. rho=.5의 BH는 FDR=.035935, power=.562465, FWER=.2010이었다.

독립/의존 통계량의 평균 상관 진단은 각각 -.000856, .501519였다. 본실행 세 PNG를 직접 열어 시각검사했고 혼합귀무 그림의 범례 위치를 곡선과 겹치지 않도록 고쳤다. 결과 수치는 변경하지 않았다. PDF는 같은 base R 그리기 함수로 함께 저장했다.
