"""Verify preserved document prefixes, appended links, current input/code hashes, and required artifacts."""
from pathlib import Path
import json,re,hashlib,csv
from project import ROOT,WORK,write,event,sha
run=ROOT/'runs';audit=json.loads((run/'D01-documents/append_audit.json').read_text(encoding='utf-8'))
failures=[];link_count=0
for row in audit['files']:
    p=WORK/row['path'];b=p.read_bytes()
    if hashlib.sha256(b[:row['original_bytes']]).hexdigest()!=row['before_sha256']:failures.append('Prefix changed: '+str(p))
    added=b[row['original_bytes']:].decode('utf-8')
    if added.count('<!-- NHANES-EXECUTION-20260928-v1 -->')!=1:failures.append('Marker count: '+str(p))
    for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',added):
        if target.startswith(('http://','https://')):continue
        link_count+=1
        if not (p.parent/target).resolve().exists():failures.append('Missing link: '+target)
    for target in re.findall(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]',added):
        if not (p.parent/(target+'.md')).exists():failures.append('Missing wiki target: '+target)
for task in ['A01','A02','A03']:
    recs=list(run.glob(task+'-*/execution.json'))
    if len(recs)!=1:failures.append('Ambiguous run for '+task);continue
    meta=json.loads(recs[0].read_text(encoding='utf-8'))
    if meta['exit_code']!=0:failures.append('Nonzero run '+task)
    for path,digest in meta['input_hashes'].items():
        if sha(WORK/path)!=digest:failures.append('Input hash drift '+path)
    script=Path(meta['command'][2])
    if sha(script)!=meta['script_sha256']:failures.append('Executed code drift '+str(script))
required=['A01-groups/boxplots.png','A01-groups/boxplots_log_axis.png','A01-groups/pairwise.csv',
 'A01-groups/tukey.csv','A01-groups/trend.csv','A02-models/model_sensitivities.csv',
 'M01-simulation/null_raw_p_histogram.png','M01-simulation/fwer_inflation.png',
 'M02-procedure/omnibus_summary.csv','M02-procedure/pairwise_summary.csv']
required += ['A01-groups/diagnostics_'+m+'.png' for m in ['NLR','MLR','SIRI','SII']]
for path in required:
    if not(run/path).is_file():failures.append('Missing artifact '+path)
def read(path):
    with(run/path).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
assert len(read('A01-groups/pairwise.csv'))==24
assert len(read('A01-groups/primary.csv'))==4
assert len(read('A02-models/model_sensitivities.csv'))==32
assert all(r['convergence']=='TRUE' for r in read('A02-models/model_sensitivities.csv'))
result=dict(status='PASS' if not failures else 'FAIL',files_checked=len(audit['files']),
    relative_links_checked=link_count,required_artifacts=len(required),failures=failures,
    notes='Existing prefixes and actual executed script/input hashes verified; this is delivery QA, not proof of statistical validity.')
write(run/'D01-documents/delivery_checks.json',result)
event('DELIVERY_CHECK','D01',result['status'],details=result)
print(json.dumps(result,ensure_ascii=False,indent=2))
if failures:raise SystemExit(1)
