"""Append reviewed result blocks to EXISTING notes, preserving every existing byte.
Does not invoke the old HTML builder or create a separate final report.
"""
from pathlib import Path
import csv,json,hashlib,re
from project import ROOT,WORK,write,event,sha

RUN=ROOT/'runs'
def rows(name):
    with (RUN/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def table(headers,data):
    return '| '+' | '.join(headers)+' |\n|'+ '|'.join(['---']*len(headers))+'|\n'+ '\n'.join('| '+' | '.join(map(str,row))+' |' for row in data)
def n(x):return f'{float(x):,.0f}'
def f(x,d=3):return f'{float(x):.{d}f}'
def p(x):return f'{float(x):.3g}'
def link(label,path):return f'[{label}](../../analysis/{path})'
def image(label,path):return '!'+link(label,path)
def selected(data,**conditions):return next(r for r in data if all(r[k]==v for k,v in conditions.items()))

prov=json.loads((RUN/'S02-nhanes-data/fi_candidate_provenance.json').read_text(encoding='utf-8'))
trace=json.loads((RUN/'S02-nhanes-data/fi_candidate_one_person_trace.json').read_text(encoding='utf-8'))
with (ROOT/'data/derived/candidate_complete36.csv').open(encoding='utf-8',newline='') as inp:
    person=next(r for r in csv.DictReader(inp) if float(r['SEQN'])==float(trace['SEQNunidentified']))
summary=rows('A01-groups/summary.csv');primary=rows('A01-groups/primary.csv')
group=rows('A01-groups/group_membership_summary.csv');pairs=rows('A01-groups/pairwise.csv')
trend=rows('A01-groups/trend.csv');models=rows('A02-models/model_sensitivities.csv')
perc=rows('A02-models/sample_vs_weighted_percent.csv');pred=rows('A02-models/fractional_mean_predictions.csv')
sens=rows('A03-coding/same_people_summary.csv')[0];ret=rows('A03-coding/retention_by_demography.csv')
welch_survey=rows('A02-models/survey_group_tests.csv')
blocks={}
blocks['00-start']=f'''## 공개 NHANES로 실행한 분석 — 2026-09-28 추가

**현재 위치:** 코드 작성에 이어 공개자료 분석·통계 검토·모의실험까지 실행했습니다. 아래 결과는 저자 코드가 확인된 완전 재현이 아니라, 미공개 FI 규칙을 명시적으로 정한 **operational36 재구성 후보**의 분석입니다. 논문의 13,507명과 동일한 분석집단이라고 주장하지 않습니다.

공개 9개 조사 주기 전체 92,062명 → 50세 이상 24,119명 → 후보 FI 36항목 완비 9,814명 → 네 혈액지표 분석 9,786명입니다. 같은 FI 값은 같은 군에 두므로 FI군의 인원은 정확히 25%씩 나뉘지 않습니다.

```mermaid
flowchart TD
    A["공개 NHANES: 한 사람의 설문·혈액·검진 측정값"] --> B["코드북·단위·0값·결측·개인 ID 검증"]
    B --> C["NLR·MLR·SIRI·SII 계산"]
    B --> D["36항목 후보 FI<br/>저자 미공개 규칙과 구현 가정 구별"]
    C --> E["대상자·결측·표본선택 확인"]
    D --> E
    E --> F["과제: FI 사분위군별 염증지표 평균 비교"]
    E --> G["논문 연결: FI>0.3 로지스틱 Model1 후보"]
    F --> H["Welch·ANOVA·KW → 사후비교·다중보정·진단"]
    G --> I["설계가중·FI 역치·연속 FI·혈소판 중복 점검"]
    H --> J["검토된 결과를 기존 단계 문서에 추가"]
    I --> J
    K["독립 모의실험: 원리 22설계 + 실제 검정 4설계"] --> J
```

| 확인할 내용 | 기존 문서의 추가 부분 |
|---|---|
| 한 사람의 혈구 수 → 염증지표 → FI와 군 | [[01-paper]], [[02-paper]], [[03-paper]] |
| 왜 최종 표본이 줄고 인구 비율이 달라지는가 | [[04-paper]], [[05-paper]] |
| OR·가정·보정 회귀와 연속 FI의 차이 | [[06-paper]], [[07-paper]], [[08-paper]] |
| 과제의 실제 군 비교 결과·사후검정·경향성 | [[09-paper]] |
| 검정이 제대로 작동하는가·추가 분석의 한계 | [[10-paper]] |

네 지표의 FI군 평균 차이는 다중보정 후에도 관찰됐습니다. 그러나 50–59세는 16.5%, 60세 이상은 50.9%만 후보 FI 완비자로 남았습니다. 이는 대표성과 결측 선택을 검토해야 한다는 결과이며, 작은 p값으로 해결되지 않습니다. FI 코딩 세 규칙을 함께 바꾸자 같은 9,814명 중 250명의 이진 분류, 1,412명의 사분위군이 바뀌었습니다.

**실행과 설명의 위치:** {link('R 구현·VS Code 실행 안내','README.md')}, {link('작업 명세·의존관계','memory/task_registry.json')}, {link('현재 상태와 제한','memory/progress.md')}, {link('이벤트 로그','memory/events.jsonl')}. 문서의 설명을 분석 코드 대신 사용하지 않습니다. 이번에는 기존 Markdown과 Obsidian 노트에 결과를 추가했으며, HTML은 다시 생성하지 않았습니다.

**아직 판정할 수 없는 부분:** 저자와 정확히 같은 FI/결측 처리, 논문 표본수의 완전 일치, Model2 전체 및 원문 spline 설정의 동일 재현. 미공개 정의를 추정하여 출판 수치에 맞추는 대신 확인되지 않은 것으로 남겼습니다. 이번 완료 범위는 과제에 필요한 군 비교·모의실험과 명시된 후보 자료의 추가 타당성 점검입니다.
'''
blocks['01-paper']=f'''## 실행에서 한 사람을 끝까지 추적하기

**들어오는 자료:** 공개 NHANES 식별자 SEQN={n(person['SEQN'])}, 조사 {person['cycle']}, 공개 연령 {n(person['RIDAGEYR'])}세인 한 행입니다. 가상 자료가 아니며 실제 개인 신원을 알아내는 작업은 하지 않았습니다.

| 단계 | 이 행에서 계산한 값 | 이 값의 역할 |
|---|---|---|
| CBC | 호중구 {f(person['LBDNENO'])}, 림프구 {f(person['LBDLYMNO'])}, 단핵구 {f(person['LBDMONO'])}, 혈소판 {f(person['LBXPLTSI'])} | 원 측정값, 단위 10³/µL |
| 염증지표 | NLR {f(person['NLR'])}, MLR {f(person['MLR'])}, SIRI {f(person['SIRI'])}, SII {f(person['SII'])} | 네 가지 설명변수 후보 |
| FI | 결핍 합 {sum(trace['item_values'].values()):.0f}/36 = {f(person['FI'],4)} | 명시한 후보 규칙으로 계산한 노쇠 점수 |
| 이진 결과 | FI>0.3 → {int(float(person['FI'])>.3)} | 로지스틱의 반응값 |
| 과제 비교군 | {('Q1' if float(person['FI'])<=1/12 else 'Q2' if float(person['FI'])<=1/6 else 'Q3' if float(person['FI'])<=.25 else 'Q4')} | FI 사분위군의 구성원 |

**집단 결과로 넘어가는 과정:** 이 사람의 NLR은 소속 군의 합계·평균·잔차 계산에 기여합니다. 회귀에서는 이 사람의 FI 이진값과 공변량이 다른 모든 사람의 행과 함께 계수 추정에 기여합니다. 개인 한 명에게 OR나 p값을 직접 붙이는 과정이 아닙니다.

원문 항목 → 원변수 → 결핍값의 연결은 {link('36항목 매핑','runs/S02-nhanes-data/fi36_candidate_variable_availability.csv')}과 {link('이 사람의 36항목 계산 기록','runs/S02-nhanes-data/fi_candidate_one_person_trace.json')}에 있습니다. FI의 실제 저자 코딩이 아니라 재구성 후보라는 표시는 이후 단계에서도 유지합니다.
'''
blocks['02-paper']=f'''## 구현·검토: 같은 혈구에서 만든 지표를 독립 증거로 세지 않기

**입력 → 구현:** CBC 수치를 개인별 SEQN으로 결합했습니다. 림프구가 양수일 때 NLR=N/L, MLR=M/L, SIRI=N×M/L, SII=P×N/L을 계산했습니다. 로그 모형은 양수 지표만 사용합니다. 단위와 코드북은 {link('자료 출처와 주의점','runs/S02-nhanes-data/data_provenance_and_caveats.json')}에 연결했습니다.

**검토 결과:** 실제 분석 표본에서 Spearman 상관은 NLR–SII=0.851, NLR–SIRI=0.822, MLR–SIRI=0.787입니다. 분자·분모를 공유하므로 네 결과를 서로 독립적인 네 번의 입증으로 세면 안 됩니다. 각 지표를 하나씩 넣은 모형을 실행했고, 네 지표를 한 모형에 동시에 넣어 독립 효과를 분해했다고 주장하지 않습니다.

{image('네 혈구 유래 지표의 Spearman 상관','runs/A02-models/marker_correlations.png')}

**추가 질문의 처리:** FI 자체에도 혈소판 결핍 항목이 있습니다. 같은 사람에서 해당 항목을 빼고 35로 나눈 FI를 분석하는 추가 작업을 실행했습니다([[10-paper]]). 이 변화는 공유 항목에 대한 민감도 점검이며 생물학적 독립성의 증명은 아닙니다. CRP·IL-6는 이 네 비율과 같은 측정물이 아니며, 이번 분석에서 추가 측정하거나 서로 대체 가능한 지표로 검증하지 않았습니다.
'''
blocks['03-paper']=f'''## 구현·검토: 원문 FI와 재구성 후보를 구별하기

**확인한 것:** 본문과 부록 S1에서 36항목과 검사 범위를 확인했습니다. 직접 인용한 선행논문의 부록까지 조사했지만 설문 이분화·허용 결측·분모 규칙을 모두 찾지는 못했습니다. Fried의 5개 신체 표현형 기준은 여기서 FI를 계산하는 대체 코드가 아닙니다. 이 분석의 결과변수는 결핍 누적 FI입니다.

**고정한 구현 가정:** 예/아니오는 1/0, 기능곤란은 없음=0·조금/많이/불가능=1, 활동을 하지 않음·검사 누락·응답 거절은 결측으로 뒀습니다. 주관적 건강은 fair/poor, 처방약은 5개 이상, 의료 이용은 6회 이상을 결핍으로 정했습니다. 이 임계값은 저자에게 확인된 기준이 아닙니다. 정상 검사 범위의 양 끝은 정상에 포함했습니다. 전체 규칙은 {link('FI 설정','config/fi_candidate.json')}에 있습니다.

**왜 36항목 완비인가:** 저자의 부분결측 분모를 알 수 없어 후보에서는 36개 모두 관측된 경우에만 합/36을 계산했습니다. 임의 분모 축소를 피하는 재구성 선택이지만, 완전사례만 남기는 것이 편향을 없애는 것은 아닙니다. 실제 선택의 영향은 [[04-paper]]에서 확인합니다. 초기 조사 의료이용 범주 ‘4–9회’는 6회 이상인지 알 수 없어 결측 처리했습니다. 범주 코드 3을 실제 방문 3회로 읽지 않았습니다.

**규칙 변경을 실험한 결과:** 같은 9,814명에서 건강 상태 경계를 한 단계 넓히고, 약물을 4개 이상·의료이용을 4회 이상으로 변경했습니다. 평균 FI는 {f(sens['mean_FI'],4)}→{f(sens['mean_FI_alt'],4)}, FI>0.3 인원은 {n(sens['frail_primary'])}→{n(sens['frail_alt_same_people'])}입니다. {n(sens['changed_binary'])}명의 이진 분류와 {n(sens['changed_quartile'])}명의 사분위군이 달라졌습니다. 세 규칙을 함께 바꿨으므로 어느 한 규칙의 단독 효과라고 말하지 않습니다.

{link('같은 사람 코딩 민감도 결과','runs/A03-coding/same_people_summary.csv')} · {link('군 이동표','runs/A03-coding/group_transition_same_people.csv')} · {link('변경 규칙 군 비교','runs/A03-coding/alternative_same_people/primary.csv')}

0.3의 임상적 최적성을 이 자료의 p값으로 결정하지 않았습니다. 0.20·0.25·0.30·0.35의 민감도는 [[10-paper]], 연속 FI를 유지한 모형은 [[08-paper]]에 연결합니다.
'''
blocks['04-paper']=f'''## 구현·검토: 표본을 만드는 규칙부터 결과의 일부다

{table(['선정 단계','인원','해석'],[
 ['9개 주기 DEMO','92,062','공개 조사 참여자'],['공개 연령 ≥50','24,119','원자료 연령 조건'],['후보 FI 36개 완비','9,814','자가보고·검사·코딩 조건 모두 충족'],['네 지표 분석','9,786','FI군 경계는 앞의 9,814명에서 먼저 고정'],['논문 보고 분석집단','13,507','위 후보 분석집단과 동일하지 않음']])}

논문 흐름도에서 92,062−70,392=21,670명이 연령 제외 후 남는 것으로 계산되지만, 현재 공개자료의 RIDAGEYR≥50은 24,119명입니다. 이 차이는 미해결로 남겼습니다. 출판 인원에 맞추려고 연령 제한이나 누락 규칙을 바꾸지 않았습니다.

{table(['연령','원자료 인원','FI 완비 인원','남은 비율'],[[r['level'],n(r['n_available']),n(r['n_primary']),f(r['retained_percent'],1)+'%'] for r in ret if r['variable']=='age_band'])}

**이 결과가 제기하는 문제:** 일부 50–59세는 선행 문항 응답에 따라 기능곤란 문항이 생략됩니다. 결측을 그대로 남기는 후보 규칙이 연령별 선택을 다르게 만들었습니다. 규모가 크다는 사실만으로 목표 인구의 대표성이 확보되지는 않습니다. 조사 가중치도 이 완전사례 선택을 자동으로 복구하지 않습니다.

**설계 구현:** 모든 연령의 양수 MEC 가중치 88,062명으로 strata·PSU 설계를 먼저 만들고, 분석집단을 하위 모집단으로 선택했습니다. 1999–2002는 4년 가중치×4/18, 이후는 2년 가중치×2/18을 사용했습니다. 단면자료이므로 시간 순서와 인과효과는 여전히 확인되지 않습니다.

{link('주기·연령별 상세 선정 흐름','runs/S02-nhanes-data/fi_candidate_retention_flow.csv')} · {link('성별·인종별 보존율','runs/A03-coding/retention_by_demography.csv')} · [CDC 가중치 안내](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx)
'''
nlr=[r for r in summary if r['marker']=='NLR']
blocks['05-paper']=f'''## 구현·검토: Table 1의 요약을 실제 행에서 계산하기

**논문 표의 복사와 구분:** 다음은 재구성 후보 자료의 기술통계입니다. 원문 Table 1을 재현했다는 표시는 하지 않습니다. 과제에 맞춰 **FI군별 NLR**을 요약합니다.

{table(['FI군','유효 인원','평균','중앙값','Q1–Q3 (중간 50%)'],[[r['group'],n(r['n']),f(r['mean']),f(r['median']),f(r['p25'])+'–'+f(r['p75'])] for r in nlr])}

예를 들어 Q1군 NLR 중앙값 {f(nlr[0]['median'])}는 값의 가운데 위치입니다. 표의 {f(nlr[0]['p25'])}–{f(nlr[0]['p75'])}는 가운데 50%의 구간이며, IQR의 **폭**은 {float(nlr[0]['p75'])-float(nlr[0]['p25']):.3f}입니다. 이것을 평균의 신뢰구간으로 해석하지 않습니다. 평균이 중앙값보다 큰 모습은 오른쪽 꼬리의 영향을 함께 보게 합니다.

**인구 비율이 달라지는 계산:** 후보 FI 완비 여성은 4,861/9,814=49.53%입니다. 그러나 각 사람이 대표하는 인원에 MEC 가중치를 곱한 여성 비율은 53.71%입니다. 전자는 관측된 사람 수의 비율, 후자는 조사 설계 가중 비율입니다. 수치가 다른 것 자체가 오류는 아니며, 가중 비율에도 완전사례 선택 한계가 남습니다.

{link('네 지표 기술통계 전체','runs/A01-groups/summary.csv')} · {link('관측 비율과 가중 비율 대조','runs/A02-models/sample_vs_weighted_percent.csv')}

분포를 요약한 다음에 “차이가 표본 변동만으로 설명되는가?”라는 검정으로 넘어갑니다. Table 1의 p값이 교란의 크기를 판정하거나 회귀 공변량을 자동 선택하는 기준은 아닙니다.
'''
rn=selected(models,marker='NLR',analysis='weighted_binary_FI_gt_0.30_model1')
blocks['06-paper']=f'''## 실행 결과에서 OR를 읽는 예

**입력:** 후보 FI>0.3을 1, 나머지를 0으로 두고 자연로그 NLR 및 연령·성별·인종·조사주기를 사용했습니다. 설계 가중 로지스틱의 NLR OR는 {f(rn['exp_beta'])}, 점별 95% CI는 {f(rn['exp_ci_low'])}–{f(rn['exp_ci_high'])}였습니다.

이는 같은 공변량 조건에서 **NLR이 e배가 되는 자연로그 1단위 증가**와 현재 후보 노쇠 오즈의 연관성입니다. NLR 1단위 증가, 확률의 배수, 미래 노쇠 위험비로 읽지 않습니다. NLR 두 배에 대한 OR는 exp(β×ln2)로 환산하며, 기준 확률을 지정하지 않고 확률 증가량을 바로 계산할 수 없습니다.

오즈를 사용한 이유는 이진 반응의 확률을 0–1 안에 두는 logit 모형을 선택했기 때문입니다. 이 선택은 FI를 이분화하는 결정 이후에 나옵니다. 연속 FI를 유지하면 질문과 모형이 바뀝니다([[08-paper]]). 위 값은 원문 발표 OR가 아니라 후보 자료 실행 결과입니다.
'''
blocks['07-paper']=f'''## 실행·진단: 정규성·이분산·영향점을 따로 확인하기

**전처리 검증:** XPT의 0이 Python 판독에서 약 5.4×10⁻⁷⁹로 읽히는 문제를 발견했습니다. 정확한 해당 표현만 0으로 복구하고 R의 별도 판독기와 6개 파일 268,632개 값을 비교했습니다. 수치와 0 분류가 일치했습니다. 원본 XPT는 보존했습니다. {link('대조 기록','runs/S02-nhanes-data/xpt_zero_crosscheck.json')}

**아래는 ANOVA의 진단입니다. 로지스틱의 정규성 검사가 아닙니다.**

{image('NLR ANOVA의 네 가지 잔차 진단','runs/A01-groups/diagnostics_NLR.png')}

| 그림 | 확인하는 질문 | 이번 해석 |
|---|---|---|
| 잔차–적합값 | 군 평균 주변의 퍼짐이 같은가 | 네 군이므로 적합값이 네 위치에 모임 |
| Q–Q | 잔차 꼬리가 정규분포와 비슷한가 | 오른쪽 꼬리의 큰 이탈 확인 |
| Scale–Location | 표준화 잔차 퍼짐이 적합값에 따라 달라지는가 | 등분산을 무조건 전제하기 어려움 |
| 잔차–레버리지 | 일부 행이 추정에 큰 영향을 줄 가능성이 있는가 | 큰 잔차는 조사 대상이며 자동 삭제 사유가 아님 |

MLR·SIRI·SII에도 동일한 네 진단을 생성했습니다: {link('MLR','runs/A01-groups/diagnostics_MLR.png')}, {link('SIRI','runs/A01-groups/diagnostics_SIRI.png')}, {link('SII','runs/A01-groups/diagnostics_SII.png')}.

로지스틱은 설명변수의 정규분포를 요구하지 않습니다. 대신 평균 구조의 적절성, 연속 설명변수와 logit의 형태, 표본 설계, 분리 현상과 수렴을 확인해야 합니다. 이번 모형은 수렴을 확인하고 설계 기반 표준오차를 사용했지만, 모든 비선형성·잔여 교란을 해소했다고 주장하지 않습니다. Welch도 심한 왜도에서 언제나 정확한 유의수준을 보장하지 않습니다. 실제 검정 코어를 대상으로 한 모의실험은 [[10-paper]]에 있습니다.
'''
binary=[selected(models,marker=m,analysis='weighted_binary_FI_gt_0.30_model1') for m in ['NLR','MLR','SIRI','SII']]
blocks['08-paper']=f'''## 실행·검토: 보정 모형과 결과변수 변경을 분리하기

**실행한 논문 연결 모형:** 각 지표를 하나씩 자연로그 변환하고 연령·성별·인종·조사주기를 보정했습니다. 후보 FI>0.3의 Model1 구조입니다. 조사 설계를 적용한 결과는 다음과 같습니다. 전부 동일한 9,786명을 사용하며, CI는 점별 구간입니다.

{table(['지표','OR / 자연로그 1단위','95% CI'],[[r['marker'],f(r['exp_beta']),f(r['exp_ci_low'])+'–'+f(r['exp_ci_high'])] for r in binary])}

비가중 Model1도 함께 저장했습니다. 이것은 두 분석집단을 혼합한 비교가 아닙니다. Model2의 신체활동·식이 등 정의와 결측 조건을 저자와 동일하게 확인하지 못해, 이를 임의 조합한 모형을 Model2 재현이라고 부르지 않았습니다. Model1과 Model2의 차이는 통계기법의 우열이 아니라 보정하는 정보의 차이입니다.

**연속 FI 대안:** 설계 기반 `svyglm(..., family=quasibinomial())`으로 E(FI|X)의 logit을 추정했습니다. 0·1도 평균 모형의 입력이 될 수 있으며, 일반 `quasibinomial` 이름만으로 robust 표준오차가 생기는 것은 아닙니다. 여기서는 survey 설계로 표준오차를 계산했습니다. beta regression은 (0,1) 연속 분포 가정과 경계값 처리를 추가로 요구합니다. 이 후보 FI는 1/36 간격의 이산 점수이므로 이번 대안은 평균 구조를 직접 다루는 fractional logit으로 고정했습니다. beta regression이 항상 불가능하다는 뜻은 아닙니다.

{table(['지표','낮은 지표값에서 조정 평균 FI','높은 지표값에서 조정 평균 FI','차이'],[[r['marker'],f(r['adjusted_mean_FI_at_p25'],4),f(r['adjusted_mean_FI_at_p75'],4),f(r['difference'],4)] for r in pred])}

여기서 낮음/높음은 해당 로그 지표의 비가중 25·75백분위입니다. 다른 공변량은 관측 분포에 두고 가중 평균 예측했습니다. 위 값은 예측 점추정치이며 CI를 계산하지 않았습니다. 인과적 개입 효과도 아닙니다. **fractional 모형의 exp(β)를 ‘노쇠 여부 OR’로 해석하면 안 됩니다.**

{link('32개 모형 계수·SE·CI·수렴·탐색적 BH 결과','runs/A02-models/model_sensitivities.csv')} · {link('fractional 예측 정의와 값','runs/A02-models/fractional_mean_predictions.csv')} · {link('독립 코드 검토','runs/S01-paper-contract/extensions_review.md')}
'''
blocks['09-paper']=f'''## 과제 실행: FI 사분위군 사이에서 혈액지표 비교하기

**먼저 질문을 구별합니다.** 위 원문 Table 3은 염증지표 사분위군을 설명변수로, FI 이진값을 결과로 삼습니다. 과제는 **FI 사분위군을 설명변수로, 연속 염증지표를 결과로** 삼습니다. 서로 뒤집힌 질문이므로 같은 결과를 재현하는 검정이라고 부르지 않습니다.

**군 생성:** 후보 FI 완비 9,814명에서 비가중 type7 분위수 경계를 0.08333·0.16667·0.25로 정했습니다. 경계값은 낮은 군에 포함했습니다. FI가 1/36 단위라 동점이 많으며, 같은 FI를 억지로 다른 군으로 나누지 않았습니다.

{table(['군','FI 범위','군 정의 인원','분석 가능한 인원'],[[g['group'],z,g['n'],nlr[i]['n']] for i,(g,z) in enumerate(zip(group,['≤0.08333','>0.08333, ≤0.16667','>0.16667, ≤0.25','>0.25']))])}

{image('FI군별 혈액지표 상자그림; 표시 축만 로그','runs/A01-groups/boxplots_log_axis.png')}

보기 쉽게 **축만 로그로 표시**했습니다. 원척도 평균 비교는 바뀌지 않았으며 극단값을 제거하지 않았습니다. {link('원척도 상자그림','runs/A01-groups/boxplots.png')}과 {link('평균·점별 CI','runs/A01-groups/means_with_pointwise_CI.png')}도 보존했습니다.

**전체 비교:** 질문이 평균 차이이므로 Welch ANOVA를 주 검정으로 사전에 선택했습니다. ANOVA와 Kruskal–Wallis도 과제 비교용으로 모두 계산했습니다. KW를 자동으로 ‘중앙값 검정’이라고 부르지 않습니다.

{table(['지표','Welch p','4지표 Bonferroni p','설계 기반 평균검정 p'],[[r['marker'],p(r['p']),p(r['p_bonferroni']),p(selected(welch_survey,marker=r['marker'])['p'])] for r in primary])}

설계 기반 열은 하위 모집단을 유지한 survey Wald 검정입니다. 보통의 ANOVA를 그대로 가중 ANOVA라고 이름만 바꾼 결과가 아닙니다. 네 지표의 군 차이는 보정 후에도 관찰되지만, 인과관계·FI의 임상적 타당성·모든 군 사이의 차이를 자동 입증하지 않습니다.

**어느 군이 다른가:** 네 군에서 6쌍×4지표=24개 Welch t 비교를 하나의 family로 정했습니다. 방향은 높은 FI군−낮은 FI군입니다. Q4−Q1의 예는 다음과 같습니다.

{table(['지표','평균 차이 Q4−Q1','점별 95% CI','24개 Bonferroni p'],[[r['marker'],f(r['estimate']),f(r['ci_low'])+'–'+f(r['ci_high']),p(r['p_bonferroni'])] for r in pairs if r['contrast']=='Q4-Q1'])}

위 CI는 다중비교 동시 구간이 아닙니다. Tukey는 ANOVA 가정하에 **각 지표 내부 6쌍**의 동시 구간과 보정 p를 따로 냈습니다. Welch 24개 family와 보호 범위가 다릅니다. BH는 적절한 독립성·양의 의존 조건에서 FDR을 제어하며, 임의의 의존에서 항상 보장되는 것은 아닙니다.

**경향성:** 각 사람의 FI 대신 소속 군의 FI 중앙값을 점수로 넣고, 염증지표와의 선형 관계를 HC3 표준오차로 추정했습니다. 이는 군 중앙값 점수 1단위당 평균 변화이며 개인 FI의 연속 기울기와 다릅니다. 네 경향 검정은 별도 family로 보정했습니다. 유의한 직선 기울기는 모든 구간에서 단조 증가함의 증명이 아닙니다.

{link('세 전체검정 모두','runs/A01-groups/omnibus.csv')} · {link('24개 쌍대 비교','runs/A01-groups/pairwise.csv')} · {link('Tukey','runs/A01-groups/tukey.csv')} · {link('HC3 경향성','runs/A01-groups/trend.csv')} · {link('코드','src/group_analysis.R')}
'''
blocks['10-paper']=f'''## 추가 분석·검정 검토: 무엇을 확인했고 무엇은 남았나

**FI 역치 민감도:** 같은 표본·같은 공변량에서 기준을 >0.20, >0.25, >0.30, >0.35로 바꿨습니다. 네 지표 모두 양의 연관 방향이 유지됐지만, 이것으로 0.3이 최적이라고 결론 내릴 수 없습니다. 각 기준은 서로 다른 이진 결과를 정의합니다.

{image('FI 역치별 Model1 OR와 점별 CI','runs/A02-models/threshold_sensitivity.png')}

**혈소판 중복:** FI36에서 혈소판 항목을 뺀 FI35를 동일한 사람의 fractional 모형에 넣었습니다. SII의 로그 계수는 {f(selected(models,marker='SII',analysis='weighted_fractional_FI')['beta_logx'],4)}→{f(selected(models,marker='SII',analysis='weighted_fractional_FI_without_platelets')['beta_logx'],4)}였습니다. 수학적 공유 한 항목에 대한 민감도이며, 모든 교란·공통 원인·측정오류가 사라졌다는 뜻은 아닙니다. 60세 이상으로 제한한 분석도 {link('모형 전체표','runs/A02-models/model_sensitivities.csv')}에 포함했습니다. 50세 미만은 이번 후보 자료에 없으므로 그 집단과 비교하여 최적 하한을 검증하지 않았습니다.

**모의실험 1 — 다중검정 원리:** `expand.grid`로 22개 조건, `Map`으로 반복 설계를 실행했습니다. 각 조건 B=10,000, seed를 고정했습니다. 알려진 분산의 z 검정을 이용하므로 실제 ANOVA 구현 확인과는 구분합니다. 독립 전역귀무에서 k=100 무보정 FWER 추정은 0.9945, 이론 1−0.95¹⁰⁰=0.99408입니다. 모든 독립 무보정 k 조건의 이론값이 해당 점별 95% Monte Carlo 구간 안에 있었습니다. 상관 0.5에서는 k=100 추정 0.5620으로 달랐으며 독립 공식을 강제로 맞추지 않았습니다.

{image('검정 개수와 적어도 한 번의 거짓 양성 확률','runs/M01-simulation/fwer_inflation.png')}

{image('전역귀무의 원 p값 분포','runs/M01-simulation/null_raw_p_histogram.png')}

귀무가설하 유효한 연속 p값의 균등 분포를 시각적으로 점검했습니다. 보정된 p값이나 실제 염증 자료의 p값까지 균등해야 하는 것은 아닙니다. **불편한 결과도 보존했습니다:** 독립 전역귀무 k=100에서 Bonferroni 추정 0.0556, BH 0.0573으로 각 Monte Carlo 구간이 0.05를 웃돌았습니다. 같은 seed의 사건을 독립 계산으로 대조했으며 seed를 다시 골라 성공처럼 만들지 않았습니다. 원인을 확정하지 않았고, 유한 모의실험이 이론을 증명하거나 모든 실행값이 0.05 이하임을 보장하지 않는다고 기록했습니다.

**모의실험 2 — 실제 비교 코드:** 실제 `comparison_core()`를 호출하여 군당 n=30, 4개 시나리오×B=2,000회를 실행했습니다. 다음은 기각 비율입니다.

| 생성 조건 | ANOVA | Welch | KW | 무엇을 읽는가 |
|---|---:|---:|---:|---|
| 정규 등분산 귀무 | .0495 | .0510 | .0450 | 명목 0.05와 경험적 크기 비교 |
| 정규 이분산·동일 평균 | .0615 | .0500 | .0610 | KW는 분포 동일 귀무가 거짓이므로 size가 아님 |
| 동일 lognormal 귀무 | .0410 | .0620 | .0500 | 왜도에서 근사 검정의 작동 확인 |
| 평균 차이가 있는 대립 | .4890 | .4785 | .4610 | 거짓 양성률이 아닌 검정력 |

lognormal에서 Welch 0.0620의 Monte Carlo 95% 구간은 0.05225–0.07343입니다. Welch가 모든 왜도 조건에서 정확한 수준을 유지한다고 쓰지 않습니다. 이 실험은 실제 표본의 크기·상관·복합표본을 그대로 재현하지 않았으며, 6쌍 family 검증으로 실제 24개 family 전체를 검증했다고 주장하지 않습니다. Tukey·HC3·FI 측정 타당성은 이 모의실험의 검증 범위 밖입니다.

{link('이론 대조·MC 구간','runs/M01-simulation/theory_comparison.csv')} · {link('원리 실험 전체','runs/M01-simulation/simulation_summary.csv')} · {link('실제 절차 실험','runs/M02-procedure/omnibus_summary.csv')} · {link('6쌍 다중비교 실험','runs/M02-procedure/pairwise_summary.csv')} · {link('독립 검토와 한계','runs/M02-procedure/review.md')}

**이번에 해결한 질문의 수준:** 실행 오류·가중치·선택·다중검정·코딩 민감도를 점검했습니다. 미공개 저자 정의를 확보하거나 FI의 임상적 타당성을 외부 자료로 검증한 것은 아닙니다. 원 논문과 정확히 같은 Model2·spline·그림의 수치 재현은 완료 표시하지 않습니다.
'''

MARK='<!-- NHANES-EXECUTION-20260928-v1 -->'
audit=[]
note_dir=WORK/'4주차/염증과 노쇠 - 분석 길잡이'
note_names={x.name.split(' ')[0]:x.stem for x in note_dir.glob('*.md')}
for slug,body in blocks.items():
    source=WORK/'frailty-learning/source'/f'{slug}.md'
    notes=list((WORK/'4주차/염증과 노쇠 - 분석 길잡이').glob(slug+' *.md'))
    if not source.exists() or len(notes)!=1:raise RuntimeError(f'Existing note missing or ambiguous: {slug}')
    for file in [source,notes[0]]:
        file_body=body
        if file==notes[0]:
            file_body=re.sub(r'\[\[([0-9]{2}-[a-z-]+)\]\]',lambda m:'[['+note_names[m[1]]+'|'+m[1]+']]',body)
        payload=('\n\n'+MARK+'\n\n'+file_body.strip()+'\n').encode('utf-8')
        old=file.read_bytes()
        if MARK.encode() in old:raise RuntimeError(f'Refuse duplicate append: {file}')
        before=hashlib.sha256(old).hexdigest()
        with file.open('ab') as out:out.write(payload)
        after=file.read_bytes()
        assert after[:len(old)]==old and after[len(old):]==payload
        audit.append(dict(path=str(file.relative_to(WORK)),original_bytes=len(old),
            before_sha256=before,after_sha256=hashlib.sha256(after).hexdigest(),
            added_bytes=len(payload),original_prefix_preserved=True))
write(RUN/'D01-documents/append_audit.json',dict(block_id=MARK,files=audit,html_changed=False))
event('DOCUMENTS_APPENDED','D01','Reviewed results appended to 11 existing source and 11 matching Obsidian notes; original bytes preserved',audit='runs/D01-documents/append_audit.json')
print(f'Appended {len(blocks)} blocks to {len(audit)} existing files. HTML unchanged.')
