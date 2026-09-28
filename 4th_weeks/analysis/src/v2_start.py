"""Start the live v2 run, preserving previous registries and learning notes."""
from pathlib import Path
import json,hashlib,datetime,shutil
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT.parent
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
run='V2-'+stamp;out=ROOT/'runs'/run;out.mkdir(parents=True,exist_ok=False)
notes=WORK/'4주차/염증과 노쇠 - 분석 길잡이'
def dump(p,o):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for p in (ROOT/'memory').glob('*'):
 if p.is_file(): (out/'previous-memory').mkdir(exist_ok=True);shutil.copy2(p,out/'previous-memory'/p.name)
backup=out/'original-notes';backup.mkdir()
for p in notes.glob('*.md'):shutil.copy2(p,backup/p.name)
names={p.name.split(' ')[0]:p for p in notes.glob('*.md')}
labels=['연구 질문과 관측 단위','혈구 측정과 설명변수','노쇠 측정과 결과변수','표본 선정·결측·설계','기술통계와 Table1','이진 결과와 오즈','척도·가정·진단','보정 모형과 Table2','설명변수 사분위와 Table3','그림·민감도·결론']
stages=[]
for i,label in enumerate(labels,1):
 key=f'{i:02d}';stages.append(dict(stage_id=key,label=label,observation_unit='participant; statistical inference uses pooled survey sample',
  concept_path=names[key+'-concept'].relative_to(WORK).as_posix(),paper_path=names[key+'-paper'].relative_to(WORK).as_posix(),
  learning_previous=f'{i-1:02d}' if i>1 else None,learning_next=f'{i+1:02d}' if i<10 else None,
  source='s12889-024-20908-9.pdf and supplement.docx; source locations in V2-P01 evidence_map',
  figure_table_ids={4:['Figure1'],5:['Table1'],8:['Table2'],9:['Table3'],10:['Figure2','Figure3','FigureS1']}.get(i,[]),
  issues=[f'ISSUE-{key}'],document_anchor='v2-stage-'+key))
tasks=[]
spec=[('V2-P01','P','v2_evidence',['01','02','03','04','08','09','10'],'data_quality',[]),
 ('V2-E01','E','v2_environment',['04','07'],'environment',[]),
 ('V2-D01','D','v2_planner',['07','08','09','10'],'statistical_validity',[]),
 ('V2-I01','I','root',['07','08','09','10'],'implementation',['V2-D01','V2-E01']),
 ('V2-Q01','Q','v2_reviewer',['01','02','03','04','05','06','07','08','09','10'],'statistical_validity',['V2-I01']),
 ('V2-DOC','O','root',[f'{i:02d}' for i in range(1,11)],'documentation',['V2-P01','V2-Q01'])]
for tid,role,worker,sids,kind,deps in spec:
 folder=ROOT/'tasks'/tid/'rev-1';folder.mkdir(parents=True,exist_ok=True)
 task=dict(task_id=tid,revision=1,stage_ids=sids,issue_id='ISSUE-'+sids[0],type=kind,
  question={'P':'Which source claims and ambiguities define the paper flow?','E':'Can existing input/code/environment evidence be reused?',
   'D':'What bounded checks address log scale, exposure grouping and nonlinearity?',
   'I':'Implement reviewed plan on declared candidate cohort','Q':'Do plan, execution and interpretation agree?',
   'O':'Can a learner follow paper explanation, question, implementation, review and updated interpretation?'}[role],
  estimand='See reviewed plan; environment/source tasks do not estimate a population parameter',owner_role=role,worker_id=worker,
  reviewer_id='v2_reviewer' if role!='Q' else 'root',required_or_optional='required',dependencies=deps,
  allowed_inputs=[],assumptions=['Existing operational36 is not verified author FI'],
  exposure_history=['root has seen publication and old results; planner receives design facts only'],
  plan_version='v2-1',plan_review={'accepted':False},methods=['Source/environment audit or pending V2-D01 plan'],
  acceptance_criteria=['Source or execution evidence with bounded conclusions; no promotion of candidate to author-identical'],
  limits={'search':'existing primary material and existing source audit first','implementation_attempts':3,'additional_scope':'log-base identity, marker-quartile model1, prespecified nonlinear diagnostic'},
  outputs=['work/handoff.md'],write_scope=[folder.relative_to(WORK).as_posix()+'/work'],state='running' if role in ['P','E','D'] else 'planned',freshness='current',attempts=[],
  result_path=folder.relative_to(WORK).as_posix()+'/result.json',review_path=folder.relative_to(WORK).as_posix()+'/review.json',
  document_anchors=['v2-stage-'+s for s in sids])
 dump(folder/'contract.json',task);tasks.append(task)
project=dict(protocol_version='2.0',run_id=run,started_at=stamp,status='running',
 paper='s12889-024-20908-9.pdf',supplement='supplement.docx',canonical_prompt='frailty-agent-workflow/docs/05-prompts.md',
 prompt_sha256=digest(WORK/'frailty-agent-workflow/docs/05-prompts.md'),learning_root=notes.relative_to(WORK).as_posix(),analysis_root='analysis',
 purpose='Paper-flow learning, bounded reconstruction and statistical scrutiny; assignment remains a separate extension',
 permissions={'public_NHANES':True,'existing_notes_edit':True,'new_HTML':False,'separate_final_report':False},
 required=['initial paper flow and unresolved questions','reuse audit','reviewed bounded plan and implementation','independent result review','stage-ordered integration'],
 exclusions=['claim exact author FI without evidence','claim causal effects','re-run unchanged old simulations','pretend observational data are randomized experiments'])
dump(ROOT/'memory/project.json',project);dump(ROOT/'memory/stage_registry.json',stages)
dump(ROOT/'memory/task_registry.json',dict(protocol_version='2.0',run_id=run,tasks=tasks))
dump(out/'initial_manifest.json',dict(project=project,original_note_hashes={p.name:digest(p) for p in backup.glob('*.md')}))
print(run)
