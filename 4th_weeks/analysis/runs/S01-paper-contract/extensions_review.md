# S01 model extensions 독립 검토

실자료 실행 전 정적 검토, root 수정 확인, 완료된 실행의 출력 감사를 기록한다. 이 검토 담당은 분석 코드 수정·실자료 모형 재실행을 하지 않았다. 원자료→후보 FI 코딩은 다른 담당의 검수 범위다. 이 검토를 마친 뒤 추가 범위는 수행하지 않는다.

검토 스냅숏:

- `analysis/src/model_extensions.R` SHA256 `2AFF1A20A6ADB3EBEE229FF69F9A50BF8EE0EAD4A7642F0B0E41EDB149A11442`
- `analysis/config/extensions_plan.json` SHA256 `A331C3819573EB7DD46F236774F85440DF108C68CD33522D5BA7F64B7356B1F7`

root 수정 후 재검토한 `model_extensions.R` SHA256: `4A43374A2811F289F2970C8BDA018393F52CCA4E134A6EC6485CECADC86FE2FE`. 아래 최초 발견의 줄번호는 최초 스냅숏 기준이다.

## 결론

전체 연령 설계→후보 영역 subset, `svyglm`의 설계 기반 공분산, 예측값의 sampling-weight 평균, 같은 회귀표본에서 혈소판 항목 제외/35 분모, binary와 fractional 효과의 구분은 올바른 방향이다. 최초 발견한 **평균비교 표본의 회귀표본 종속** 및 **후보/설계 입력 정합성 검사 부재**는 root가 수정했고 변경된 코드를 직접 읽어 해결을 확인했다. 현재 검토 범위에서 미해결 중대 계산오류는 없다. 아래 최초 발견내용은 검수 이력으로 보존한다.

## 수정 확인 및 테스트 증거

- 현 수정판은 `marker_value`가 finite이고0이상인 `d_mean`에서 평균/Wald를 계산한다. 별도 `d`는 양수 logx와 공변량 완전사례로 만들어 log 모형에 사용한다. 따라서 평균검정에 필요 없는 공변량/양수 조건이 더는 적용되지 않는다.
- 현 수정판은 `match(dat$SEQN,base$SEQN)`에서 누락을 중단하고 모든 공통 열을 SEQN 순서로 대조한다. positive-weight design과 후보의 ID·가중치 불일치가 조용히 진행되는 경로를 차단한다.
- `T02-fixed-20260927T210314296655Z/execution.json`에서 exit_code0, stdout에서 합성자료32모형 수렴·bounded prediction PASS를 확인했다. CSV는32행, design_counts는 전체1600/후보1272였다. stderr는 비어 있다. 이는 합성자료 증거이며 NHANES 결과가 아니다.
- 다만 T02-fixed 로그가 기록한 `model_extensions.R` hash는 `bcaa4fe99643d5cb4d7a343c9990984663c1868fe2b01a1d35316b247876ebde`로 현 수정판 hash와 다르다. 따라서 위 PASS는 **선행 revision의 동작검증**, 두 최근 변경은 **현재 revision의 정적 검증**으로 구분한다. root에게 현 revision 합성검사 기록을 남길 것을 전달했다. 이 검토에서 같은 테스트를 중복 실행하지 않았다.

### 최종 실행 확인 — 위 revision 검증 미완료 사항 해소

추가 분석 없이 기존 실행 로그와 CSV를 읽고 다음을 확인했다.

- `T02-reviewed-20260927T210602908705Z`: exit_code0, stderr0byte, 합성32모형 수렴·예측범위 PASS. 로그 source hash가 현재 `model_extensions.R`의 `4a43374a...`와 같고 extensions_plan hash도 일치한다. 이제 현 수정판의 합성실행 검증이 확보됐다.
- `A02-20260927T210626709227Z`: exit_code0, stderr0byte. 실행 코드·확장계획 및 **두 입력파일** candidate_complete36.csv/nhanes_design_all.csv의 현재 SHA256이 실행 로그와 일치한다.
- `A01-20260927T210626704130Z`: exit_code0. 현재 group_analysis.R의 hash `366937c9e37a15ee48c64ca1ce71883c257cf37af434e402196b157a28f72c07`과 실행 hash가 같다.
- A02 design_counts: 전체 양수가중 설계88,062명, 후보FI완비9,814명, full/domain design df 모두138. A01 기준 FI군 합계는2,765+2,835+1,830+2,384=9,814명이다. 실제 네 지표 주분석과 가중군 검정은 모두9,786명이다. 9,814는 FI군 경계를 정의한 기준표본, 9,786은 해당 CBC 분석표본이므로 같은 N으로 혼용하지 않는다.
- model_sensitivities.csv는32행이며32모형 모두 `convergence=TRUE`. age60+ 네 모형은8,605명, 나머지28모형은9,786명이다. FI36과 FI35 fractional 모형도 동일9,786명이다.
- 모든32행에서 beta/SE/CI/p/지수화 효과가 finite이고 `CI_low <= estimate <= CI_high`, 지수CI 양수 및 순서, `0 <= p <= BH_p <= 1`을 프로그램으로 확인했다. weighted 모형의 **model residual df는123**, unweighted 모형은Inf이며 design df138과 구분해야 한다.
- fractional_mean_predictions.csv의 네 지표×두 예측평균은 모두[0,1] 안에 있다(약0.1583–0.1884). 차이는 점추정만 있으며 CSV에도 CI 미계산이라고 적혀 있다. 이 출력 검증은 예측값의 인과 해석이나 후보FI의 원저자 동일성을 확인한 것이 아니다.

최종 검토 상태: 두 P2 해결, 현 revision 합성PASS 및 실자료 종료/출력 정합성 확인. A03 대안 FI 코딩 분석은 이 검토 범위 밖이며 여기서 추가 검토하지 않았다.

## 발견사항

### [P2, 해결] 평균 비교가 필요 없는 log·공변량 제한까지 적용 — 최초 코드 동작

위치: R50–57. `d`를 `is.finite(logx)`와 공변량 완전사례로 제한한 뒤 `svyby`와 `FI_group`의 Wald 검정을 수행한다. 그런데 과제 주 분석은 원척도에서 유한한 0 이상 지표를 사용하고 age/sex/race/cycle 완전사례를 요구하지 않는다. 따라서 지표0이나 공변량 결측이 있으면 두 분석 간 차이에 조사설계 보정뿐 아니라 표본변화도 섞인다. MLR/SIRI 등에서0은 단순히 log에 넣을 수 없다는 이유로 제거되는 값일 수 있다. 실제 발현 여부는 자료를 확인해야 한다.

수정 제안: `d_mean`은 후보 영역 중 원척도 지표가 유효한 표본, `d_model`은 양수 지표+공변량 완전사례로 나눈다. 가중 군 평균/Wald에는 `d_mean`을, log 모형에는 `d_model`을 사용한다. 의도적으로 공통 회귀표본만 비교할 계획이라면 같은 표본의 비가중 평균/Welch도 병기하고 표본 제한을 명시한다. 분석 대상 N을 지표별로 저장한다.

### [P2, 해결] 후보 표본과 설계 영역 불일치가 조용히 허용됨 — 최초 조건부 오류 위험

위치: R7,13–31. SEQN 중복은 검사하지만 `dat`의 모든 ID가 양수가중 `base`에 존재하는지 검사하지 않는다. `des`는 positive-weight base와 교집합인데 `n_candidate`, `sample_percent`, `weighted_percent`는 원래 `dat`에서 계산한다. 공통 필드는 `merge`에서 base 값을 유지하므로 후보파일과 설계파일의 weights/원변수가 달라도 경고가 없다. 이때 기술표와 회귀가 서로 다른 사람·가중치를 가리킬 수 있다. 현재 파일에서 불일치가 실제 발생했다는 판단은 아니다.

수정 제안: domain 생성 후 후보/영역 SEQN 집합 동일성, SEQN별 결합가중치·설계변수 동일성, finite positive weight를 검사한다. 불일치를 허용할 때는 먼저 제외 흐름을 기록하고 기술표도 `des$variables`의 실제 domain에서 계산한다. `n_candidate_input`, `n_candidate_in_design`를 별도로 저장하면 추적이 쉽다.

## 확인된 정상 구현

### 조사설계와 domain

R13–22는 양수가중 전체 연령 MEC 자료에서 `svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~weight_mec_18yr,nest=TRUE)`를 만든 뒤 후보 영역을 `subset`한다. 연령50+ 자료만 별도의 일반 설계로 새로 만드는 오류는 없다. R51과 R60의 추가 domain subset도 설계 객체를 사용한다. `survey.lonely.psu='fail'`은 문제가 있는 설계를 조용히 임의 보정하지 않는다.

다만 다음은 이 함수 밖에서 확인돼야 한다: 실제 입력 `design_all`이 전체 연령인지, 1999–2002 특수 가중치와 이후 주기를 올바르게18년으로 통합했는지, 주기 사이 SDMVSTRA가 재사용되는지. `nest=TRUE`는 PSU를 strata에 중첩시키며 주기별 strata 충돌을 자동 해결하지 않는다. 여기서는 이미 만들어진 `weight_mec_18yr`를 신뢰하므로 이 검토가 가중치 산출을 검증했다고 표현하지 않는다.

### fractional FI 평균과 표준오차

R62의 weighted 경로는 `svyglm(...,family=quasibinomial())`이며 일반 `glm`의 quasi 표준오차와 다르다. survey 문서상 설계 기반 model-robust 공분산을 사용하므로 앞선 리뷰에서 지적했던 “quasibinomial이라는 이름만으로 robust가 되지 않음”의 문제는 이 경로에서 해소된다. 응답 FI의 조건부 평균에 logit link를 적용하며 FI0/1을 배제하지 않는다. 코드의 covariance `vcov(fit)`와 survey 잔여 자유도에 기반한 t CI/p는 일관된다. [survey svyglm 공식 문서](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/svyglm.html)

주의: robust SE는 FI 구성의 미확인, complete-case 선택, logit 평균함수의 해석, 잔여 교란을 해결하지 않는다. 일반 `glm`은 unweighted binary 비교에만 쓰인다. 이 비가중 결과 역시 복합표본 표준오차를 사용한 것은 아니다.

### weights 및 newdata 예측

R71–77에서 `new <- raw`로 원래 factor levels와 공변량을 유지한 채 `logx`만 p25/p75에 고정한다. 그 회귀 domain의 `weights(dd)`로 응답척도 예측을 평균하므로 **회귀 domain이 가중 대표하는 공변량 분포에 표준화한 평균 FI**의 plug-in 추정이다. 개인별 예측을 계산한 후 평균하므로 logit inverse의 비선형성 때문에 생기는 “평균 공변량 한 행에서 예측” 오류도 없다.

노출 p25/p75 자체는 R73의 **비가중 type7 logx 분위수**다. 가중 인구노출 분위수라고 라벨을 붙이면 안 된다. `adjusted_mean_FI` 및 difference에 CI를 계산하지 않는다고 명시한 점은 맞다. 나중에 CI를 추가한다면 개인별 prediction SE를 단순 평균하지 말고 계수 공분산과 표준화 절차를 반영해야 한다. 현재 `predict`는 기본값으로 SE도 계산하지만 사용하지 않으므로 `se.fit=FALSE`는 선택적인 효율 개선이다. 노출분위수 산출법·표준화 domain·원척도 exp(logx_p25/p75)를 metadata에 추가하면 해석이 분명해진다.

### 혈소판 항목 제외

R44–46의 `(FI*36-deficit_29)/35`는 완전36항목 binary FI를 전제로 한 올바른 식이다. 두 fractional 모형은 동일한 `d` 및 공변량으로 적합하고 FI35 결측으로 새 사람을 포함시키지 않는다. 이로써 참여자 변경에 의한 차이를 억제한다. FI35로 군을 다시 만들거나 binary 역치를 바꾸지는 않으며 현재 구현은 연속평균 fractional 결과끼리의 비교다.

추가 입력검사 제안: `deficit_29`의0/1 여부와 `FI*36`이 원항목 합과 일치하는지 확인한다. 현재 범위검사만으로 부분점수 FI나 잘못된29번 항목까지 판별할 수는 없다. 이를 FI 구성 담당이 이미 검사했다면 그 검증 산출물을 연결하면 충분하다. 미세 floating-point 오차가 FI35를 [0,1] 밖으로 만든 경우 단순 넓은 허용범위 검사 뒤 GLM에 그대로 넣지 말고 원항목 정수합에서 계산한다.

### binary OR 라벨과 family

threshold 그림 R96–99는 weighted binary 모델 네 개만 선택해 OR로 표시한다. fractional `exp_beta`를 OR 그림에 섞지 않는다. 실행 주석 R105에도 fractional exp(beta)는 binaryfrailty odds가 아님을 명시한다. CSV의 `exp_beta`는 중립적이나 혼합표를 읽는 사람을 위해 `estimand`, `effect_label`, `outcome_kind` 열을 추가하는 것을 권고한다.

각 지표별 unweightedbinary1+weightedthreshold4+age60binary1+fractional36+fractional35=8개, 네 지표 총32개이므로 R87 및 계획의 BH32는 일치한다. 가중 군 평균 Wald4개의 보정은 별도 family다. 이를 합한 전역 family 통제라고 주장하지 않아야 한다. 임의 의존구조에서 BH FDR 보장을 단정하지 않는 조건은 앞선 검토와 같다.

## 추가 실행 점검과 라벨 제안

- `nrow(dd$variables)`가 실제 모형 사용 N인지 확인하고 `nobs(fit)`와 대조한다. logx는 finite 및 covariate는 complete 검사하지만 age의 Inf, response 결측, 설계 입력 불일치까지 포괄하지는 않는다.
- binary 모델별 event/non-event 수, 최소 domain PSU/strata 수, design df와 model residual df, 수렴 경고, 완전분리 여부를 기록한다. `fit$converged`만 저장한다고 모든 부적합 모형이 제외되는 것은 아니다. df<=0·비유한beta/SE·convergedFALSE이면 CI/p를 해석 가능한 결과로 내보내지 않는다.
- `survey_group_means.csv`는 현재 mean과SE만 있고 군별 N/CI가 없다. 지표별 군 N과 design subset 조건을 추가하는 것을 권고한다. `survey_group_tests.csv`의 `design_df`는 `regTermTest`의 denominator df 자체와 다를 수 있으므로 Wald statistic·numerator df·test denominator df를 따로 저장하면 좋다.
- Spearman R35–36은 네 지표 모두 양수인 완전사례 표본의 **비가중** 상관이다. 로그는 양수에서 순서를 보존하므로 상관값 자체에 필요하지 않지만0을 제거하는 표본 제한이 생긴다. 그 의도가 없다면 원척도 finite값으로 계산한다. 그림에 unweighted 및 해당 N을 기록한다.
- FI군은 과제에서 정의한 비가중 기준표본 quartile를 사용한다. 이를 “가중 인구 FI사분위”라 부르면 안 된다. 이는 표본에서 정의한 FI구간에 대한 가중 domain 평균이다.
- natural log1단위 OR는 지표가 e배일 때의 OR다. “지표1단위”와 혼동하지 않도록 threshold 그림에 ln이라고 표시하면 좋다.
- 분수반응 모형은 conditional mean의 모형이며 `exp_beta`가 결손확률이나 독립36trial의 OR라는 보장은 없다. 평균FI의 p25→p75 표준화 차이는 binary OR와 단위가 다른 결과다.
- complete-case FI 대상에 MEC 가중치를 적용했다고 그 대상의 선택편향이 교정되는 것은 아니다. 원문과 동일한FI·동일표본을 확보했다는 주장도 여전히 불가하다. 계획의 한계 문구는 적절하다.

## 판단 범위

두 P2 수정과 현 revision의 합성/실자료 실행기록·출력 정합성을 확인했다. 일반적인 입력검증·출력 해석 제안은 남아 있으나 이번 감사에서 새로운 중대 오류는 발견하지 않았다. 이 검토는 출판 OR에 가까운 모형을 고르기 위한 검토가 아니며, 가중효과·역치민감도·나이60+·fractionalFI·FI35 모두 별도 질문을 다루는 탐색적 분석이다.
