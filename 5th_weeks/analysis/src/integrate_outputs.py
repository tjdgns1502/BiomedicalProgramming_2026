"""Integrate reviewed run evidence into the original paired learning notes."""
from pathlib import Path
import csv,json,sys,re,hashlib,shutil,datetime
root=Path(sys.argv[1]); a=root/'analysis'; notes=root/'치주질환과 고혈압 - 분석 길잡이'
core_id='R2-20261004'; ext_id=sys.argv[2] if len(sys.argv)>2 else 'E2-20261004'; v_id='V1-20261004'
core=a/'runs'/core_id; ext=a/'runs'/ext_id; val=a/'runs'/v_id
def readj(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def rows(p):return list(csv.DictReader(p.open(encoding='utf-8-sig',newline='')))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def num(x):
 try:return float(x)
 except (TypeError,ValueError):return None
def fmt(x,d=3):
 x=num(x);return '—' if x is None else f'{x:.{d}f}'
def link(p,label):return f'[{label}](../{p.relative_to(notes.parent).as_posix().replace(" ","%20")})' if p.is_relative_to(notes.parent) else f'[{label}]({p.as_posix()})'
def table(headers,data):return '| '+' | '.join(headers)+' |\n| '+' | '.join('---' for _ in headers)+' |\n'+''.join('| '+' | '.join(str(c).replace('|','/') for c in row)+' |\n' for row in data)
def writecsv(p,data):
 if not data:return
 with p.open('w',encoding='utf-8-sig',newline='') as f:w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
assert readj(core/'status.json')['status']=='success'
assert readj(ext/'status.json')['status']=='success'
cr=readj(core/'report.json'); er=readj(ext/'report.json')
if '--comparison-only' not in sys.argv:
 for name in ('R2-20261004-q-review.json','R2-data-review.json','E1-20261004-q-review.json','E1-data-review.json',ext_id+'-q-review.json',ext_id+'-data-review.json','V1-20261004-q-review.json'):
  d=readj(a/'reviews'/name);decision=d.get('decision',d.get('status',d.get('verdict')))
  if isinstance(decision,dict):decision=decision.get('value',decision.get('status'))
  assert str(decision).lower().startswith('accept'),(name,decision)
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
comparison=a/'comparisons'/ext_id;comparison.mkdir(parents=True,exist_ok=True)
sources=a/'sources/europepmc'
targets=[]; population_targets=[]; p_targets=[]
def parse_original_model_tsv(file,family):
 exposure='oral_health';subgroup='Overall'
 for line in file.read_text(encoding='utf-8-sig').splitlines():
  cells=line.split('\t');label=re.sub(r'\s+',' ',cells[0]).strip()
  if label=='Oral health':exposure='oral_health';subgroup='Overall';continue
  if label=='Periodontal disease':exposure='periodontal';subgroup='Overall';continue
  if label=='Non-Smoking':subgroup='Non-Smoking';continue
  if label=='Smoking':subgroup='Smoking';continue
  if label.startswith('Age'):subgroup='30-44' if '<' in label else '45+';continue
  if len(cells)<5 or not re.fullmatch(r'[\d,]+/[\d,]+',cells[1].strip()):continue
  cases,n=map(lambda x:int(x.replace(',','')),cells[1].split('/'))
  level='Excellent/Very good' if label.startswith('Excellent/') else label
  population_targets.append(dict(family=family,subgroup=subgroup,exposure=exposure,term=exposure+level,published_level_cases=cases,published_level_n=n))
  for mi,cell in enumerate(cells[2:5],1):
   match=re.search(r'([\d.]+)\s*\(\s*([\d.]+)\s*[-–]\s*([\d.]+)\s*\)',cell)
   if not match:continue
   term=('oral_health'+label) if exposure=='oral_health' else ('periodontal'+label)
   targets.append(dict(family=family,subgroup=subgroup,model='Model'+str(mi),exposure=exposure,term=term,published_OR=float(match[1]),published_low=float(match[2]),published_high=float(match[3]),published_level_cases=cases,published_level_n=n,source=str(file.relative_to(a))))
parse_original_model_tsv(sources/'table_2.tsv','table2')
parse_original_model_tsv(sources/'table_3.tsv','table3')
text=(sources/'12889_2023_16012_MOESM1_ESM.txt').read_text(encoding='utf-8-sig')
family='supplement_measured';exposure='oral_health'
for line in text.splitlines():
 if 'physician diagnosed' in line:family='supplement_diagnosed_treated';exposure='oral_health'
 if line.strip()=='Oral health':exposure='oral_health'
 if line.strip()=='Periodontal disease':exposure='periodontal'
 match=re.match(r'\s*(Good|Fair|Poor|Yes)\s+([\d,]+)/([\d,]+)\s+(.*)',line)
 if not match:continue
 values=re.findall(r'([\d.]+)\(([\d.]+)[-–]([\d.]+)\)',match[4])
 for mi,v in enumerate(values,1):targets.append(dict(family=family,subgroup='Overall',model='Model'+str(mi),exposure=exposure,term=exposure+match[1],published_OR=float(v[0]),published_low=float(v[1]),published_high=float(v[2]),published_level_cases=int(match[2].replace(',','')),published_level_n=int(match[3].replace(',','')),source='sources/europepmc/12889_2023_16012_MOESM1_ESM.txt'))
coefs=rows(ext/'tables/all_model_coefficients.csv')
counts=rows(ext/'tables/model_sample_counts_formulas.csv')
def published_group(r):
 return {'No':'Non-Smoking','Yes':'Smoking'}.get(r['subgroup'],r['subgroup']) if r['family']=='table2' else r['subgroup']
lookup={(r['candidate'],r['family'],published_group(r),r['model'],r['exposure'],r['term']):r for r in coefs}
comp=[]
primary_rows=[r for r in rows(ext/'derived/master.csv') if r['analysis_domain']=='TRUE']
def source_level_counts(t):
 sample=primary_rows
 if t['family']=='table2' and t['subgroup']!='Overall':
  smoke={'Non-Smoking':'No','Smoking':'Yes'}[t['subgroup']]
  sample=[r for r in sample if r['smoking']==smoke]
 elif t['family']=='table3':sample=[r for r in sample if r['age_group']==t['subgroup']]
 elif t['family']=='supplement_measured':sample=[r for r in sample if r['diagnosed_or_treated_htn']=='0']
 elif t['family']=='supplement_diagnosed_treated':sample=[r for r in sample if r['diagnosed_or_treated_htn']=='1' or r['hypertension_code']=='0']
 outcome={'supplement_measured':'measured_htn','supplement_diagnosed_treated':'diagnosed_or_treated_htn'}.get(t['family'],'hypertension_code')
 level=t['term'].removeprefix(t['exposure'])
 sample=[r for r in sample if r[t['exposure']]==level]
 return sum(r[outcome]=='1' for r in sample),len(sample)
for t in targets:
 c=lookup.get(('A',t['family'],t['subgroup'],t['model'],t['exposure'],t['term']))
 if c is None:raise RuntimeError(f'Missing required implemented source row: {t}')
 rec={**t,'run_id':ext_id,'candidate':'A','calculated_OR':num(c['odds_ratio']),'calculated_t_low':num(c['ci_low']),'calculated_t_high':num(c['ci_high']),'calculated_z_low':num(c.get('z_ci_low')),'calculated_z_high':num(c.get('z_ci_high')),'delta_OR':num(c['odds_ratio'])-t['published_OR'],'OR_tolerance_predeclared':.005,'within_OR_rounding':abs(num(c['odds_ratio'])-t['published_OR'])<=.005,'configuration_status':'unidentified author choices; analyst candidate','population_comparability':'different N/selection; partial reconstruction, not exact replication'}
 rec.update(delta_low=rec['calculated_t_low']-t['published_low'],delta_high=rec['calculated_t_high']-t['published_high'],within_CI_rounding=abs(rec['calculated_t_low']-t['published_low'])<=.005 and abs(rec['calculated_t_high']-t['published_high'])<=.005)
 cases,level_n=source_level_counts(t)
 rec.update(calculated_level_cases=cases,calculated_level_n=level_n,delta_level_cases=cases-t['published_level_cases'],delta_level_n=level_n-t['published_level_n'],within_count_tolerance=cases==t['published_level_cases'] and level_n==t['published_level_n'])
 comp.append(rec)
writecsv(comparison/'all_published_OR_comparisons.csv',comp)
writecsv(comparison/'publication_targets.csv',targets)
pop=[]
for t in population_targets:
 cases,level_n=source_level_counts(t)
 pop.append({**t,'calculated_level_cases':cases,'calculated_level_n':level_n,'delta_cases':cases-t['published_level_cases'],'delta_n':level_n-t['published_level_n']})
writecsv(comparison/'table2_3_all_level_population_comparison.csv',pop)
# P-trend for binary exposure is its coefficient test; oral trend uses the declared score.
trends=rows(ext/'tables/oral_trend_tests.csv')
tlookup={(r['candidate'],r['family'],published_group(r),r['model']):r for r in trends}
for file,family in [(sources/'table_2.tsv','table2'),(sources/'table_3.tsv','table3')]:
 exposure='oral_health';subgroup='Overall'
 for line in file.read_text(encoding='utf-8-sig').splitlines():
  cs=line.split('\t');label=re.sub(r'\s+',' ',cs[0]).strip()
  if label in ('Oral health','Periodontal disease'):exposure='oral_health' if label=='Oral health' else 'periodontal';subgroup='Overall'
  elif label in ('Non-Smoking','Smoking'):subgroup=label
  elif label.startswith('Age'):subgroup='30-44' if '<' in label else '45+'
  elif label=='P-trend':
   for mi,cell in enumerate(cs[2:5],1):
    model='Model'+str(mi)
    c=tlookup[('A',family,subgroup,model)] if exposure=='oral_health' else lookup[('A',family,subgroup,model,exposure,'periodontalYes')]
    p_targets.append(dict(family=family,subgroup=subgroup,exposure=exposure,model=model,published_p_text=cell,calculated_p=num(c['p_value']),source_method_status='author trend coding and df not fully specified; candidate comparison'))
family='supplement_measured';exposure='oral_health'
for line in text.splitlines():
 if 'physician diagnosed' in line:family='supplement_diagnosed_treated';exposure='oral_health'
 if line.strip()=='Oral health':exposure='oral_health'
 if line.strip()=='Periodontal disease':exposure='periodontal'
 if line.strip().startswith('P-trend'):
  values=line.strip().split()[1:]
  for mi,cell in enumerate(values,1):
   model='Model'+str(mi)
   c=tlookup[('A',family,'Overall',model)] if exposure=='oral_health' else lookup[('A',family,'Overall',model,exposure,'periodontalYes')]
   p_targets.append(dict(family=family,subgroup='Overall',exposure=exposure,model=model,published_p_text=cell,calculated_p=num(c['p_value']),source_method_status='author trend coding and df not fully specified; candidate comparison'))
writecsv(comparison/'published_trend_p_comparisons.csv',p_targets)
# The main descriptive categories and continuous rows are compared without retuning.
cats=rows(ext/'tables/A_table1_categorical.csv'); cont=rows(ext/'tables/A_table1_continuous.csv')
clook={(r['variable'],r['level'],r['hypertension_group']):r for r in cats}
vlook={(r['variable'],r['hypertension_group']):r for r in cont}
headers={'Sex':'sex','Race/ethnicity':'race','Smoking':'smoking','Periodontal disease':'periodontal','Oral Health':'oral_health','Education':'education','BMI':'bmi_category','Sleep duration':'sleep_category','Alcohol consumption':'alcohol_category','Physical activity':'activity_category','History of CVD':'cvd_category','Diabetes':'diabetes_category'}
catcomparisons=[];current=None; unmapped=[]
def clean(s):return re.sub(r'\s+','',s).lower().replace('~','-').replace('≥','>=').replace('≤','<=').replace('hours','')
for line in (sources/'table_1.tsv').read_text(encoding='utf-8-sig').splitlines():
 cs=line.split('\t');label=cs[0].strip()
 if 'N(' in label.replace(' ','') or 'N (' in label:
  current=next((v for k,v in headers.items() if label.startswith(k)),None);continue
 if 'mean (SE)' in label or label.startswith('No.'):current=None;continue
 if not current or len(cs)<3:continue
 # Match labels using their order within each variable when typography differs.
 available=[]
 for r in cats:
  if r['variable']==current and r['hypertension_group']=='No' and r['level'] not in available:available.append(r['level'])
 selected=next((v for v in available if clean(v)==clean(label)),None)
 aliases={'<High school':'Less than high school','>High school':'More than high school','Other Race-IncludingMulti-Racial':'Other race including multiracial','<\u200918.5':'Underweight','18.5\u2009~\u200924.9':'Normal','25\u2009~\u200929.9':'Overweight','≥\u200930':'Obese','<\u20097':'<7','7\u2009~\u20099':'7-9','>\u20099':'>9'}
 selected=selected or aliases.get(label)
 if selected not in available:
  # Keep unmatchable rows explicitly in coverage; source vocabulary is preserved.
  unmapped.append({'source_variable':current,'source_level':label,'available_levels':';'.join(available)});continue
 for group,cell in zip(('No','Yes'),cs[1:3]):
  m=re.match(r'([\d,]+)\(([\d.]+)\)',cell.strip())
  if not m:continue
  c=clook[(current,selected,group)]
  catcomparisons.append(dict(variable=current,level=selected,hypertension_group=group,published_n=int(m[1].replace(',','')),calculated_n=int(c['raw_n']),published_weighted_pct=float(m[2]),calculated_weighted_pct=float(c['weighted_percent']),population_status='different primary sample; descriptive comparison only'))
writecsv(comparison/'table1_categorical_comparison.csv',catcomparisons)
writecsv(comparison/'table1_unmapped_labels.csv',unmapped)
continuous_comparisons=[]
names={'Age,':'age','Total cholesterol,':'total_cholesterol','Triglyceride,':'triglycerides_biopro','Creatinine,':'creatinine','HDL,':'hdl','HbA1c,':'hba1c','Sodium,':'sodium','Fat,':'fat'}
for line in (sources/'table_1.tsv').read_text(encoding='utf-8-sig').splitlines():
 cs=line.split('\t');variable=next((v for k,v in names.items() if cs[0].startswith(k)),None)
 if variable is None or len(cs)<3:continue
 for group,cell in zip(('No','Yes'),cs[1:3]):
  m=re.fullmatch(r'([\d.]+)\(([\d.]+)\)',cell.strip())
  if not m:raise RuntimeError('Missing continuous source values')
  c=vlook[(variable,group)]
  continuous_comparisons.append(dict(variable=variable,hypertension_group=group,published_mean=float(m[1]),published_SE=float(m[2]),calculated_mean=float(c['weighted_mean']),calculated_SE=float(c['weighted_mean_se']),raw_n=int(c['raw_n']),mean_delta=float(c['weighted_mean'])-float(m[1]),source_unit_note='HbA1c LBXGH is percent; article mg/dl label differs' if variable=='hba1c' else 'same reported scale',population_status='different primary sample; descriptive comparison only'))
writecsv(comparison/'table1_continuous_comparison.csv',continuous_comparisons)
writecsv(comparison/'all_model_sample_counts.csv',counts)
reviews=a/'reviews';review_files=list(reviews.glob('*.json'))
review_summary=[]
for p in review_files:
 d=readj(p);decision=d.get('decision',d.get('verdict',d.get('status')))
 if isinstance(decision,dict):decision=decision.get('value',decision.get('status'))
 if decision is None:continue
 reviewer=d.get('reviewer_id',d.get('reviewer',d.get('role')))
 if isinstance(reviewer,dict):reviewer=reviewer.get('agent',reviewer.get('agent_id',reviewer.get('role')))
 review_summary.append({'path':p.relative_to(a).as_posix(),'sha256':sha(p),'decision':decision,'reviewer':reviewer})
dump(comparison/'comparison_manifest.json',{'run_id':ext_id,'created_at':now,'core_data_version':cr['data_version'],'extended_data_version':er['data_version'],'source_hashes':{p.name:sha(p) for p in [sources/'table_1.tsv',sources/'table_2.tsv',sources/'table_3.tsv',sources/'12889_2023_16012_MOESM1_ESM.txt']},'comparisons_sha256':sha(comparison/'all_published_OR_comparisons.csv'),'OR_rows':len(comp),'review_records':review_summary,'not_blinded':'Published results visible during source review; no numeric tuning performed.'})
if '--comparison-only' in sys.argv:
 print(json.dumps({'OR_rows':len(comp),'population_rows':len(pop),'trend_rows':len(p_targets),'table1_categorical_rows':len(catcomparisons),'table1_continuous_rows':len(continuous_comparisons),'unmapped':unmapped},ensure_ascii=False));sys.exit(0)
# Copy reviewed scientific figures into the vault, keeping source/run/hash provenance.
assets=[]
for run in (core,ext,val):
 for p in (run/'figures').glob('*.png'):
  dst=notes/'assets'/run.name/p.name;dst.parent.mkdir(parents=True,exist_ok=True)
  if dst.exists() and sha(dst)!=sha(p):raise RuntimeError('Existing asset with different hash')
  if not dst.exists():shutil.copy2(p,dst)
  assets.append({'source':str(p),'copy':str(dst),'run_id':run.name,'sha256':sha(p)})
dump(notes/'assets/manifest.json',assets)
def fig(run,name,caption):return f'![[assets/{run}/{name}]]\n\n{caption}\n'
snapshot=a/'tasks/O-DOC/rev-1/packet/original-notes';snapshot.mkdir(parents=True,exist_ok=True)
for p in notes.glob('*.md'):
 if not (snapshot/p.name).exists():shutil.copy2(p,snapshot/p.name)
def update(sid,implementation,comparison_text,review,interpretation):
 p=next(notes.glob(f'{sid}-paper *.md'));prefix=p.read_text(encoding='utf-8').split('## 구현')[0]
 version_note=f'검증 실행 `{v_id}`; 고정 이항 시나리오와 출판 비가중 표를 사용했으며 E2 원자료와 분리됩니다.' if sid=='06' else f'자료 버전 `{er["data_version"]}`; core는 `{cr["data_version"]}`.'
 p.write_text(prefix+'## 구현\n\n'+implementation+'\n\n## 재현 비교\n\n'+comparison_text+'\n\n## 검토·추가 분석\n\n'+review+'\n\n## 갱신된 해석\n\n'+interpretation+f'\n\n반영 시점: {now}. '+version_note+'\n',encoding='utf-8')
q=cr['qa'];n=q['analysis_n'];htn=q['htn_raw_n'];non=q['no_htn_raw_n']
base=f'R-CAT-001 / `{core_id}` / plan1.1 → R-EXT-002 / `E1-20261004` / plan1.4 → R-REPAIR-003 / `{ext_id}` / plan1.5. 주 후보 {n:,}명(고혈압{htn:,}, 비고혈압{non:,})를 공통 분모로 사용합니다. 상류 core 자료해시를 확장 실행이 확인하고 동일 사람의 코딩을 재사용했습니다. E1 원시 검사값 실행을 보존하고 E2에서 CDC 검사법 보정을 적용했습니다. 영향을 받지 않는 M1/M2의 재사용 출처와 모든 M3 하류 재계산을 기록했습니다.'
update('01','논문 검색→PMID/DOI 대조→Methods/표/각주→공식 원자료의 순서로 진행했습니다. '+base,
 f'출판 N21,800명과 계산 N{n:,}명 차이는 {n-21800:+,}명입니다. 저자 설정 확인과 숫자 일치가 별개이므로 전체 판정은 **부분 재현**입니다.',
 '본 논문 원문은 [공식 EuropePMC XML](../analysis/sources/europepmc/PMC10262359.fullText.xml), 보충자료는 [유효 PDF](../analysis/sources/europepmc/supplementary/12889_2023_16012_MOESM1_ESM.pdf)로 보관했습니다. 출판사 직접 다운로드가 반환한 HTML은 실패 확장자로 따로 보존했습니다. 독립 source 검토는 구강측정 방식·각주·보충표 분모를 확인했습니다.',
 'ISSUE-01 해결: 자가보고 OHQ가 이 논문의 측정 기준입니다. 이 분석은 연관 연구이며 치주 치료가 고혈압을 예방한다는 인과결론을 내리지 않습니다. 임상 치주검진을 사용한 다른 논문 재현과 구분합니다.')
update('02',base+'\n\n혈압1–4회 독립평균(SBP>0, DBP≥0), 정상이라고 판정할 때만 진단·약물 음성 확인, 양성 근거가 있으면 우선 인정했습니다. 응답7/9와 정보없는 약물질문을 정상으로 바꾸지 않았습니다. 평생100개비 흡연 후보를 사용합니다.',
 '평균의 첫회 처리, 혼합DBP0 처리, 혈압 필수값 조합과 불명확 응답 처리에서 저자의 구현은 유일하게 식별되지 않았습니다. 같은 사람이 제외되면 모든 후속 표·모형도 같은 분모에서 계산하도록 연결했습니다.',
 f'계산 불변조건 {cr["invariants_passed"]}개 통과. 코드의 가상 변환 fixture, 원자료 별표 코드와 분기, 전체/선정 응답 수는 '+link(core/'tables/raw_code_counts.csv','응답코드 수')+' 및 '+link(core/'tables/bp_reading_counts.csv','혈압 측정 수')+'에 있습니다. CDC 혈압 매뉴얼의 보고용 평균에는 첫회/0값 처리가 따로 있어 이 후보를 “CDC 표준 평균”이라고 부르지 않습니다.',
 'ISSUE-02/03 부분 해결: 후보 구현과 원자료의 코드 의미는 검토됐지만 저자 세부코드와 동일하다는 증거는 없습니다. 개인의 원자료 코딩→분모 포함→모형 기여까지 설명할 수 있으며 개인 p값은 만들지 않았습니다.')
flow=table(['선정 단계','n','직전 단계에서 제외'],[(r['stage'],f'{r["n"]:,}',r['excluded_since_previous'] if r.get('excluded_since_previous') is not None else '—') for r in q['flow']])
candidates=er.get('candidates',[])
update('03',base+'\n\n'+flow,
 table(['집단','논문 n','계산 n','차이'],[['전체',21800,n,n-21800],['비고혈압',10783,non,non-10783],['고혈압',11017,htn,htn-11017]])+f'\n비가중 고혈압 비율은 {q["htn_raw_percent"]:.2f}%, 설계 가중 비율은 {cr["htn_weighted_percent"]:.2f}%입니다. 이 두 비율은 분모와 표집 의미가 다릅니다.',
 '전체 양의MEC 가중치47,652명에서 design을 만든 뒤 대상자를 subset했습니다. 원래 SDMVSTRA/SDMVPSU를 보존했고 설계 자유도78을 확인했습니다. B는 양의 식이 day1 가중치 design을 먼저 만들고 신뢰 가능한 식이 응답 영역을 subset한 **dietary-weight sensitivity**입니다. A/B는 표본·가중치가 함께 달라지므로 숫자 차이를 방법의 우열로 판정하지 않습니다. 공변량 연속결측 대체값과 flag는 '+link(ext/'tables/continuous_missing_indicators.csv','결측 지시변수 기록')+'에 모두 기록했습니다.',
 'ISSUE-04 미해결: 최종 표본수 차이와 저자의 제외 흐름은 정확히 일치하지 않습니다. ISSUE-05 부분 해결: 필요한 가중치의 공식 지침은 확인했고 A와B를 분리 실행했습니다. 범주/지시변수 방식은 저자 구현 후보이며 결측 편향을 해결한 것으로 간주하지 않습니다.')
catcore=rows(core/'tables/table1_categorical.csv');cell=lambda level,group:next(r for r in catcore if r['variable']=='periodontal' and r['level']==level and r['hypertension_group']==group)
pdtab=table(['자가보고 치주질환','비고혈압 n (가중%)','고혈압 n (가중%)'],[[level,f'{cell(level,"No")["raw_n"]} ({fmt(cell(level,"No")["weighted_percent"],2)}%)',f'{cell(level,"Yes")["raw_n"]} ({fmt(cell(level,"Yes")["weighted_percent"],2)}%)'] for level in ['No','Yes']])
tests=[r for r in rows(core/'tables/categorical_tests.csv') if r['variable']=='periodontal' and num(r['p_value']) is not None]
testtab=table(['검정','통계량','p'],[[r['method'],fmt(r['statistic']),f'{float(r["p_value"]):.6g}'] for r in tests])
update('04',base+'\n\n'+pdtab,
 '출판 분할표와 계산 표는 서로 다른 선정분모입니다. 원문 n은 비가중, %는 설계가중입니다. 전체 공변량의 기술표를 계산했고 '+link(comparison/'table1_categorical_comparison.csv','Table1 범주 비교')+'와 '+link(comparison/'table1_continuous_comparison.csv','Table1 평균·SE 비교')+'에 연결했습니다. HbA1c LBXGH는 %이며 원문의 mg/dl 표기와 구별합니다.',
 testtab+'\n'+fig(core_id,'naive_periodontal_mosaic_residual.png',f'자가보고 치주질환×고혈압. {n:,}명 비가중 탐색용 모자이크·Pearson 잔차. 모집단 검정은 표의 Rao–Scott F를 사용합니다. 각 셀의 색은 독립 기대빈도에서의 방향과 차이를 나타냅니다.')+fig(core_id,'naive_oral_health_mosaic_residual.png',f'구강상태4범주×고혈압, 동일 {n:,}명 비가중 탐색. 셀 n·기대빈도·잔차는 pearson_cell_diagnostics.csv에 연결됩니다.'),
 'ISSUE-06 해결 범위: 일반 Pearson/Yates/Fisher를 교육용 비교, Rao–Scott를 설계 기반 추론으로 구분했습니다. p가 더 작다는 이유로 더 좋은 검정을 선택하지 않습니다. 방향·효과 크기·설계·불확실성을 함께 읽어야 합니다. 연속변수 비교 CSV의 naive Welch t는 No−Yes, survey t는 Yes−No 방향이므로 부호가 반대일 수 있습니다. 양측 p는 방향 반전의 영향을 받지 않습니다.')
main=[r for r in comp if r['family']=='table2' and r['subgroup']=='Overall']
modeltab=table(['모형','대비','논문 OR (95%CI)','계산 OR (95% t CI)','OR 차이'],[[r['model'],r['term'],f'{r["published_OR"]:.2f} ({r["published_low"]:.2f}–{r["published_high"]:.2f})',f'{r["calculated_OR"]:.3f} ({r["calculated_t_low"]:.3f}–{r["calculated_t_high"]:.3f})',f'{r["delta_OR"]:+.3f}'] for r in main])
extra=[r for r in comp if r['model']=='Model3' and not(r['family']=='table2' and r['subgroup']=='Overall')]
extratab=table(['표/집단','대비','논문 M3 OR','계산 M3 OR (95% t CI)'],[[r['family']+'/'+r['subgroup'],r['term'],f'{r["published_OR"]:.2f}',f'{r["calculated_OR"]:.3f} ({r["calculated_t_low"]:.3f}–{r["calculated_t_high"]:.3f})'] for r in extra])
interactions=rows(ext/'tables/interaction_joint_wald.csv')
writecsv(comparison/'published_interaction_p_comparisons.csv',[{'family':'table2' if r['modifier']=='smoking' else 'table3','candidate':r['candidate'],'exposure':r['exposure'],'modifier':r['modifier'],'published_p_text':'<0.001','calculated_joint_Wald_p':num(r['p_value']),'comparison_limit':'Publication does not identify the fitted interaction model and denominator df; analyst M3 joint Wald candidate.'} for r in interactions if r['candidate']=='A'])
inttab=table(['후보','노출','수정요인','joint Wald p'],[[r['candidate'],r['exposure'],r['modifier'],f'{float(r["p_value"]):.6g}'] for r in interactions])
update('05',base+'\n\nA는 MEC/5 후보, B는 식이 day1 가중치 민감도입니다. TG는 BIOPRO의LBXSTR 후보이며 일반 TG 분석에서 권고되는 referenceLBXTR와 다릅니다. [CDC BIOPRO_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm)의 검사법 변경 권고에 따라 J 주기 크레아티닌은 1.051×원값−0.06945, TG는 0.9655×원값−7.020으로 이전 주기 척도에 맞췄습니다. 원값은 보존하고 결측 대체 전에 적용했습니다. 저자가 같은 보정을 했는지는 미확인입니다. 수면0.5시간을 보존하고 음주 주기별 문항변경을 조정했습니다. 식·표본·자유도·수렴은 '+link(ext/'tables/model_sample_counts_formulas.csv','모형별 기록')+'에 있습니다.\n\n본문 Table2 M2와 Table3 M2, 보충표 M2는 서로 다른 변수를 보정했습니다. 보충 I는 진단/치료 음성인 사람의 측정고혈압 vs 정상, II는 진단/치료 고혈압 vs 원래 비고혈압으로 후보집단을 만들었습니다. 공개분모를 근거로 추론한 선정이므로 author-code-verified라고 표시하지 않습니다.',
 modeltab+'\n'+extratab+'\n모든 M1–M3와 출판 OR/CI 비교는 '+link(comparison/'all_published_OR_comparisons.csv','전체 수치 비교')+'입니다. OR/CI 반올림 허용오차0.005, 정수 n 오차0을 실행 전에 고정했습니다. 분석집단과 숨은 설정이 다르므로 가까운 숫자도 정확 재현으로 승격하지 않습니다.',
 fig(ext_id,'A_model1_3_forest.png',f'A 주 후보 {n:,}명. 치주질환 Yes vs No와 구강상태 각 범주 vs Excellent/Very good. M1/M2/M3의 보정범위는 본문 Table2 각주, 95%CI는 survey t 자유도입니다.')+fig(ext_id,'B_model1_3_forest.png','B: 식이 응답 및 식이 day1 가중치를 반영한 민감도 분석. A와 동일 분모로 읽으면 안 됩니다. 모형별 n을 위 기록에서 확인합니다.')+'\n'+inttab+'\n상호작용은 한 층의 유의/다른 층의 비유의 차이가 아니라 joint Wald로 확인했습니다. 원문의 interaction값과 다르더라도 모델·설계·표본 및 숨은 설정 차이가 있으므로 논문 오류로 단정하지 않습니다.',
 'ISSUE-07 미해결/부분 재현: 연속결측 대체, TG, 활동, 음주, 당뇨, 식이·측정의 저자 세부 구현을 유일하게 식별하지 못했습니다. ISSUE-08 조건부 지지: 후보 데이터에서 연관을 추정했으며 잔여 교란·역인과·측정오류·결측 지시변수 편향의 한계를 유지합니다. Table3의 나이군 내부 연령은 각주처럼 연속 보정하지 않아 잔여 교란이 남을 수 있습니다.')
pp=next(notes.glob('05-paper *.md'))
with pp.open('a',encoding='utf-8') as f:
 f.write('\n\n보충집단 분모: I 12,401명(측정 고혈압1,632, 비고혈압10,769), II 19,815명(진단/치료9,046, 비고혈압10,769)입니다. 주 분석 고혈압10,689명 중 진단·복약 상태 미확인인 측정 고혈압11명은 두 보충집단에서 제외됩니다. 보충 case 두 수를 더하면10,678이며 주 분석과 같은 양성분모가 아닙니다. 독립 자료 감사에서 확인한 차이를 숨기지 않습니다.\n\n전체 기준범주를 포함한 '+link(comparison/'table2_3_all_level_population_comparison.csv','Table2/3 수준별 분모 비교')+'와 '+link(comparison/'published_trend_p_comparisons.csv','출판 추세 p 비교')+'를 확인할 수 있습니다.\n')
 f.write('\n출판 상호작용 p와 후보 joint Wald의 '+link(comparison/'published_interaction_p_comparisons.csv','비교표')+'를 별도로 연결합니다. 출판 OR 84행 중 선언한 OR 오차 안의 행은 '+str(sum(r['within_OR_rounding'] for r in comp))+'행이며, 이것만으로 정확 재현을 판정하지 않습니다.\n')
 f.write('\n모형 공식과 실제 계수 열의 구분: B의 식이 domain에서는 sodium_missing와 fat_missing가 모두0이므로 해당 지시변수는 공식에 있어도 계수 추정에서 제외됩니다. 상수·공선성 열의 제외는 모형 행렬의 rank와 자유도에 반영됩니다. svyglm의 aliased metadata 빈 배열만으로 제외가 없다고 결론내리지 않고 독립 수치 감사의 제외 목록을 확인합니다.\n')
 f.write('\nE2 독립 검토: 자료·변환·연계·점추정 380개와 새 모형 수치 371개 점검을 통과했습니다. 자료 검토는 모델 추론의 승인과 구분하며, 수치 검토의 승인이 저자 설정을 확인했다는 의미는 아닙니다.\n')
pp=next(notes.glob('04-paper *.md'))
with pp.open('a',encoding='utf-8') as f:
 f.write('\n\n원문 Table1 출처 점검: 고혈압 남성5,412+여성5,606=11,018명으로 표의 총계11,017명과1명 다릅니다. 단순 산술 불일치이며 어느 셀이 맞는지는 저자 코드 없이 확정하지 않습니다. 원문 당뇨 No732/1,232 및 Missing9,177/6,913은 DIQ010 후보와 크게 다르므로 저자의 실제 문항·결측 매핑은 미확인으로 남깁니다. 출판 수치를 맞추기 위해 원자료 응답을 변경하지 않았습니다. '+link(a/'reviews/source-definition-audit.md','공식 정의·출처 감사')+'에 근거를 기록했습니다.\n')
size=rows(val/'typeI_error.csv');fisher=[r for r in size if r['test']=='Fisher']
fishtab=table(['집단당 n','귀무 공통p','정확 기각확률(%)','MC(%)','MC Wilson95%(%)'],[[r['n_per_group'],r['null_p'],fmt(100*float(r['exact_typeI']),4),fmt(100*float(r['MC_typeI']),3),f'{100*float(r["MC_low"]):.3f}–{100*float(r["MC_high"]):.3f}'] for r in fisher])
effect=rows(val/'published_OR_PR.csv')[0];ex=rows(val/'course_examples.csv')
update('06','V-FISHER/V-EFFECT/V-PAIRED / `V1-20261004` / plan1.1 / seed20261004. 각 시나리오10,000회. 검정 함수가 계산한 모든 가능한 p값 표를 MC에서 조회하여 동일 검정절차를 검증했습니다. 실제 NHANES 복합표본 추출을 재현한 시뮬레이션은 아닙니다.',
fishtab+f'\n출판 비가중 치주질환 표에서 노출군 고혈압 유병률{100*float(effect["p_exposed"]):.2f}%, 비노출군{100*float(effect["p_unexposed"]):.2f}%, crude OR={float(effect["crude_OR"]):.5f}, PR={float(effect["crude_PR"]):.5f}입니다. OR를 유병률비로 읽으면 배수를 {float(effect["OR_relative_overstatement_pct"]):.2f}% 상대적으로 크게 표현합니다. 이는 두 배수의 상대 차이이며 질병위험이7.4%증가했다는 뜻이 아닙니다. 이 CI는 SRS 교육용이며 설계보정 OR와 섞지 않습니다.',
fig(v_id,'test_size_curve.png','선과 점은 정확 열거 기각확률, 오차막대는 10,000회 MC의 Wilson95%CI입니다. 가로축은 독립 집단당 n, 세로축은 특정 귀무 p에서의 제1종 오류율. 점선은 명목0.05입니다. 전체 귀무공간 최대 size를 계산한 그림은 아닙니다.')+fig(v_id,'power_curve.png','대립가설 p0=.20, p1=.35에서 집단당 표본수에 따른 정확 열거 검정력입니다. 그래프는 정확값의 선·점이며, 10,000회 MC와 Wilson CI는 검증 실행의 CSV에서 따로 확인합니다.')+fig(v_id,'OR_PR_baseline_curve.png','고정 PR에서 기저유병률p0가 높아질 때 crude OR가 더1에서 멀어집니다. p1<1의 정의역만 계산. 표시 점은 출판 비가중 표입니다. adjusted OR 변환은 하지 않았습니다.')+table(['강의 가상 예제','p'],[[r['example'],f'{float(r["p_value"]):.9g}'] for r in ex])+'\nFisher 조건부 주변합(집단10/10, 전체성공10)에서 실제 기각확률은 0.0230141입니다. 독립 감사81/81개 검산 통과, 입력/결과 manifest15개·코드/계획 해시 일치. R 시작의 LC_* 경고는 UTF-8 로케일 설정 후 계산에 영향을 주지 않았습니다. V의 warnings=[]는 수집되지 않은 배열이므로 경고가 전혀 없었다는 증거로 사용하지 않습니다.',
 'ISSUE-09 해결 범위: 정한 독립 이항 시나리오에서 Fisher의 보수성을 확인했습니다. 모든 자료구조에서 같은 오류율이라고 일반화하지 않습니다. ISSUE-10 해결: crude OR와 PR를 수치·곡선으로 비교했습니다. ISSUE-11: NHANES에는 paired 전후가 없어 실제 McNemar는 해당 없음. 강의 가상 표의25호전/5악화에서는 조건부 Binomial exact p≈0.000324914를 확인했습니다.')
update('07',base+'\n\n필수 항목→stage→task→run→검토→표/그림→본 노트 경로를 output_coverage에 연결했습니다. 모든 초기 설명과 의문은 위에 보존하고 계산·검토를 해당 단계에 반영했습니다.',
 '재현 판정: **부분 재현**. 기본 n과 선택/결측·공변량 후보가 다르며 모든 출판 수치가 반올림 오차 안에 일치하지 않습니다. 저자 설정 확인: **일부 확인/일부 식별 불가**. 계산 정확성의 독립 검토와 저자 설정의 확인을 구별합니다.',
 table(['검토 기록','판정','해시'],[[link(a/r['path'],r['path']),r['decision'],r['sha256'][:16]] for r in review_summary])+'\n'+link(comparison/'comparison_manifest.json','비교·출처 해시')+' / '+link(a/'memory/output_coverage.json','산출물 coverage')+' / '+link(a/'config/plan-v1.5.json','확장 계획')+'\n\n노출 이력: 원문 정의를 확인할 때 구현자·검토자도 출판 수치가 포함된 웹 응답을 읽었습니다. 별도 인스턴스의 독립 감사이지만 맹검이라고 부르지 않습니다. 저자 결과값에 맞추기 위한 후보 탐색·변경은 하지 않았습니다. 검사법 보정은 공식 측정체계 근거에 따른 정의 수정이며 새 상류 정의에서 관련 하류 결과를 모두 갱신했습니다.',
 'ISSUE-12 해결 범위: 주 분석과 하위집단·그림은 같은 검토된 자료 정의를 공유하고, 식이 민감도·보충표의 다른 분모는 별도 ID로 명시했습니다. 원자료와 run을 덮어쓰지 않았으며 R1 실패도 보존했습니다. 학습 결과는 연관과 통계 구조를 이해하고 후보 구현을 재실행할 수 있는 수준입니다. 인과효과나 저자의 미공개 코드를 확정한 결과가 아닙니다.')
stage_names=[(p.name[:2],p.stem.split(' ',1)[1]) for p in sorted(notes.glob('*-concept *.md'))]
start='# 5주차: 치주질환·구강건강과 고혈압\n\n논문검색부터 공개 원자료 분석, R 통계 검증, 독립 감사, 원래 단계 문서 통합까지 진행했습니다. 지정 PMID37308938은 Li et al.(2023), DOI10.1186/s12889-023-16012-z와 일치합니다.\n\n현재 재현 수준은 **부분 재현**입니다. '+f'논문21,800명과 주 후보{n:,}명의 분모가 다르며, 미공개 공변량·결측·TG 설정을 확인한 것처럼 표현하지 않았습니다.\n\n'+ '\n'.join(f'- [[{sid}-concept {name}|{sid}. {name} — 이론]] / [[{sid}-paper {name}|논문 적용과 실행 결과]]' for sid,name in stage_names)+'\n\n핵심 발견:\n\n'+f'- 자가보고 설문을 사용한 횡단면 연구입니다. Model1도 나이·성별·인종·교육을 보정합니다.\n- 기본 후보 치주질환 Model1 OR {cr["models"]["exposure_results"][0]["odds_ratio"]:.3f}, 95% t CI {cr["models"]["exposure_results"][0]["ci_low"]:.3f}–{cr["models"]["exposure_results"][0]["ci_high"]:.3f}. M2/M3·하위집단·보충표 비교는05-paper에 있습니다.\n- Fisher 집단당5명, 귀무p=.5의 정확 기각확률2.1484%로 명목5%보다 낮습니다. 정확 열거·MC불확실성·검정력은06-paper입니다.\n- 출판 crude OR1.14835와PR1.06922의 상대 차이는7.40%. adjustedOR를RR로 바꾸지 않습니다.\n\n남은 제한: 저자 세부 선정/결측/활동/음주/당뇨/TG 설정은 식별 불가합니다. 독립 에이전트 검토는 외부 표본 검증을 뜻하지 않습니다. 출판표 일부의 이상한 결측/interaction은 원문 코드가 없어 오류로 확정하지 않았습니다.\n\n계산 위치: [R코드](../analysis/src/), [실행기록](../analysis/runs/), [현재상태](../analysis/memory/progress.md), [산출물coverage](../analysis/memory/output_coverage.json). 기준 실행 프롬프트: [v2.0 원본](../실행%20설계/05-prompts-v2.0-original.md), [5주차 일관성 보강](../실행%20설계/05-prompts-week5.md).\n'
(notes/'00-start 처음부터 따라가는 분석 흐름.md').write_text(start,encoding='utf-8')
tasks=readj(a/'memory/task_registry.json')
for t in tasks:
 t['freshness']='current'
 t['exposure_history']='Publication values visible during source review to root/P/I/Q; independent agents but no claim of blinding; no tuning. Supplemental population inference used reported denominators.'
 if t['task_id']=='R-CAT-001':t.update(state='accepted',result_path=str(core/'report.json'),review_path=str(reviews/'R2-20261004-q-review.json'),review_paths=[str(reviews/'R2-20261004-q-review.json'),str(reviews/'R2-data-review.json')],attempts=['R1-20261004 failed binary-header validator','R2-20261004 success'])
 elif t['task_id']=='R-EXT-002':t.update(state='accepted',result_path=str(a/'runs/E1-20261004/report.json'),review_path=str(reviews/'E1-20261004-q-review.json'),review_paths=[str(reviews/'E1-20261004-q-review.json'),str(reviews/'E1-data-review.json')],freshness='M1/M2 current and reused; raw-lab M3 superseded by R-REPAIR-003',attempts=['E1-20261004'])
 elif t['task_id']=='R-REPAIR-003':t.update(state='accepted',result_path=str(ext/'report.json'),review_path=str(reviews/(ext_id+'-q-review.json')),review_paths=[str(reviews/(ext_id+'-q-review.json')),str(reviews/(ext_id+'-data-review.json'))],attempts=[ext_id])
 elif t['task_id'].startswith('V-'):t.update(state='accepted',result_path=str(val/'result.json'),review_path='reviews/V1-20261004-q-review.json',attempts=[v_id])
 elif t['task_id']=='Q-AUDIT':t.update(state='accepted',result_path='reviews/',review_path='reviews/')
dump(a/'memory/task_registry.json',tasks)
coverage=[]
for id,stage,files in [('Table1','S04',['tables/A_table1_categorical.csv','tables/A_table1_continuous.csv']),('Table2','S05',['tables/A_table2_exposure_or.csv','tables/B_table2_exposure_or.csv']),('Table3','S05',['tables/A_table3_exposure_or.csv']),('SupplementI','S05',['tables/A_supplement_measured_exposure_or.csv']),('SupplementII','S05',['tables/A_supplement_diagnosed_treated_exposure_or.csv']),('trend','S05',['tables/oral_trend_tests.csv']),('interaction','S05',['tables/interaction_joint_wald.csv'])]:
 for file in files:assert(ext/file).exists(),file
 coverage.append({'id':id,'required':True,'source_checked':True,'implementation':'candidate executed','numeric_review':'independent reviewed; partial reproduction','validity_scope':'conditional support within declared definitions, weights and missing assumptions','freshness':'current','run_id':ext_id,'files':files,'document':next(notes.glob(stage[1:]+'-paper *.md')).name,'author_configuration':'partly unidentified','reproduction':'partial, not exact','continues_possible_required':False})
for id,file in [('mosaic','naive_periodontal_mosaic_residual.png'),('PearsonResidual','naive_oral_health_mosaic_residual.png')]:coverage.append({'id':id,'required':True,'implementation':'executed','run_id':core_id,'file':'figures/'+file,'numeric_review':'independent reviewed','document':'04-paper','continues_possible_required':False})
for id,file in [('Forest','A_model1_3_forest.png')]:coverage.append({'id':id,'required':True,'implementation':'executed','run_id':ext_id,'file':'figures/'+file,'document':'05-paper','continues_possible_required':False})
for id,file in [('FisherTypeI','typeI_error.csv'),('ORvsPR','published_OR_PR.csv'),('McNemarDemo','course_examples.csv')]:coverage.append({'id':id,'required':True,'implementation':'executed','numeric_review':'Q accepted81checks','run_id':v_id,'file':file,'document':'06-paper','continues_possible_required':False})
coverage.append({'id':'McNemar_actual_NHANES','required':False,'implementation':'not_applicable','reason':'no paired before/after observations'})
dump(a/'memory/output_coverage.json',coverage)
(a/'memory/progress.md').write_text('# 현재 상태\n\n범위 내 정의 가능한 필수 작업 완료: 출처 확인, paired 학습노트, 공개원자료 QA, 본문/보충모형 후보, 검정과 그림, 독립 검토, 기존문서 통합.\n\n재현 수준: 부분 재현. 선택 N와 숨은 저자 구현의 미확인은 식별불가로 기록. 실행 가능한 필수 항목을 미실행으로 남기지 않음.\n\n현재 run: '+core_id+'(core), '+ext_id+'(extended), '+v_id+'(validation). R1 실패 보존. 원자료/자료정의 동일하나 다르게 가중·선정한 B/보충집단은 별도 표기.\n\noptional common complete case: 초기 계획의 선택 항목, 실행하지 않음(deferred); 범주/연속결측 지시변수 한계는 판정에 포함.\n',encoding='utf-8')
registry=readj(a/'memory/stage_registry.json')
for s in registry:
 for typ in ('concept','paper'):s[typ+'_sha256']=sha(Path(s[typ]))
 s.update(freshness='current',integrated_runs=[core_id,ext_id,v_id],review_records=review_summary)
dump(a/'memory/stage_registry.json',registry)
with(a/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'timestamp':now,'sender':'root','task_id':'O-DOC','kind':'handoff','summary':'Reviewed runs integrated into original stages, source comparisons and coverage checked','artifact_refs':[core_id,ext_id,v_id]},ensure_ascii=False)+'\n')
print(json.dumps({'integrated':str(notes),'OR_comparisons':len(comp),'unmapped_table1_labels':unmapped,'review_records':review_summary,'assets':len(assets)},ensure_ascii=False))
