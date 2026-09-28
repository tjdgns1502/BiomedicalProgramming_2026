"""Publish accepted continuation at the existing learning stages; no new report/HTML."""
from pathlib import Path
import csv,json,shutil,hashlib,re
r=Path(__file__).resolve().parents[1];w=r.parent
p=json.loads((r/'memory/project.json').read_text(encoding='utf-8'));run=r/'runs'/p['run_id'];notes=w/p['learning_root'];src=r/'tasks/V3-I01/rev-1/work';q=r/'tasks/V3-Q01/rev-1/work'
review=json.loads((q/'result_review.json').read_text(encoding='utf-8'))
assert review.get('verdict',review.get('decision')) in ['accept','accept_with_limits']
def rows(name):
 with (src/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def fmt(x):
 try:return f'{float(x):.3g}'
 except:return str(x)
def tb(headers,rr):return '| '+' | '.join(headers)+' |\n|'+'|'.join(['---']*len(headers))+'|\n'+'\n'.join('| '+' | '.join(map(str,z))+' |' for z in rr)
def orcell(row):return fmt(row['OR'])+' ('+fmt(row['low'])+'–'+fmt(row['high'])+')'
dest=notes/'assets'/p['run_id'];dest.mkdir(parents=True,exist_ok=True);manifest=[]
for file in src.iterdir():
 if file.is_file() and file.suffix.lower() in ['.csv','.png','.r','.json','.log','.txt'] and file.name not in ['derived_analysis_inputs.csv']:
  shutil.copy2(file,dest/file.name);manifest.append({'source':file.relative_to(w).as_posix(),'asset':(dest/file.name).relative_to(notes).as_posix(),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
for name in ['result_review.json','expected_pfqqa.json','plan_review_v3.json','table_test_addition_review.json']:
 if (q/name).exists():shutil.copy2(q/name,dest/name)
def link(name,title):return f'[{title}](assets/{p["run_id"]}/{name})'
flow=rows('flow_counts.csv');counts={z['stage']:z['n'] for z in flow};cont=rows('continuous_models.csv');quart=rows('quartile_models.csv');trends=rows('trend_models.csv');spl=rows('spline_tests.csv');inter=rows('interactions.csv');endpoints=rows('endpoint_audit.csv')
def model(label):return [z for z in cont if z['model']==label]
matched=tb(['지표','Model1 같은 사람 OR (CI)','Model2 같은 사람 OR (CI)','Model2 2배 증가 OR'],[[a['marker'],orcell(a),orcell(b),fmt(b['OR_doubling'])] for a,b in zip(model('M1_matched'),model('M2'))])
flowtable=tb(['단계','인원'],[[k,counts[k]] for k in counts])
qtable=tb(['지표','Model2 Q4/Q1 OR (점별 CI)','원 p','12대비 Holm p'],[[z['marker'],orcell(z),fmt(z['p']),fmt(z.get('p_holm',''))] for z in quart if z['model']=='M2' and z['contrast']=='Q4/Q1'])
trendtable=tb(['지표','중앙값 점수 추세 원 p','4지표 Holm p'],[[z['marker'],fmt(z['p']),fmt(z.get('p_holm',''))] for z in trends if z['model']=='M2'])
spltable=tb(['분석','지표','비선형 원 p','4지표 Holm p'],[[z['model'],z['marker'],fmt(z['p']),fmt(z.get('p_holm',''))] for z in spl])
inttable=tb(['지표','집단 특성','상호작용 원 p','24검정 Holm p'],[[z['marker'],z['moderator'],fmt(z['p']),fmt(z.get('p_holm',''))] for z in inter])
suptable=tb(['지표','Model2 OR','추가 16변수 보정 OR'],[[a['marker'],orcell(a),orcell(b)] for a,b in zip(model('M2_supp_matched'),model('M2_plus16'))])
diettable=tb(['지표','같은 사람·가중치: day1 OR','같은 사람·가중치: 2일 평균 OR'],[[a['marker'],orcell(a),orcell(b)] for a,b in zip(model('Diet_day1_matched'),model('Diet_mean2_matched'))])
ept=tb(['FI 후보','인원','FI=0','FI=1','고유 점수 수'],[[z['candidate'],z['n'],z['zeros'],z['ones'],z['distinct']] for z in endpoints])
texts={
'01':f'**같은 사람을 따라가는 흐름을 유지하면서 분석 범위를 마저 구현했습니다.** 이전 operational36 완비 후보와 이번 설문 분기 확인 후보를 구별합니다. 새 FI 후보가 계산되는 사람은 {counts["route36"]}명이고, 혈액지표·설계·Model1 조건을 만족한 기준 집단은 {counts["reference"]}명입니다. 이 집단에서 요약표와 지표군을 만든 뒤, 추가 공변량을 요구하는 Model2 집단을 따로 정의했습니다. 한 사람의 FI·혈구 값은 집단 모형의 입력이며 개인에게 연구 OR를 붙이지 않습니다.',
'02':'혈구 지표의 수식을 바꾼 것이 아닙니다. 이번 변화의 출발점은 결과변수 FI를 만들 때의 설문 분기와 대상자 선정입니다. 네 지표는 동일 혈구 성분을 공유하므로 네 개의 독립된 생물학적 증거로 세지 않습니다. 기존 수식 검증·상관 분석은 그 정의 범위에서 재사용합니다.',
'03':f'**발견한 문제:** 50–59세의 일부는 건강상 활동 제한이 없다는 선별 응답 때문에 세부 기능 문항을 질문받지 않았습니다. 공식 PFQ의 정확한 분기 조건과 원 항목의 시스템 결측을 확인한 경우에만 9개 기능 항목의 결핍값을 0으로 재구성했습니다. 답변 거부·모름·활동하지 않음 코드는 채우지 않았습니다.\n\n독립 계산에서 4,992명·44,928개 항목이 재구성됐고, FI 완비 인원은 9,814명에서 13,289명으로 늘었습니다. 이전 완비 대상자의 FI는 동일했습니다. 이 규칙을 저자의 실제 코드라고 확인한 것은 아닙니다.\n\n{ept}\n\n**Beta regression 질문:** FI=0이 실제로 있으므로 표준 beta regression을 전체 자료에 그대로 적합할 수 없습니다. 0을 임의로 밀어 넣거나 삭제하지 않았습니다. 기존 fractional logit은 경계값을 포함한 평균 FI라는 별도 질문의 구현으로 유지합니다. FI30은 관측항목 최소30개의 별도 분모 민감도이며 저자 FI가 아닙니다. '+link('endpoint_audit.csv','경계값 점검')+' · '+link('expected_pfqqa.json','독립 PFQ 재구성 검증'),
'04':f'**표본 선정의 후속 구현**\n\n{flowtable}\n\n`reference`는 새 FI 후보와 네 양수 지표·Model1 정보를 갖춘 집단, `model2`는 추가 공변량 완전사례, `supplement`는 16개 추가 질환·검사 변수까지 갖춘 집단, `diet`는 2일 식이 조건을 갖춘 별도 하위집단입니다. 인원 차이를 맞추려고 규칙을 조정하지 않았습니다.\n\n공식 설문 분기를 반영해도 원문 13,507명과 동일한 분석집단이라고 확인되지 않습니다. 결과가 가까워졌다는 사실은 저자의 숨은 설정을 찾아냈다는 증거가 아닙니다. 초기 실행에서 1999년 식이 상태 변수명 DRDDRSTS를 놓친 오류를 발견해 수정했고, 그 결과를 자료 부족으로 오인한 중간 출력은 폐기 이력으로 보존했습니다. '+link('flow_counts.csv','표본 흐름')+' · '+link('covariate_availability_dictionary.csv','주기별 변수 가용성'),
'05':'**Table1과 S2–S5의 후보 계산을 추가했습니다.** 각 변수의 결측·유효 분모, 단순 빈도·비율·중앙값·IQR과 조사 가중 요약을 구별합니다. Table1은 노쇠 여부 두 군, 보충표는 각 염증지표의 네 군입니다. 연속형은 설계 기반 순위 검정, 범주형은 Rao–Scott F 검정으로 비교하고 표별 검정 가족의 Holm 보정을 함께 남깁니다. 이는 저자가 보고한 모든 검정의 선택·가중 규칙을 확인한 재현은 아닙니다.\n\nFI와 FI로 만든 노쇠군, 지표와 그 지표의 사분위군처럼 정의상 연결된 비교는 독립적 과학적 발견으로 읽지 않습니다. 수치가 다른 이유를 살필 때는 분모·결측·가중·군의 정의부터 확인합니다. '+link('table1_descriptions.csv','Table1 후보 요약')+' · '+link('S2_S5_descriptions.csv','S2–S5 후보 요약'),
'06':'이번 OR의 연속형 단위는 **자연로그 1 증가, 즉 지표 e배 증가**로 고정했습니다. 이해를 돕기 위해 지표 2배 증가의 OR도 별도로 계산했습니다. 저자 로그 밑이 미보고인 상태에서 발표 OR와 이 숫자의 근접 정도로 재현 통과를 판정하지 않습니다. '+link('continuous_models.csv','모든 연속 지표 모형과 단위'),
'07':f'**이번에는 추가 보정 후 함수 형태도 검사했습니다.** 고정 df3 자연스플라인의 추가 비선형 2항을 설계 Wald 검정으로 확인했습니다.\n\n{spltable}\n\nM2는 주 분석, M2_plus16은 16개 질환·검사 추가 보정입니다. 각각 네 지표의 검정 가족을 별도로 보정했습니다. 원문 knot를 알아낸 것이 아니라 명시한 후보의 진단입니다. 없는 조사 주기 범주가 행렬에 남아 생긴 초기 rank 실패는 사용하지 않는 범주 수준을 정리해 해결했습니다. 실제 관측 공변량을 유의성에 따라 제거한 것은 아닙니다.',
'08':f'**Model2까지 구현한 결과** — 두 모형을 동일한 {counts["model2"]}명에 적합해 대상자 변화와 보정 추가를 구별했습니다.\n\n{matched}\n\n위 OR 구간은 자연로그 1 증가에 대한 점별 구간입니다. 큰 Model1 집단의 결과도 CSV에 따로 남겼습니다. 교육·PIR·BMI·흡연·음주·여가활동·열량·당뇨·고혈압을 추가했습니다. 음주는 “어느 한 해 12잔 이상”, 활동은 여가 강도, 열량은 신뢰할 수 있는 day1이라는 공개 문항 기반 후보입니다. 이를 저자의 과거1년 음주·정확한 활동량·전 기간 2일 식이 정의와 같다고 부르지 않습니다.\n\n**식이 민감도:** 2003–2016년의 양수 WTDR2D/7 전체 연령 설계에서 두 날 모두 신뢰 가능한 성인 하위집단을 사용했습니다. 동일한 사람과 가중치에서 열량 변수만 바꿨습니다.\n\n{diettable}\n\n검진 가중치의 전체 기간 분석과 식이 가중치의 2일 응답자 분석은 적용 집단이 다릅니다. day1과 mean2의 위 비교 자체는 같은 식이 하위집단의 비교입니다. '+link('continuous_models.csv','같은 표본 비교 전체 결과'),
'09':f'**Table3의 Model2와 추세 검정도 실행했습니다.** 사분위 경계는 Model2 결측 제외 전에 기준 집단에서 한 번 정하고, 모형마다 다시 나누지 않았습니다.\n\n{qtable}\n\n{trendtable}\n\n추세는 각 군의 기준집단 원척도 중앙값을 점수로 사용한 선형 항입니다. 모든 인접 군이 단조 증가한다는 검정은 아닙니다. 12개 대비·4개 추세·4개 전체 군 검정은 서로 다른 사전 지정 가족입니다. 논문 방향은 염증지표군→노쇠 여부이고, 기존 과제의 FI군→지표 평균은 별도 분석으로 유지합니다. '+link('quartile_models.csv','모든 군 대비')+' · '+link('trend_models.csv','추세')+' · '+link('frozen_quartiles.csv','고정 경계와 점수'),
'10':f'**Figure3의 하위집단 분석과 보충자료 분석을 마저 실행했습니다.** 연령·성별·BMI·활동·흡연·음주 6개 특성 × 지표4개의 상호작용을 각각 하나의 모형에서 검정했습니다.\n\n{inttable}\n\n집단별로 한쪽만 유의하다는 비교가 아니라 집단 간 기울기 차이를 직접 검정한 결과입니다. 위 Holm은 24개 검정에 대한 보정입니다. 원문과 같은 연령·활동·음주 코딩이라고 확인된 것은 아닙니다.\n\n**보충 S6·S7·FigureS1:** 동일한 사람에서 Model2와 질환·검사 16변수 추가 보정 모형을 비교하고, 연속 지표·사분위·추세·곡선을 계산했습니다.\n\n{suptable}\n\n추가 변수 중 일부가 FI 항목과 겹칩니다. 계수가 줄거나 커진 것을 더 올바른 인과효과로 단정하지 않습니다. 아래 곡선·숲그림은 후보 정의의 점별 95% 구간이며 저자 그래프의 동일 복제가 아닙니다. '+link('subgroup_slopes.csv','하위집단 기울기와 인원')+' · '+link('interactions.csv','상호작용 전체')}
for png in sorted(dest.glob('*.png')):
 if any(k in png.stem.lower() for k in ['curve','forest','subgroup']):
  texts['10']+=f'\n\n![{png.stem}](assets/{p["run_id"]}/{png.name})'
  if 'forest' in png.stem.lower():texts['10']+='\n\n그림 읽기: sex 1=남성, 2=여성; LT65=50–64세, GE65=65세 이상; BMI LT25=<25, 25_LT30=25 이상30 미만, GE30=30 이상입니다. Low/Moderate/Vigorous는 정의한 여가활동 강도, smoking은 평생100개비 경험, alcohol은 어느 한 해12잔 이상 여부입니다. 같은 10,874명 모형에서 얻은 집단별 지표 e배 증가 OR와 점별95% CI이며, 집단 차이 검정은 별도 상호작용 표를 봅니다.'
  else:texts['10']+='\n\n곡선 읽기: 대상은 동일 후보 10,874명이며, 가로축은 원척도 지표를 로그 간격으로 표시합니다. 기준은 각 지표의 표본 중앙값, 표시 범위는5–95백분위, 세로축은 기준 대비 조건부 OR입니다. 띠는 설계 자유도138의 t 임계값을 사용한 점별95% CI입니다. 인과적 위험 변화나 개인 예측확률이 아닙니다.'
 if 'flow' in png.stem.lower():texts['04']+=f'\n\n![후보 표본 흐름](assets/{p["run_id"]}/{png.name})'
texts['04']+='\n\n도표의 92,062명은 전체 조사 원자료 인원입니다. 실제 검진 설계는 양수 검진 가중치 88,062명으로 만들고 하위집단을 지정했습니다. 별도 2일 식이 설계의 양수 가중치 부모 집단은 55,233명이며 이 중 조건을 만족한 성인 후보를 분석했습니다.'
texts['05']+='\n\n'+link('table1_tests.csv','Table1 군 비교 검정')+' · '+link('S2_S5_tests.csv','S2–S5 군 비교 검정')+' · '+link('descriptive_test_row_manifest.csv','실행 전에 고정한 비교 목록')
desc=rows('table1_descriptions.csv')
age=[z for z in desc if z['variable']=='age']
texts['05']+='\n\n**한 줄 읽기 예 — 나이:**\n\n'+tb(['군 (0=비노쇠,1=노쇠)','인원','단순 중앙값 [Q1,Q3]','가중 중앙값 [Q1,Q3]'],[[z['group'],z['observed'],f'{fmt(z["median"])} [{fmt(z["q25"])},{fmt(z["q75"])}]',f'{fmt(z["weighted_median"])} [{fmt(z["weighted_q25"])},{fmt(z["weighted_q75"])}]'] for z in age])+'\n\n단순 요약은 이 분석 파일의 참여자 분포이고 가중 요약은 주어진 설계 가중치를 적용한 분포입니다. 완전사례 선정 편향까지 자동 교정된다는 뜻은 아닙니다.'
texts['07']+='\n\n이번 후보에서 네 지표 모두 Model2 비선형 검정의 Holm p<0.05였습니다. 특히 선형 SII 항의 p가 0.05보다 크다는 사실을 “SII와 노쇠는 아무 관계가 없다”로 해석하면 안 됩니다. 선형 기울기 검정과 곡선 전체·비선형 부분 검정은 서로 다른 질문입니다.'
texts['10']+='\n\n**상호작용 결과의 의미:** 24개 중 원 p<0.05인 비교가 있어도 Holm 보정 후 0.05 미만인 비교는 없었습니다. 특정 집단의 효과가 없다고 입증한 것이 아니라, 이번 후보 정의와 검정 가족에서는 집단 차이를 뒷받침할 보정 후 근거가 충분하지 않았다는 뜻입니다.'
stages=json.loads((r/'memory/stage_registry.json').read_text(encoding='utf-8'));updates=[]
for s in stages:
 path=w/s['paper_path'];text=path.read_text(encoding='utf-8');sid=s['stage_id'];marker=f'<!-- V3-STAGE-{sid} -->'
 assert marker not in text,'Refuse duplicate integration; restore from this run original-notes or implement explicit update'
 insertion='\n\n'+marker+'\n\n### 후속 실행: 남은 논문 분석까지 구현\n\n'+texts[sid]+'\n\n> 아래의 기존 V2 실행 내용은 당시 완비 후보의 기록입니다. 이번 후보와 표본·정의가 같다고 섞어 읽지 않습니다.\n\n'
 text=text.replace('## 3. 어떻게 구현했고 무엇을 얻었나\n','## 3. 어떻게 구현했고 무엇을 얻었나\n'+insertion,1)
 text=text.replace('## 6. 갱신된 해석과 남은 한계\n','## 6. 갱신된 해석과 남은 한계\n\n**후속 실행 상태:** 공개자료로 정의한 해당 후보 분석과 독립 검토를 완료했습니다. 저자 설정 확인·정확 재현 여부와 후보 구현 완료는 별도 판정입니다. 이전 판정은 아래에 이력으로 보존합니다.\n',1)
 path.write_text(text,encoding='utf-8');updates.append({'path':s['paper_path'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
start=next(notes.glob('00-start*.md'));text=start.read_text(encoding='utf-8');notice=f'''## 후속 실행에서 달라진 점

논문 분석을 네 가지 진단에서 멈췄던 범위 설정을 바로잡고, 남아 있던 Model2·표 비교·추세·하위집단·보충 분석을 실행했습니다. 각 paper 문서의 **3구역 첫 부분**이 이번 결과입니다.

- 공식 설문 분기 확인으로 FI 완비 후보가 9,814명에서 {counts['route36']}명으로 늘었습니다. 이전 완비 대상자의 점수는 동일했습니다.
- 주 분석 기준 집단 {counts['reference']}명, 추가 보정 Model2 {counts['model2']}명입니다. 같은 사람에서 Model1/2를 비교했습니다.
- Table1·Table2·Table3, S2–S7, 비선형 곡선, 24개 상호작용, 2일 식이 가중 민감도를 계산하고 독립 검토했습니다.
- 저자의 정확한 FI 코딩·활동량·음주·로그 밑·스플라인 설정은 여전히 일부 미확인입니다. **후보 구현을 완료했다는 것과 원 논문을 동일하게 재현했다는 것은 다릅니다.**

'''
text=text.replace('## 읽는 방법',notice+'## 읽는 방법',1);start.write_text(text,encoding='utf-8')
(run/'document_integration.json').write_text(json.dumps({'notes':updates,'assets':manifest,'review':str(q/'result_review.json'),'new_HTML':False,'separate_final_report':False},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Integrated accepted continuation into existing 00 and 01-10 notes')
