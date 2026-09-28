"""Integrate reviewed v2 work in the existing stage notes, preserving initial explanation in backups."""
from pathlib import Path
import json,csv,re,shutil,hashlib
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT.parent
project=json.loads((ROOT/'memory/project.json').read_text(encoding='utf-8'))
run=ROOT/'runs'/project['run_id'];notes=WORK/project['learning_root'];backup=run/'original-notes'
stage_registry=json.loads((ROOT/'memory/stage_registry.json').read_text(encoding='utf-8'))
issues=json.loads((ROOT/'memory/issues.json').read_text(encoding='utf-8'))
impl=ROOT/'tasks/V2-I01/rev-1/work'
review_path=ROOT/'tasks/V2-Q01/rev-1/work/result_review.json'
if not review_path.exists():raise RuntimeError('Independent result review is required before publication')
review=json.loads(review_path.read_text(encoding='utf-8'))
if review.get('decision') not in ['accept','accept_with_limits']:raise RuntimeError('Result review not accepted')
def readcsv(name):
 p=next(impl.rglob(name))
 with p.open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def fmt(x,d=3):return f'{float(x):.{d}f}'
def pval(x):return f'{float(x):.3g}'
def table(headers,data):return '| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(map(str,r))+' |' for r in data)
logrows=readcsv('log_base_checks.csv');qrows=readcsv('quartile_model1.csv');nonlin=readcsv('nonlinearity_tests.csv');ages=readcsv('age_boundary_counts.csv')
dest=notes/'assets'/project['run_id'];dest.mkdir(parents=True,exist_ok=True)
manifest=[]
for path in impl.rglob('*'):
 if path.is_file() and path.suffix in ['.csv','.png','.json','.R','.txt','.log']:
  target=dest/path.relative_to(impl);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
  manifest.append({'source':path.relative_to(WORK).as_posix(),'copy':target.relative_to(notes).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
def asset(name):return next(p for p in dest.rglob(name)).relative_to(notes).as_posix()
for name in ['result_review.json','result_numeric_checks.json','marker_assertion_reconciliation.json']:
 path=review_path.parent/name
 if path.exists():
  target=dest/'review'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
  manifest.append({'source':path.relative_to(WORK).as_posix(),'copy':target.relative_to(notes).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
def mdlink(name,label):return f'[{label}]({asset(name)})'
def field(row,*keys):
 for k in keys:
  if k in row:return row[k]
 raise KeyError((keys,list(row)))
logtable=table(['지표','ln 1단위 OR','log10 1단위 OR'],[[r['marker'],fmt(field(r,'OR_ln','or_ln')),fmt(field(r,'OR_log10','or_log10'))] for r in logrows])
nlttable=table(['지표','비선형 원 p','4개 Bonferroni p','분자/분모 자유도'],[[r['marker'],pval(r['p']),pval(r['p_bonferroni']),r['df_num']+'/'+r['df_den']] for r in nonlin])
age_table=table(['자료 범위','조사주기','50세 이상','50세 초과','정확히50세'],[[r['scope'],r['cycle'],r['n_ge50'],r['n_gt50'],r['n_eq50']] for r in ages if r['cycle'].lower() in ['all','total','pooled','all_cycles']])
published={'NLR':('2.06','1.75–2.43'),'MLR':('1.55','1.32–1.82'),'SIRI':('2.29','1.94–2.71'),'SII':('1.55','1.31–1.82')}
qt=table(['지표','원문 Model1 Q4/Q1 OR (CI)','후보 Q4/Q1 OR (CI)','판정'],[[r['marker'],published[r['marker']][0]+' ('+published[r['marker']][1]+')',fmt(field(r,'OR','or'))+' ('+fmt(r['ci_low'])+'–'+fmt(r['ci_high'])+')','집단·FI·분위수 정의가 달라 직접 일치 판정 불가'] for r in qrows if r['contrast'] in ['Q4-Q1','Q4/Q1','Q4']])
stats={
'04':f'**새 구현:** 같은 자료에서 연령 조건만 바꿔 인원을 셌습니다.\n\n{age_table}\n\n각 범위에서 `50세 이상−50세 초과=정확히50세`를 확인했습니다. 원문의 연령 제외 후 인원은 21,670명입니다. 어느 조건이 발표 N에 더 가깝다는 이유로 기준을 바꾸지 않았습니다. 전체 주기별 기록: '+mdlink('age_boundary_counts.csv','연령 경계 감사표'),
'06':f'**새 구현:** 같은 사람·반응·공변량·설계에서 로그의 밑만 바꿨습니다.\n\n{logtable}\n\n`β_log10 = ln(10) × β_ln`입니다. 비교 단위가 e배에서 10배로 달라져 OR 수치가 바뀌지만 적합 확률과 같은 배수 증가에 대한 OR는 같습니다. 계수·SE·공분산·적합값의 변환을 검사했습니다. 이 검사는 저자가 어느 밑을 썼는지 밝혀낸 결과가 아닙니다. '+mdlink('log_base_checks.csv','수학적 동등성 검사'),
'07':f'**새 구현:** 같은 후보 표본에서 `logit(p)=선형 로그 지표+공변량`과 추가 비선형 2항이 있는 모형을 비교했습니다.\n\n{nlttable}\n\n자연로그 지표의 고정 1/3·2/3 분위수 knot와 df3 자연스플라인을 사용하고, 선형 부분 밖의 두 항을 설계 기반 Wald F로 검정했습니다. Bonferroni의 검정 가족은 사전에 정한 네 지표입니다. 유의하지 않다고 선형성이 증명되는 것은 아닙니다. '+mdlink('nonlinearity_tests.csv','진단 전체 수치'),
'08':f'**새 구현:** Model1의 보정 구조는 연령·성별·인종·조사주기입니다. 후보 FI의 정의와 분석집단 차이를 유지한 채 로그 단위를 명시했습니다.\n\n{logtable}\n\n이전 자연로그 OR와 원문 OR를 같은 숫자 단위라고 가정해 차이를 해석해서는 안 됩니다. 원문은 밑을 명시하지 않았고 Table1은 원척도 값이므로 이 비교로 저자의 밑을 결정할 수 없습니다. Model2는 미확인 공변량 정의를 채운 척하지 않고 미해결로 둡니다.',
'09':f'**이번에 추가한 논문 방향의 구현:** 각 염증지표를 원척도 type7 사분위로 나눠 Q1을 기준으로 `노쇠 여부 ~ 지표군 + 연령 + 성별 + 인종 + 주기`를 설계 보정 로지스틱으로 적합했습니다.\n\n{qt}\n\n이는 Table3의 **Model1 구조 후보**입니다. 위 원문 설명에 있는 Model2와 섞지 않습니다. Q2·Q3 대비도 모두 계산했으며, 분할점 추정의 불확실성까지 포함한 구간은 아닙니다. '+mdlink('quartile_model1.csv','12개 대비와 점별 신뢰구간'),
'10':f'**새 진단 그림:** 아래는 원문 Figure2의 복제가 아니라, 이번에 고정한 자연스플라인의 조건부 OR 곡선입니다.\n\n![후보 표본의 고정 자연스플라인 진단]({asset("diagnostic_curves.png")})\n\n기준은 같은 표본에서 각 지표의 중앙값, 표시 범위는 5–95백분위입니다. 구간은 점별 95% CI이며 기준점과의 공분산을 반영했습니다. 다른 보정변수는 상호작용 없는 모형에서 대비할 때 상쇄됩니다.\n\n{nlttable}\n\n원문의 knot·기준점·FI 코딩을 모르므로 곡선의 모양이 비슷하거나 다르다는 이유로 원문을 재현했거나 반박했다고 판정하지 않습니다.'}
comparison={
'01':'원문은 참여자 단위 자료를 사용합니다. 기존 실제 추적 예시의 SEQN 13은 한 행의 변환을 보여 주며 연구의 OR를 혼자 결정하지 않습니다. 관측 단위 수준은 연결됐지만 저자 분석 파일의 열 구성까지 동일하다는 뜻은 아닙니다.',
'02':'원문 식 N/L, M/L, N×M/L, P×N/L과 구현 식은 같습니다. 기존 원자료 검증에서 부동소수점 수준의 수식 일치를 확인했습니다. 지표를 염증 전체의 완전한 측정으로 검증한 것은 아닙니다.',
'03':'원문 36항목·FI>0.3은 확인했습니다. 후보의 fair/poor·약5개·방문6회·36완비 규칙은 확인된 저자 규칙이 아니므로 수치 재현의 전제는 미해결입니다. Fried 기준을 FI 대신 적용한 것도 아닙니다.',
'04':'원문: 92,062 → 연령 제외 후21,670 → 최종13,507. 기존 공개자료 후보: 92,062 → 50세 이상24,119 → FI완비9,814 → 혈액지표9,786. 차이를 숨기지 않고 저자 분석집단의 동일 재현은 미완료로 판정합니다.',
'05':'원문 3,729/13,507은 단순 빈도로27.61%인데 보고 비율은24%입니다. 후보 FI완비 자료는1,923/9,814입니다. 모집단·선택·가중 정의가 다르므로 두 유병 비율의 차이를 원문 오류 검정으로 사용하지 않습니다. 음주결측627명과 공변량결측 제외152명의 관계도 미보고입니다.',
'06':'로그 밑 변환의 계산상 동등성은 검증할 수 있습니다. 저자의 실제 변환 밑은 이 계산으로 식별할 수 없습니다. 같은 배수 변화와 다른 로그1단위 변화의 OR를 구별해야 합니다.',
'07':'원문의 로그변환은 확인됐습니다. 여기서 사용한 knot·df·검정 가족은 분석자의 사전 고정 진단입니다. 새 진단을 원문 RCS와 동일하게 구현했다고 표기하지 않습니다.',
'08':'원문 Table2와 후보 Model1은 X·Y의 개념과 일부 보정 구조를 공유하지만, FI·표본·변환 밑·가중 처리의 동등성이 확인되지 않았습니다. 따라서 정확 일치/불일치 검정보다 비교 가능 조건이 미충족이라는 판정이 우선입니다.',
'09':'원문의 지표 사분위 분석과 후보 계산을 위에서 같은 Model1끼리 제시했습니다. 과제의 FI 사분위→지표 평균 검정은 반응변수와 질문이 다르므로 논문 Table3의 재현으로 세지 않습니다.',
'10':'원문 Figure1은 포함 대상, Table1은 분포, Table2–3은 보정 연관, Figure2는 함수 형태, Figure3은 집단별 연관을 설명합니다. 이번 분석은 이 역할을 연결했지만 원문 Figure2·3 수치 전체의 동일 재현은 아닙니다.'}
introduction='''### 이 연구는 왜 시작됐고 무엇을 밝히려 했나?

저자는 이전 연구가 NLR에 집중되어 있고 SIRI와 FI의 관계, 미국 인구에 대한 적용 근거가 부족하다고 설명합니다. 이는 원문 Background의 연구 공백 주장입니다. 이번 작업이 관련 문헌 전체를 새로 체계적으로 검토해 확정한 것은 아닙니다.

그래서 “미국 조사 참여자에서 CBC로 만든 네 지표가 높은 사람은 같은 시점에 FI로 정의한 노쇠 상태일 오즈도 높은가?”를 묻습니다. 연구자는 사람을 염증 노출에 무작위 배정한 것이 아니라 기존 NHANES의 면접·검사 자료를 선택하고 연결했습니다. 따라서 여기서 설계란 대상자·변수·결측·보정·모형을 정하는 관찰연구의 분석 설계입니다.

혈구 수를 X로, 여러 결핍을 합친 FI와 그 이진값을 Y로 정의한 뒤 사람들을 함께 분석합니다. 한 사람의 측정값은 집단 추정의 재료이며, 최종 결론의 범위는 같은 시점의 연관성입니다. 근거: [원문 Background와 설계](assets/paper.pdf#page=2).

'''
audits=[]
for stage in stage_registry:
 sid=stage['stage_id'];path=WORK/stage['paper_path'];old=(backup/path.name).read_text(encoding='utf-8')
 initial,_,previous=old.partition('<!-- NHANES-EXECUTION-20260928-v1 -->')
 previous=re.sub(r'\n> Obsidian의 그림.*','',previous,flags=re.S)
 # Preserve the initial explanation, move duplicated navigation to the final end.
 initial=re.sub(r'\n---\s*\n\[\[.*이전:.*', '',initial,flags=re.S)
 match=re.search(r'^# .*$',initial,flags=re.M)
 head=initial[:match.end()] if match else '# '+stage['label']
 body=initial[match.end():] if match else initial
 body=re.sub(r'^## ', '### ',body,flags=re.M).strip()
 previous=re.sub(r'^## ', '### ',previous.strip(),flags=re.M)
 issue=next(x for x in issues if x['stage_id']==sid)
 if sid=='01':body=introduction+body
 current=stats.get(sid,previous)
 if sid=='07':current+='\n\n**결과를 읽으면:** 네 지표 모두 Bonferroni 보정 후에도 p<0.05였습니다. 이 후보 자료와 고정한 모형에서는 로그 지표와 로그오즈의 관계를 직선 하나로만 표현하기 부족하다는 근거입니다. 스플라인이 다른 집단에서도 더 잘 예측하거나 생물학적으로 참이라는 결론은 아닙니다.'
 if sid=='04':current+='\n\n50세를 제외해도 23,313명으로 원문의 21,670명과 1,643명 차이가 남습니다. 따라서 이번 자료에서는 정확히 50세인 사람의 포함 여부만으로 표본수 차이를 설명할 수 없습니다.'
 if sid=='04':current+=' 이번 건수는 전체 조사설계 파생파일에 기록된 연령을 센 것이며 원 DEMO 파일을 새로 읽은 결과는 아닙니다. 후보 파일은 이미 50세 이상으로 제한되어 있습니다.'
 if sid=='10':current+='\n\n새 곡선의 보정은 Model1(연령·성별·인종·조사주기)이며, 점별 구간은 설계 자유도 138의 t 임계값을 사용했습니다.'
 if sid=='02':current+='\n\n**구현 중 실패와 해결:** 새 구현자는 기존 네 지표 열을 고정 입력으로 사용했습니다. 추가 수식 검사 한 번은 결측을 처리하지 않은 비교 함수 때문에 멈췄습니다. 독립 검토자가 결측을 구별해 다시 확인하니 공통 9,786명에서 네 수식 모두 허용 오차 안에서 일치했습니다. 28명의 결측이 있는 전체 자료에서 비교 함수가 NA를 반환한 것이므로, 지표 값이 틀렸다는 증거는 아니었습니다. 실패 로그를 보존했습니다. 이 검사는 파생자료 안의 산술 검증이며 원 XPT·단위·병합 전체를 새로 인증한 것은 아닙니다.'
 if sid=='02':current+=' '+mdlink('marker_assertion_reconciliation.json','결측 처리와 수식의 독립 점검 기록')
 extra=previous if sid in stats else '이 단계의 기존 검사와 결과는 위 구현에 포함되어 있습니다. 근거의 범위는 아래 판정과 구분해 읽습니다.'
 if sid=='09':extra='**과제 확장 — 논문과 다른 질문:** 아래는 FI군별 염증지표 평균의 비교입니다.\n\n'+extra
 if sid=='10':extra='**이미 수행한 민감도·모의실험을 재사용한 부분:** 다음 결과는 입력·코드 감사 후 유지했습니다. 동일 계산을 다시 실행한 결과로 표기하지 않습니다.\n\n'+extra
 status=issue['status']
 if status in ['분석 후 갱신','검토 후 갱신']:status='부분 해결 — 계산·진단은 수행했으나 저자 미공개 정의는 남음'
 issue['status']=status
 text=head+'\n\n<!-- V2-LEARNING-STAGE-'+sid+' -->\n\n'
 text+='> 읽는 순서: **논문 설명 → 남긴 의문 → 구현 → 재현 비교 → 추가 검토 → 갱신된 해석**. 개념이 막히면 위 통계 개념 노트로 돌아가세요.\n\n'
 text+='## 1. 처음의 논문 설명과 데이터 흐름\n\n> 아래는 구현 전에 작성한 원문 해설입니다. 당시의 미실행 설명은 이 구역의 작성 시점을 뜻하며, 이후 실제 실행 상태는 3–6구역에서 확인합니다.\n\n'+body+'\n\n'
 text+='## 2. 이 단계에서 남겨 둔 의문\n\n**'+issue['question']+'**\n\n'+issue['source_summary']+'\n\n'
 text+=f'> 문제 `{issue["issue_id"]}` · 종류: {issue["kind"]} · 연결 작업: `{issue["task_id"]}`. 기록 ID를 몰라도 아래 설명을 읽을 수 있습니다.\n\n'
 text+='## 3. 어떻게 구현했고 무엇을 얻었나\n\n'+current+'\n\n'
 text+='## 4. 논문과 비교하면 어디까지 일치하는가\n\n'+comparison[sid]+'\n\n'
 text+='## 5. 의문을 검토한 과정과 추가 분석\n\n'+extra+'\n\n'
 text+='## 6. 갱신된 해석과 남은 한계\n\n**현재 판정: '+status+'**\n\n'+issue['interpretation_limit']+'\n\n'
 text+='새 계산은 독립 계획 검토 후 실행하고 별도 결과 검토를 거쳤습니다. 과거 자료·모형의 재사용 감사는 입력과 코드의 일관성을 확인한 것이며, 저자 FI 정의나 인과적 해석의 인증이 아닙니다.\n\n'
 nextid=stage['learning_next'];nxt=next((s for s in stage_registry if s['stage_id']==nextid),None)
 if nxt:text+='다음: [['+Path(nxt['concept_path']).stem+'|'+nxt['label']+'의 개념]] → [['+Path(nxt['paper_path']).stem+'|논문 적용]].\n'
 path.write_text(text,encoding='utf-8');audits.append({'path':stage['paper_path'],'backup':(backup/path.name).relative_to(WORK).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
start=next(notes.glob('00-start *.md'))
start_text='''---
tags: [염증과노쇠, 학습안내]
순서: 1
---

# 한 사람의 측정값에서 논문의 결론까지

이 문서는 **논문을 이해하면서 구현과 검토 결과를 같은 순서로 읽는 시작점**입니다. 코드나 로그를 먼저 읽을 필요는 없습니다.

저자는 염증과 노쇠에 관한 선행연구에서 출발해, 미국 NHANES 자료에서 네 혈구 유래 지표와 FI 노쇠 여부의 연관성을 묻습니다. 새 실험으로 사람을 배정한 연구가 아니라 기존 관찰자료를 선택·코딩·분석한 연구입니다. 같은 사람의 혈구 수와 설문·검진 값이 각각 설명변수와 결과변수로 바뀌고, 여러 사람의 자료를 모아 효과와 불확실성을 추정합니다.

```mermaid
flowchart TD
 A["기존 연구와 남은 질문"] --> B["관찰연구 설계: 누구의 무엇을 측정했나"]
 B --> C["같은 사람의 혈구 수 → 네 염증지표 X"]
 B --> D["설문·검진의 결핍 → FI → 노쇠 여부 Y"]
 C --> E["포함·결측·조사설계가 정한 분석집단"]
 D --> E
 E --> F["Table1: 분포와 사람들의 특성"]
 E --> G["Table2: 연속 로그 X와 Y의 보정 연관"]
 E --> H["Table3: X 사분위와 Y의 보정 연관"]
 G --> I["곡선·집단차·민감도 → 결론의 범위"]
 H --> I
 E --> J["과제 확장: FI군별 염증지표 평균"]
```

화살표는 설명을 위한 데이터·질문의 관계입니다. Table1의 요약값을 회귀의 원자료로 넣는다는 뜻은 아닙니다. 과제 확장은 논문과 X·Y의 역할이 다릅니다.

## 읽는 방법

각 단계에서 concept를 먼저 읽으면 통계·데이터의 특징을 배우고, paper에서 이 논문이 무엇을 했는지 확인합니다. paper에는 처음 남긴 의문, 실제 구현, 원문과의 비교, 추가 검토와 남은 한계가 같은 순서로 이어집니다.

'''
start_text+=table(['단계','먼저 이해할 개념','논문 설명·구현·검토'],[[s['stage_id']+' '+s['label'],'[['+Path(s['concept_path']).stem+'|개념]]','[['+Path(s['paper_path']).stem+'|논문과 실제 분석]]'] for s in stage_registry])
start_text+='''

## 이번 실행으로 무엇을 더 알게 됐나

- 한 사람의 자료 구조와 연구 질문을 먼저 연결했습니다. 출판 수치·가상 예시·후보 자료 결과를 구별합니다.
- 기존 후보 분석은 코드와 입력이 유지됐는지 감사한 뒤 재사용했습니다. 저자와 동일한 FI라는 뜻은 아닙니다.
- 로그의 밑을 바꾸면 숫자로 표시한 OR는 달라져도 같은 배수 변화와 적합 확률은 같다는 점을 실제 모형으로 검사했습니다.
- 논문 방향인 **염증지표 사분위 → 노쇠 여부** Model1을 추가하고, 과제의 **FI 사분위 → 염증지표 평균**과 구분했습니다.
- 연령 경계와 로그 지표의 함수 형태를 계획에 따라 검사했습니다. 구체적인 결과는04·06·07·09·10단계에서 읽습니다.

## 무엇이 아직 해결되지 않았나

저자의 FI 세부 코딩·결측 허용·로그 밑·일부 Model2 정의·RCS 설정은 모두 확인되지 않았습니다. 현재 분석집단은 명시한 operational36 후보입니다. 따라서 논문 전체를 동일하게 재현했다는 결론은 내리지 않습니다. 모형을 잘 실행했다는 것, 통계적 가정이 적절하다는 것, 노쇠를 타당하게 측정했다는 것, 인과관계를 밝혔다라는 것은 각각 다른 판단입니다.

운영 프롬프트가 필요할 때만 [[12-reusable-prompt 다음 논문에도 사용할 요청 프롬프트|재사용 프롬프트]]를 읽으세요. 실제 코드·자료·로그의 기준은 작업 폴더의 `analysis/`입니다. 이번 내용은 기존 Obsidian 문서에서 갱신했고 HTML은 별도로 만들지 않았습니다.
'''
start.write_text(start_text,encoding='utf-8')
(ROOT/'memory/issues.json').write_text(json.dumps(issues,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(run/'document_integration.json').write_text(json.dumps({'notes':audits,'assets':manifest,'source_mirror_updated':False,'canonical':'Obsidian only','review':review_path.relative_to(WORK).as_posix()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Integrated 10 stage notes and the existing start note; prior versions preserved in run backup.')
