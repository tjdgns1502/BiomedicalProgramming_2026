import hashlib
import json
import pathlib
import subprocess
from datetime import datetime, timezone

root = pathlib.Path.cwd()
out = root / 'analysis/tasks/V2-E01/rev-1/work'
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
def check(path, expected):
    p = root / path
    actual = sha(p)
    return {'path': str(path).replace('\\', '/'), 'recorded_sha256': expected, 'current_sha256': actual, 'match': actual == expected}
runs = []
for task in ['A01', 'A02', 'A03']:
    for p in sorted((root/'analysis/runs').glob(task+'-*/execution.json')):
        e = json.loads(p.read_text(encoding='utf-8-sig'))
        groups = {k: [check(n, v) for n, v in e[k].items()] for k in ['source_hashes','config_hashes','input_hashes']}
        runs.append({'task_id': task, 'execution_path': p.relative_to(root).as_posix(), 'execution_sha256': sha(p), 'exit_code': e.get('exit_code'), 'finished': e.get('finished'), 'recorded_status': e.get('status'), 'status_note': 'submitted is stale lifecycle wording; finished and exit_code=0 record completion', 'checks': groups, 'all_recorded_hashes_match': all(c['match'] for cs in groups.values() for c in cs)})
prov_path=root/'analysis/runs/S02-nhanes-data/fi_candidate_provenance.json'
prov=json.loads(prov_path.read_text(encoding='utf-8-sig'))
provenance_checks=[check('analysis/'+prov['config']['input'],prov['input_sha256']),check('analysis/config/fi_candidate.json',prov['configuration_sha256']),check('analysis/src/construct_fi_candidate.py',prov['script_sha256'])]
provenance_checks += [check('analysis/data/derived/'+n,h) for n,h in prov['output_sha256'].items()]
env=json.loads((root/'analysis/config/environment.json').read_text(encoding='utf-8-sig'))
rscript=pathlib.Path(env['rscript'])
code='cat(R.version.string,"\\n"); cat("survey=",as.character(packageVersion("survey")),"\\n",sep="")'
current=subprocess.run([str(rscript),'--vanilla','-e',code],capture_output=True,text=True) if rscript.exists() else None
outputs=[]
for folder in ['A01-groups','A02-models','A03-coding']:
    outputs += [{'path': p.relative_to(root).as_posix(), 'current_sha256': sha(p), 'bytes': p.stat().st_size} for p in sorted((root/'analysis/runs'/folder).rglob('*')) if p.is_file()]
audit={'audit_id':'V2-E01/rev-1','audited_at_utc':datetime.now(timezone.utc).isoformat(),'method':'Read-only SHA-256 comparisons with existing execution/provenance records; no statistical analyses or tests rerun. Current output hashes are a new inventory, not historical integrity proof.','runs':runs,'candidate_provenance':{'path':prov_path.relative_to(root).as_posix(),'sha256':sha(prov_path),'checks':provenance_checks,'recorded_counts':prov['checks'],'status':prov['config']['status']},'environment':{'config_sha256':sha(root/'analysis/config/environment.json'),'rscript_path':str(rscript),'exists':rscript.exists(),'current_probe_exit_code':current.returncode if current else None,'current_probe_stdout':current.stdout if current else None,'current_probe_stderr':current.stderr if current else None,'historical_session_info_sha256':sha(root/'analysis/runs/E00-environment/session-info.txt'),'limit':'Path and current R/survey version checked; full historical package/binary equivalence is not established.'},'existing_output_inventory':outputs,'reuse_decision':{'conditional_artifact_reuse':all(r['all_recorded_hashes_match'] and r['exit_code']==0 for r in runs) and all(c['match'] for c in provenance_checks),'statistical_validity_certified':False,'author_identical_reproduction_certified':False,'limits':['9814 complete FI and 9786 positive-CBC complete FI are analyst-defined candidate cohort counts, not proof of author-identical data.','No execution record provides historical output hashes; current output inventory cannot establish that outputs were unchanged since execution.','Unchanged bytes and a prior zero exit code do not establish statistical validity, correct inference, or original-paper replication.','analysis_plan status provisional-data-definition-pending is descriptive metadata; unchanged runtime inputs and source hashes determine this narrow reuse audit. Changes to explanatory documents alone do not imply changed statistical inputs.','Any future change to candidate input, executed code, grouping/coding choices or relevant model configuration requires reassessment and potentially rerun.']}}
(out/'reuse_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# V2-E01 reuse handoff','',f"Conditional artifact reuse: {audit['reuse_decision']['conditional_artifact_reuse']}.",'','All recorded input/source/config hashes are compared separately in reuse_audit.json. This is a byte/provenance audit, not a statistical review. No tests or statistical analyses were rerun.','',*['- '+s for s in audit['reuse_decision']['limits']],'','## Evidence hashes','',f'- reuse_audit.json: {sha(out/"reuse_audit.json")}',f'- fi_candidate_provenance.json: {sha(prov_path)}',*['- '+r['execution_path']+': '+r['execution_sha256'] for r in runs],'','## Current environment','',current.stdout.strip() if current else 'Rscript missing','',f'Current output inventory: {len(outputs)} files; historical output hashes unavailable.','', 'No raw data, existing logs, root documentation, or contracts were modified. Only this task work directory was written.']
(out/'handoff.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'reuse':audit['reuse_decision']['conditional_artifact_reuse'],'run_matches':[(r['task_id'],r['all_recorded_hashes_match']) for r in runs],'provenance_matches':all(c['match'] for c in provenance_checks),'output_files':len(outputs),'audit_sha256':sha(out/'reuse_audit.json'),'handoff_sha256':sha(out/'handoff.md'),'mismatches':[c for r in runs for cs in r['checks'].values() for c in cs if not c['match']]},indent=2))
