from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]
items=[('Figure1','04','Cohort inclusion and exclusion counts'),('Table1','05','Frail/nonfrail continuous and categorical descriptions'),('Table2-Model1','08','Continuous log-marker adjusted association'),('Table2-Model2','08','Full covariate candidate adjustment'),('Table3-Model1','09','Marker quartile contrasts and trend'),('Table3-Model2','09','Full-adjusted quartiles and trend'),('Figure2','10','Full-adjusted nonlinear curves'),('Figure3','10','Six moderators and interaction tests'),('Supplement-S2-S5','05','Descriptions by marker quartiles'),('Supplement-S6-S7-FigS1','10','Additional disease/lab adjustment candidate'),('FI-routing-sensitivity','03','Verified skip-derived zero candidate versus complete36'),('FI-fractional-beta','03','Existing fractional results and beta eligibility'),('Assignment','09','Prior FI-group comparisons and procedure simulations')]
out=[]
for key,stage,purpose in items:
 out.append(dict(output_id=key,stage_id=stage,question=purpose,source_confirmation='pending_current_source_audit',candidate_implementation='reusable' if key in ['Assignment','FI-fractional-beta'] else 'planned',numeric_review='pending',validity_scope='candidate observational association; not author-identical',documentation='pending',task_id='V3-I01' if key!='Assignment' else 'historical A01/M01/M02',freshness='pending'))
(r/'memory/output_coverage.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered',len(out),'output requirements')
