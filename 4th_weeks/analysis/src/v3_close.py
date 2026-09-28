"""Close only reviewed executable output coverage, retaining author-definition uncertainty."""
from pathlib import Path
import json,csv,hashlib,shutil,re
from datetime import datetime,timezone
r=Path(__file__).resolve().parents[1];w=r.parent
def get(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def put(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=get(r/'memory/project.json');run=r/'runs'/p['run_id'];notes=w/p['learning_root'];q=r/'tasks/V3-Q01/rev-1/work';i=r/'tasks/V3-I01/rev-1/work'
for name in ['result_review.json','document_review.json']:
 z=get(q/name);assert z.get('verdict',z.get('decision')) in ['accept','accept_with_limits'],name
assert (run/'document_integration.json').exists()
needed=['continuous_models.csv','quartile_models.csv','trend_models.csv','omnibus_tests.csv','spline_tests.csv','interactions.csv','subgroup_slopes.csv','table1_descriptions.csv','table1_tests.csv','S2_S5_descriptions.csv','S2_S5_tests.csv','endpoint_audit.csv','flow_counts.csv','Figure1_flow.png','Figure2_Model2_curves.png','Figure3_subgroup_forest.png','FigS1_plus16_curves.png']
assert all((i/f).is_file() for f in needed)
errors=[]
for file in notes.glob('*.md'):
 text=file.read_text(encoding='utf-8')
 for link in re.findall(r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]',text):
  name=link.split('#')[0]
  if name and not any((base/name).exists() or (base/(name+'.md')).exists() for base in [notes,notes.parent]):errors.append(file.name+':'+link)
 for link in re.findall(r'!?\[[^\]]*\]\((assets/[^)]+)\)',text):
  if not (notes/link.split('#')[0]).exists():errors.append(file.name+':'+link)
 if text.count('```')%2:errors.append(file.name+':fences')
put(run/'document_checks.json',{'errors':errors,'scope':'local links and Markdown fences; independent narrative review separately recorded'})
assert not errors,errors
mapping={'Figure1':['flow_counts.csv','Figure1_flow.png'],'Table1':['table1_descriptions.csv','table1_tests.csv'],'Table2-Model1':['continuous_models.csv'],'Table2-Model2':['continuous_models.csv'],'Table3-Model1':['quartile_models.csv','trend_models.csv','omnibus_tests.csv'],'Table3-Model2':['quartile_models.csv','trend_models.csv','omnibus_tests.csv'],'Figure2':['spline_tests.csv','Figure2_Model2_curves.png'],'Figure3':['interactions.csv','subgroup_slopes.csv','Figure3_subgroup_forest.png'],'Supplement-S2-S5':['S2_S5_descriptions.csv','S2_S5_tests.csv'],'Supplement-S6-S7-FigS1':['continuous_models.csv','quartile_models.csv','trend_models.csv','FigS1_plus16_curves.png'],'FI-routing-sensitivity':['flow_counts.csv','item_missingness.csv','continuous_models.csv'],'FI-fractional-beta':['endpoint_audit.csv']}
cov=get(r/'memory/output_coverage.json')
for row in cov:
 key=row['output_id'];row['candidate_implementation']='reviewed_candidate_complete' if key not in ['Assignment','FI-fractional-beta'] else 'reviewed_reuse_with_endpoint_gate' if key=='FI-fractional-beta' else 'historical_reviewed_reuse'
 row['source_confirmation']='reported structure verified; exact author implementation remains partly unknown'
 row['numeric_review']='accepted_with_limits';row['documentation']='integrated_existing_stage';row['freshness']='current_for_declared_candidate'
 row['artifacts']=[(i/f).relative_to(w).as_posix() for f in mapping.get(key,[])]
 row['review']=(q/'result_review.json').relative_to(w).as_posix()
 if key=='FI-fractional-beta':row['limit']='Existing fractional mean-FI models reused; ordinary beta inapplicable to unmodified all-person FI with zero endpoints; no fit by silent endpoint removal.'
 if key=='Assignment':row['limit']='Prior strict36 candidate assignment/simulation kept historical, not rerun on new FI candidate.'
put(r/'memory/output_coverage.json',cov)
issues=get(r/'memory/issues.json')
for z in issues:
 z['source_confirmation']='partly_unresolved_author_choices';z['candidate_implementation']='completed_or_reviewed_reuse';z['numeric_review']='accepted_with_limits';z['documentation']='updated';z['freshness']='current_with_candidate_label'
 if z['stage_id'] in ['06','09']:z['status']='질문의 구분·계산 확인 완료; 저자 동일 설정 여부는 별도'
 elif z['stage_id']=='03':z['status']='설문 분기 후보 재구성·검토 완료; 저자 FI 동일성 미확인'
 else:z['status']='후속 후보 구현·검토 완료; 원문 설정 확인과 인과 주장은 제한'
put(r/'memory/issues.json',issues)
reg=get(r/'memory/task_registry.json')
for t in reg['tasks']:
 if t['task_id']=='V3-I01':t['state']='accepted';t['review_path']=(q/'result_review.json').relative_to(w).as_posix();t['result_path']=(i/'coverage_manifest.json').relative_to(w).as_posix();t['acceptance_scope']='Declared full-output candidates; not exact-author replication'
for tid,worker,role in [('V3-P01','remaining_sources','P'),('V3-D01','remaining_plan','D'),('V3-Q01','continuation_review','Q'),('V3-DOC','root','O')]:
 if not any(t['task_id']==tid for t in reg['tasks']):reg['tasks'].append({'task_id':tid,'worker_id':worker,'owner_role':role,'state':'accepted','freshness':'current','review_reference':(q/('document_review.json' if tid=='V3-DOC' else 'plan_review_v3.json' if tid in ['V3-P01','V3-D01'] else 'result_review.json')).relative_to(w).as_posix(),'acceptance_scope':'Only source/plan/review/integration work actually inspected; not independent external replication'})
put(r/'memory/task_registry.json',reg)
put(r/'memory/agent_assignments.json',{'run_id':p['run_id'],'coordinator':'root','workers':[{'task':t['task_id'],'worker':t.get('worker_id'),'role':t.get('owner_role'),'state':t['state']} for t in reg['tasks'] if t['task_id'].startswith('V3')],'isolation':'Separate task packets and ownership; shared filesystem, not OS sandbox','reviewer':'continuation_review'})
for tid in ['V3-P01','V3-D01','V3-I01','V3-Q01']:
 task=r/'tasks'/tid/'rev-1';target=run/'tasks'/tid
 shutil.copytree(task,target,dirs_exist_ok=False)
p['status']='completed_executable_candidate_coverage';p['full_paper_replication']='exact_author_settings_unresolved';p['completed_at']=datetime.now(timezone.utc).isoformat();put(r/'memory/project.json',p)
integration=get(run/'document_integration.json')
for item in integration['notes']:item['sha256']=hashlib.sha256((w/item['path']).read_bytes()).hexdigest()
integration['final_review']=(q/'document_review.json').relative_to(w).as_posix()
put(run/'document_integration.json',integration)
(r/'memory/progress.md').write_text('''# 후속 실행 완료 범위

논문 출력별 후보 구현을 완료하고 독립 코드·수치·문서 검토를 받았습니다. 완료된 네 검사만으로 중단한 이전 범위를 수정했습니다.

- 공식 PFQ 분기 재구성; 엄격 완비/분기 완비/FI30 비교 및 경계값 확인.
- Table1와 S2–S5 요약·군 비교, Table2/3 두 모형·사분위·추세.
- Model2 곡선,24개 상호작용,추가16변수 보충 분석과 곡선.
- 1999식이상태명 오류와 미사용 범주 행렬 오류 수정; 초기 출력 attempt1 보존.
- 2일 식이 전용가중 민감도와 같은 사람 비교.
- 기존 과제·모의실험·fractional 분석은 해당 후보의 과거 결과로 재사용.

원문 FI 코딩·음주·활동량·일부 가중/스플라인 설정의 동일성은 확인되지 않았습니다. 이는 정확 재현 판정의 제한이며 이번에 실행 가능한 후보 분석을 누락한 상태는 아닙니다. 각 표/그림 연결은 output_coverage.json, 읽기 시작점은 기존 Obsidian00-start입니다.
''',encoding='utf-8')
with (r/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'timestamp':p['completed_at'],'kind':'candidate_coverage_completed','run_id':p['run_id'],'source_identity':'unresolved','review':str(q.relative_to(w))},ensure_ascii=False)+'\n')
with (r/'memory/decisions.md').open('a',encoding='utf-8') as f:f.write('\n## V3 continuation decisions\n- Task-level four-check completion did not satisfy paper-output coverage; reopened and completed all executable declared candidates.\n- Official PFQ routing defines a new primary candidate; original strict36 is preserved and unchanged on shared participants.\n- Corrected1999diet status alias and unused factor levels after independent source/code review; attempt1 retained as superseded implementation failure.\n- Table1/S2-S5 source comparison tests added under independent plan addendum; same-data analyst choices remain exploratory.\n- Standard beta branch closed for unmodified endpoint-containing FI; existing fractional analysis retained for its distinct mean-FI question.\n- Document integration console print had Windows encoding failure after successful file writes; print fixed, no duplicate integration or statistical rerun.\n')
with (r/'memory/verified_facts.jsonl').open('a',encoding='utf-8') as f:
 for fact in ['PFQ route reconstruction independently agrees for all 24119 rows','1999 reliability is DRDDRSTS, not DRDDRSTZ','Ordinary beta cannot directly include observed FI zero endpoints']:
  f.write(json.dumps({'fact':fact,'run_id':p['run_id'],'source':(q/'result_review.json').relative_to(w).as_posix(),'scope':'V3 declared candidate'},ensure_ascii=False)+'\n')
put(run/'accepted_manifest.json',[{'path':f.relative_to(w).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in (run/'tasks').rglob('*') if f.is_file()])
print('Reviewed executable candidate coverage closed; exact-author identity remains unresolved.')
