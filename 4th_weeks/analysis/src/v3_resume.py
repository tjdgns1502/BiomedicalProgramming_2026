from pathlib import Path
import json,shutil
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1];w=root.parent
stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ');run=root/'runs'/('V3-'+stamp)
run.mkdir(exist_ok=False)
shutil.copytree(root/'memory',run/'previous-memory')
p=json.loads((root/'memory/project.json').read_text(encoding='utf-8'))
p['prior_run_id']=p['run_id'];p['run_id']=run.name;p['status']='running';p.pop('completed_at',None)
p['required'] += ['paper Table1/Table2 Model2/Table3 Model2/Figure2/Figure3 explicit implementation coverage','FI missingness and coding candidate evidence','independent review of remaining implementations and stage integration']
p['continuation_reason']='User rejected arbitrary bounded-v2 stop; unresolved author settings limit claims, not all candidate execution.'
(root/'memory/project.json').write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
notes=w/p['learning_root'];shutil.copytree(notes,run/'original-notes',ignore=shutil.ignore_patterns('assets'))
with (root/'memory/requirements.md').open('a',encoding='utf-8') as f:f.write('\n## Continuation: 왜 마저 실행이 안되고?\nUser rejects stopping after four bounded checks. Continue remaining paper-output coverage and defined validity tasks; distinguish unavailable author details from executable candidate analyses.\n')
(root/'memory/progress.md').write_text('# 재개 중\n\nV2 네 가지 검사 완료를 전체 종료로 취급한 범위 설정을 수정합니다. 미완료 Model2·하위집단·FI 결측 및 논문 표/그림별 구현 커버리지를 조사하고 독립 계획 검토 후 실행합니다. 원 저자와 동일 설정이라는 주장은 보류하되 가능한 후보 분석은 진행합니다.\n',encoding='utf-8')
with (root/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'timestamp':stamp,'kind':'resume','run_id':run.name,'reason':p['continuation_reason']},ensure_ascii=False)+'\n')
print(run)
