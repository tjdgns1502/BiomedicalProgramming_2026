"""Record observed orchestration handoffs; timestamps are recording times, not invented dispatch times."""
from pathlib import Path
import json
from project import ROOT, event, write, sha

assign=json.loads((ROOT/'memory/agent_assignments.json').read_text(encoding='utf-8'))
assign['workers'][0]['additional_tasks']=['Review group_analysis.R','Review model_extensions.R']
assign['workers'][1]['write_scope']+=['analysis/src/construct_fi_candidate.py','analysis/config/fi_candidate.json']
assign['workers'][2]['additional_tasks']=['M02 actual shared comparison-core simulation','Independent code review']
assign['workers'][2]['write_scope']+=['analysis/src/procedure_simulation.R','analysis/tests/test_procedure_simulation.R','analysis/runs/M02-procedure']
write(ROOT/'memory/agent_assignments.json',assign)
records=[
 ('USER_REQUIREMENT','S02','User confirmed no supplied participant dataset; use public NHANES.'),
 ('HANDOFF_RECORDED','S01','Fresh-context evidence agent verified primary PDF/supplement and direct FI references; author FI rules remain unspecified.'),
 ('HANDOFF_RECORDED','S02','Fresh-context data agent acquired public source files and codebooks; reconstruction and zero-decoding QA in progress.'),
 ('HANDOFF_RECORDED','M01','Fresh-context simulation agent ran 10000 replicates per design; unusual corrected-error deviations retained and audited.'),
 ('TASK_EXPANDED','M02','Actual ANOVA/Welch/KW and pairwise shared code simulation delegated after M01; separate from ideal z-test principles.'),
 ('DECISION','S02','Operational36 candidate complete-case rules fixed before candidate outcome analysis; no numerical fitting to published outcomes.'),
 ('REVIEW_RESPONSE','A01','Independent reviewers found no core calculation error; labels must separate group-median score, pointwise CI, Tukey CI and BH assumptions.'),
 ('ENVIRONMENT_FIX','T02','First synthetic extension run failed writing Korean absolute path under R C locale. Retained failure log; use relative ASCII artifact arguments. R analysis unchanged.'),
]
for kind,task,body in records:event(kind,task,body,record_type='retrospective_handoff_record')
tasks=[
 dict(id='E00',agent='/root',question='Can this workspace run R reproducibly?',depends=[],accept='R session and packages captured; no global locale changes'),
 dict(id='S01',agent='/root/paper_contract',question='What does the paper explicitly specify and omit?',depends=[],accept='Claim-level source locations and uncertainty recorded'),
 dict(id='S02',agent='/root/nhanes_data',question='Can public rows yield the needed biomarkers and declared candidate FI?',depends=['S01'],accept='Unique participant joins, source checksums, codebook rules, item missingness and transform trace'),
 dict(id='M01',agent='/root/simulation',question='Does independent multiple-testing inflation agree with theory within Monte Carlo uncertainty?',depends=[],accept='Fixed seeds, raw replicates, MC intervals and all departures reported'),
 dict(id='A01',agent='/root',question='Do mean markers differ across candidate FI groups?',depends=['S02'],accept='Same-score grouping, prechosen Welch family, effect estimates, corrected p and diagnostics'),
 dict(id='M02',agent='/root/simulation',question='How does the actual comparison code behave under stated data-generating models?',depends=['A01-code'],accept='Shared statistical core, known nulls, MC uncertainty; limitations explicit'),
 dict(id='A02',agent='/root',question='How do survey design, outcome choice and measurement definitions affect inference?',depends=['S02'],accept='Preserved all-age survey design, domain analysis, distinct estimands and complete reporting'),
 dict(id='D01',agent='/root',question='Can reviewed results be traced in existing learning documents?',depends=['S01','S02','A01','A02','M01','M02'],accept='Append only to existing source and Obsidian notes; same blocks and valid links; no separate report'),
]
write(ROOT/'memory/task_registry.json',dict(recorded_at=__import__('project').stamp(),tasks=tasks,
 states=['planned','ready','running','submitted','reviewed','accepted','needs_revision','limited_by_missing_definition'],
 protocol='Workers submit file paths, source/input hashes, result, limitations; root reviews and alone updates shared notes. No passing unreviewed conclusions as common facts.',
 global_limits=['Public data only','Do not alter raw data','Do not tune to published p values','No causal claims','No pretending candidate equals author FI'],
 coordinator_limits=['Do not fill missing author definitions silently','Do not treat worker success as reviewed acceptance','Do not merge tasks with different estimands'],
 worker_limits=['Read only relevant assigned inputs','Write only assigned files','Distinguish observed result, assumption and recommendation','Report failures, do not discard inconvenient runs'],
 log_limits='Artifact and message handoff audit; not hidden reasoning logs or an OS-enforced sandbox'))
print('Recorded task contracts, ownership, handoffs and known limitations.')
