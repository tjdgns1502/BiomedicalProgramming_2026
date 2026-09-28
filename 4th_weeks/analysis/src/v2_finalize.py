"""Archive reviewed artifacts and update operational memory without claiming full replication."""
from pathlib import Path
import json, shutil, hashlib, re
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parents[1]; W=ROOT.parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
project=read(ROOT/'memory/project.json');run=ROOT/'runs'/project['run_id'];notes=W/project['learning_root']
q=ROOT/'tasks/V2-Q01/rev-1/work'; review=read(q/'result_review.json')
assert review['decision'] in ('accept','accept_with_limits')
docreview=read(q/'document_review.json')
assert docreview['decision'] in ('accept','accept_with_limits')
assert (run/'document_integration.json').exists()
errors=[];stages=read(ROOT/'memory/stage_registry.json')
for s in stages:
 p=W/s['paper_path'];txt=p.read_text(encoding='utf-8')
 for n in range(1,7):
  if len(re.findall(r'^## '+str(n)+r'\.',txt,re.M))!=1:errors.append(str(p)+':section'+str(n))
 if txt.count('```')%2:errors.append(str(p)+':fences')
for p in notes.glob('*.md'):
 txt=p.read_text(encoding='utf-8')
 for link in re.findall(r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]',txt):
  name=link.split('#')[0]
  if name and not any((base/name).exists() or (base/(name+'.md')).exists() for base in [notes,notes.parent]):errors.append(p.name+':'+link)
 for link in re.findall(r'!?\[[^\]]*\]\((assets/[^)]+)\)',txt):
  if not (notes/link.split('#')[0]).exists():errors.append(p.name+':'+link)
write(run/'document_checks.json',{'errors':errors,'stage_count':len(stages),'scope':'Markdown structure, local assets and wikilinks; not a rendered Obsidian UI audit'})
assert not errors,errors
registry=read(ROOT/'memory/task_registry.json')
for task in registry['tasks']:
 tid=task['task_id'];work=ROOT/'tasks'/tid/'rev-1/work'
 if work.exists():shutil.copytree(work,run/'agents'/tid,dirs_exist_ok=True)
 task['state']='accepted';task['freshness']='current'
 task['outputs']=[p.relative_to(W).as_posix() for p in work.glob('*') if p.is_file()] if work.exists() else []
 if tid=='V2-DOC':
  task['outputs']=[s['paper_path'] for s in stages]+[p.relative_to(W).as_posix() for p in notes.glob('00-start*.md')]
  task['write_scope']=[project['learning_root'],'analysis/memory',run.relative_to(W).as_posix()]
  task['reviewer_id']='v2_reviewer'
  ref=(q/'document_review.json').relative_to(W).as_posix()
 elif tid in ['V2-E01','V2-D01']:ref=(q/'plan_review.json').relative_to(W).as_posix()
 elif tid in ['V2-I01','V2-Q01']:ref=(q/'result_review.json').relative_to(W).as_posix()
 else:
  task['reviewer_id']='root';ref='analysis/tasks/V2-P01/rev-1/work/evidence_map.json'
 task['review_reference']=ref
 task['acceptance_scope']='Bounded v2 task only; author-identical FI/cohort and full paper replication remain unresolved'
 if tid=='V2-I01':task['attempts']=read(work/'execution.json')['attempts']
 if tid!='V2-I01':task['plan_review']={'applicable':False,'reason':'Source/environment/document audit or planning/review itself; not a new fitted analysis'}
 write(W/task['result_path'],{'task_id':tid,'state':'accepted','outputs':task['outputs'],'scope':task['acceptance_scope']})
 write(W/task['review_path'],{'reviewer':task['reviewer_id'],'reference':ref,'scope':task['acceptance_scope'],'review_type':'independent code and numeric review' if tid=='V2-I01' else 'scoped evidence or integration review'})
write(ROOT/'memory/task_registry.json',registry)
project['status']='completed_bounded_v2';project['full_paper_replication']='unresolved';project['completed_at']=datetime.now(timezone.utc).isoformat();write(ROOT/'memory/project.json',project)
write(ROOT/'memory/agent_assignments.json',{'coordinator':'/root','run_id':project['run_id'],'workers':[{'task':t['task_id'],'agent':t['worker_id'],'write_scope':t['write_scope'],'reviewer':t['reviewer_id']} for t in registry['tasks']],'isolation':'Fresh worker contexts and assigned write ownership; shared filesystem, not OS-enforced isolation','documentation_writer':'root'})
(ROOT/'memory/progress.md').write_text('''# 현재 실행 상태

변경 프롬프트 v2의 제한된 실행을 완료했습니다. 논문 전체의 동일 수치 재현은 미완료입니다.

- 기존 학습 문서 00 시작 및 01–10 paper를 원문 설명 → 의문 → 구현 → 비교 → 검토 → 해석 순서로 갱신했습니다.
- 논문 근거 확인, 환경·입력 재사용 감사, 독립 계획, 구현, 독립 결과 검토를 수행했습니다.
- 새로운 계산: 로그 밑 동등성, 지표 사분위 Model1, 연령 경계 인원, 고정 자연스플라인 비선형 진단.
- 과거 과제·민감도·모의실험 결과는 재사용이며 새 실행으로 표기하지 않습니다.
- 저자 FI 코딩·결측·일부 보정 정의·RCS 설정 미확인은 issues.json에 남겼습니다.
- 코드와 실행 로그는 tasks/V2-I01/rev-1/work 및 이번 runs 폴더, 검토는 tasks/V2-Q01/rev-1/work에서 확인합니다.
- HTML이나 별도 최종 보고서는 생성하지 않았습니다. 기존 Obsidian 노트가 읽기 시작점입니다.
''',encoding='utf-8')
with (ROOT/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'timestamp':project['completed_at'],'kind':'bounded_run_completed','run_id':project['run_id'],'review':str(q.relative_to(W)),'full_replication':False},ensure_ascii=False)+'\n')
manifest=[{'path':p.relative_to(W).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in (run/'agents').rglob('*') if p.is_file()]
write(run/'accepted_artifacts.json',{'run_id':project['run_id'],'artifacts':manifest,'note':'Archive copies retain original execution paths and hashes; mutable review notes may have later appended review text.'})
print('Finalized bounded run; document checks passed; exact replication remains unresolved.')
