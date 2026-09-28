"""Coordinator acceptance, artifact checksums, and environment/version handoff."""
from pathlib import Path
import json
from project import ROOT,WORK,sha,write,event,stamp
p=ROOT/'memory/task_registry.json';reg=json.loads(p.read_text(encoding='utf-8'))
for task in reg['tasks']:
    task['state']='accepted_with_limits' if task['id'] in ['S02','M01','M02','A02'] else 'accepted'
    if task['id']=='M02':task['depends']=['A01-code-reviewed']
reg['tasks'].append(dict(id='A03',agent='/root',state='accepted_exploratory',depends=['S02'],
 question='How do predeclared alternative FI rules change classification on identical people?',
 accept='Same cohort asserted; binary/quartile transition and separate attrition reported',
 output='runs/A03-coding',review='Root checked deterministic count and transition identities; not an independent clinical validation'))
reg['finalized_at']=stamp();reg['scope_status']='Assignment implementation and documented candidate analyses executed; exact paper-identical reproduction remains underdetermined.'
write(p,reg)
event('ACCEPTANCE','ROOT',reg['scope_status'],limitations=['Author FI rules missing','Published age-selection discrepancy','Model2 and exact spline replication not claimed','Complete-case selection','No causal/clinical validity claims'])
files=[]
for base in [ROOT/'src',ROOT/'config',ROOT/'tests',ROOT/'runs/A01-groups',ROOT/'runs/A02-models',ROOT/'runs/A03-coding']:
    for file in sorted(base.rglob('*')):
        if file.is_file() and '__pycache__' not in str(file):files.append(dict(path=str(file.relative_to(WORK)),bytes=file.stat().st_size,sha256=sha(file)))
write(ROOT/'runs/D01-documents/implementation_manifest.json',dict(recorded_at=stamp(),files=files))
print('Accepted bounded implementation, retained unresolved replication limits, recorded artifact hashes.')
