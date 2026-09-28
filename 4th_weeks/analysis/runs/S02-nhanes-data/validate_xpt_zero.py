# /// script
# dependencies = ["pandas==3.0.3"]
# ///
from pathlib import Path
import pandas as pd,numpy as np,json
root=Path(__file__).resolve().parents[2];run=Path(__file__).resolve().parent
ref=pd.read_csv(run/'r_xpt_reference_values.csv');checks=[]
for file,g in ref.groupby('file'):
 original=pd.read_sas(root/'data/raw'/file,format='xport').set_index('SEQN')
 corrected=original.replace(16.0**-65,0.)
 for var,h in g.groupby('variable'):
  p=corrected.loc[h.SEQN,var].to_numpy();r=h.r_value.to_numpy();raw=original.loc[h.SEQN,var].to_numpy()
  equivalent=np.isclose(p,r,rtol=1e-12,atol=1e-12,equal_nan=True)
  zero_match=(p==0)==(r==0)
  checks.append(dict(file=file,variable=var,n=len(h),r_zero=int((r==0).sum()),raw_pandas_zero=int((raw==0).sum()),pandas_IBM_zero_artifact=int((raw==16.0**-65).sum()),corrected_zero=int((p==0).sum()),zero_classifications_match=bool(zero_match.all()),numeric_values_match=bool(equivalent.all()),max_abs_difference=float(np.nanmax(np.abs(p-r)))))
pd.DataFrame(checks).to_csv(run/'xpt_zero_crosscheck.csv',index=False)
summary=dict(reference='R 4.6.1 foreign::read.xport',pandas='3.0.3',correction='exact floating value 16**(-65) -> 0, no other values changed',n_files=len(set(ref.file)),n_numeric_values=len(ref),all_zero_classifications_match=all(c['zero_classifications_match'] for c in checks),all_numeric_values_match=all(c['numeric_values_match'] for c in checks),checked_variables=checks)
(run/'xpt_zero_crosscheck.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
assert summary['all_zero_classifications_match'] and summary['all_numeric_values_match']
print({k:v for k,v in summary.items() if k!='checked_variables'})
