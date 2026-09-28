# /// script
# dependencies = ["pandas==3.0.3"]
# ///
from pathlib import Path
import importlib.util,json
import pandas as pd,numpy as np
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fi',root/'src/construct_fi_candidate.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
cfg=json.loads((root/'config/fi_candidate.json').read_text(encoding='utf-8-sig'))
checks={}
def check(name,actual,expected):
 assert np.allclose(actual,expected,equal_nan=True),name
 checks[name]=True
check('yes_no_unknown',m.yes(pd.Series([1,2,3,7,9,np.nan])),[1,0,np.nan,np.nan,np.nan,np.nan])
check('inclusive_lab_bounds',m.range_deficit(pd.Series([59,60,99,100,np.nan]),[60,99]),[1,0,0,1,np.nan])
check('early_visit_straddling_primary6',m.visits(pd.DataFrame({'HUQ050':[0,1,2,3,4,5,77,99]}),6,cfg),[0,0,0,np.nan,1,1,np.nan,np.nan])
check('early_visit_alt4',m.visits(pd.DataFrame({'HUQ050':[0,1,2,3,4,5]}),4,cfg),[0,0,0,1,1,1])
check('late_visit_primary6',m.visits(pd.DataFrame({'HUQ051':[0,1,2,3,4,5,6,7,8,77,99]}),6,cfg),[0,0,0,0,1,1,1,1,1,np.nan,np.nan])
check('medication_zero_and_missing',m.meds(pd.DataFrame({'RXDUSE':[2,1,1,1,1,9,np.nan],'RXDCOUNT':[np.nan,4,5,np.nan,7,np.nan,np.nan]}),5),[0,0,1,np.nan,1,np.nan,np.nan])
(root/'runs/S02-nhanes-data/fi_candidate_rule_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
print(checks)
