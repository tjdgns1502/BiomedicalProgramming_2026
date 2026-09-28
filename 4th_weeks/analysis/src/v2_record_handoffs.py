"""Record real task handoffs and approved plan without altering earlier executions."""
from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT.parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,o):p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
reg=read(ROOT/'memory/task_registry.json');review=read(ROOT/'tasks/V2-Q01/rev-1/work/plan_review.json')
plan=ROOT/'tasks/V2-D01/rev-1/work/plan.json'
messages=[]
for t in reg['tasks']:
 folder=ROOT/'tasks'/t['task_id']/'rev-1'
 if t['task_id'] in ['V2-P01','V2-E01','V2-D01']:
  t['state']='submitted';t['outputs']=[p.relative_to(WORK).as_posix() for p in (folder/'work').glob('*') if p.is_file()]
  handoff=dict(task_id=t['task_id'],submitted_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
   recorded_after_actual_dispatch=True,artifacts={p:sha(WORK/p) for p in t['outputs']},
   conclusion='See handoff. Independent review or bounded source acceptance remains explicitly recorded separately.')
  dump(folder/'result.json',handoff)
 if t['task_id']=='V2-I01':
  t['worker_id']='v2_implementer';t['state']='running';t['plan_version']='V2-D01/rev-1'
  t['plan_review']={'accepted':True,'reviewer_id':'v2_reviewer','path':'analysis/tasks/V2-Q01/rev-1/work/plan_review.json','sha256':sha(ROOT/'tasks/V2-Q01/rev-1/work/plan_review.json')}
  t['allowed_inputs']=[{'path':p,'sha256':sha(WORK/p)} for p in ['analysis/tasks/V2-D01/rev-1/work/plan.json','analysis/tasks/V2-Q01/rev-1/work/plan_review.json','analysis/data/derived/candidate_complete36.csv','analysis/data/derived/nhanes_design_all.csv','analysis/config/fi_candidate.json']]
  t['methods']=['Approved four bounded checks; common sample; no published effect targets supplied to implementation']
  t['attempts']=[{'status':'running','plan_sha256':sha(plan)}]
 if t['task_id'] in ['V2-D01','V2-E01']:
  t['state']='accepted'
  t['review_reference']='analysis/tasks/V2-Q01/rev-1/work/plan_review.json'
  t['acceptance_scope']='plan and input reuse only; not statistical validity of historical results'
 dump(folder/'contract.json',t)
 messages.append(dict(timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),kind='handoff_record',task_id=t['task_id'],state=t['state'],note='Recorded current actual work; not backdated pre-execution approval.'))
dump(ROOT/'memory/task_registry.json',reg)
with (ROOT/'memory/events.jsonl').open('a',encoding='utf-8') as f:
 for m in messages:f.write(json.dumps(m,ensure_ascii=False)+'\n')
print('Recorded source/environment/planning handoffs, Q plan approval and separate I implementation.')
