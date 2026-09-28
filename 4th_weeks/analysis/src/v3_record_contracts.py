from pathlib import Path
import hashlib,json
from datetime import datetime,timezone
r=Path(__file__).resolve().parents[1];w=r.parent
def h(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=json.loads((r/'memory/project.json').read_text(encoding='utf-8'))
q=r/'tasks/V3-Q01/rev-1/work/plan_review_v2.json'
if (q.parent/'plan_review_v3.json').exists():q=q.parent/'plan_review_v3.json'
review=json.loads(q.read_text(encoding='utf-8'))
print('Review decision:',review.get('verdict',review.get('decision')))
assert review.get('verdict',review.get('decision')) in ['accept','accept_with_limits','accept_with_conditions']
packet=r/'tasks/V3-I01/rev-1/packet'
inputs=[{'path':x.relative_to(w).as_posix(),'sha256':h(x)} for x in packet.iterdir() if x.is_file()]
for name in ['candidate_all_age50.csv','nhanes_design_all.csv']:
 x=r/'data/derived'/name;inputs.append({'path':x.relative_to(w).as_posix(),'sha256':h(x)})
c={'task_id':'V3-I01','revision':1,'owner_role':'I','worker_id':'full_implementation','reviewer_id':'continuation_review','stage_ids':['02','03','04','05','07','08','09','10'],'issue_id':'V3-COVERAGE','type':'implementation','question':'Complete executable paper output candidates and validate the documented PFQ route','estimand':'Declared-candidate conditional cross-sectional binary FI odds; separate mean-FI and selection diagnostics','allowed_inputs':inputs,'additional_inputs':'Local official raw XPT/codebooks for covariate/weight extraction, fi_candidate.json and prior implementation source only; no published effect target files','exposure_history':['Fresh worker context; method-only source excerpt excludes Figure3 published values','Orchestrator previously exposed to results; continuation is not preregistration'],'dependencies':['V3-P01','V3-D01','V3-Q01-plan'],'plan_review':{'path':q.relative_to(w).as_posix(),'sha256':h(q),'decision':review.get('verdict',review.get('decision'))},'plan_version':'V3-D01/rev-1 + freeze_addendum','acceptance_criteria':['Every required output has estimate or specific recorded nonestimability','Fixed methods, domains and family sizes preserved','Independent results and narrative review','No claim author-identical FI/cohort'], 'write_scope':['analysis/tasks/V3-I01/rev-1/work'],'outputs':['code','dictionary','execution/logs','tables','plots','handoff'],'state':'running','freshness':'current','limits':{'fix_attempts':3,'new_method_search':False},'result_path':'analysis/tasks/V3-I01/rev-1/work/handoff.md','review_path':'analysis/tasks/V3-Q01/rev-1/work/result_review.json'}
put(r/'tasks/V3-I01/rev-1/contract.json',c)
reg=json.loads((r/'memory/task_registry.json').read_text(encoding='utf-8'));reg['run_id']=p['run_id']
reg['tasks']=[t for t in reg['tasks'] if t['task_id']!='V3-I01']+[c];put(r/'memory/task_registry.json',reg)
p['prompt_sha256']=h(w/p['canonical_prompt']);put(r/'memory/project.json',p)
with (r/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'message_id':'V3-I01-approved-dispatch','timestamp':datetime.now(timezone.utc).isoformat(),'sender':'root','recipient':'full_implementation','task_id':'V3-I01','kind':'handoff','artifact_refs':[c['plan_review']['path'],'analysis/tasks/V3-I01/rev-1/contract.json'],'summary':'Approved frozen full-output candidate implementation, including corrected nonnegative reliable energy','requested_action':'Execute and preserve failures'},ensure_ascii=False)+'\n')
print('V3 actual implementation contract and packet hashes recorded')
