# /// script
# requires-python = ">=3.11"
# dependencies = ["pandas==3.0.3"]
# ///
from pathlib import Path
# pandas 3.0.3 XPORT decoder returns IBM floating-point zero as 16**-65.
# Correct that exact representation to zero; verified against R foreign::read.xport.
import pandas as pd,json,hashlib
root=Path(__file__).resolve().parents[1];rows=[]
for folder in sorted((root/'data/raw').iterdir()):
 files=list(folder.glob('DEMO*.xpt'))
 if not files:continue
 d=pd.read_sas(files[0],format='xport').replace(16.0**-65,0.0)
 keep=['SEQN','SDDSRVYR','RIDAGEYR','RIAGENDR','RIDRETH1','SDMVSTRA','SDMVPSU','WTMEC2YR','WTMEC4YR']
 d=d[[c for c in keep if c in d]].copy();d['cycle']=folder.name
 d['weight_mec_18yr']=d.WTMEC4YR*2/9 if int(folder.name[:4]) in [1999,2001] else d.WTMEC2YR/9
 rows.append(d)
d=pd.concat(rows,ignore_index=True);assert not d.SEQN.duplicated().any()
p=root/'data/derived/nhanes_design_all.csv';d.to_csv(p,index=False)
cross=d.groupby('SDMVSTRA').agg(n_cycles=('cycle','nunique'),cycles=('cycle',lambda x:';'.join(sorted(x.unique()))),n=('SEQN','size')).reset_index()
cross.to_csv(root/'runs/S02-nhanes-data/design_strata_cycles.csv',index=False)
summary=dict(n=len(d),n_positive_weight=int(d.weight_mec_18yr.gt(0).sum()),n_age50=int(d.RIDAGEYR.ge(50).sum()),strata_shared_across_cycles=cross.loc[cross.n_cycles>1].to_dict('records'),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
(root/'runs/S02-nhanes-data/design_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8');print(json.dumps(summary,indent=2))
