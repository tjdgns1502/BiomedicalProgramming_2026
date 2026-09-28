# /// script
# requires-python = ">=3.11"
# dependencies = ["pandas==3.0.3"]
# ///
from pathlib import Path
import pandas as pd
import numpy as np
import json,hashlib
root=Path.cwd(); out=root/'analysis/tasks/V3-Q01/rev-1/work'
source=root/'analysis/data/derived/candidate_all_age50.csv'
d=pd.read_csv(source)
assert not d.SEQN.duplicated().any()
items={'A':'managing_money','D':'stooping','E':'lifting','H':'walking_rooms','I':'chair_rise','J':'bed','L':'dressing','P':'grasping','R':'social_event'}
defcols=[c for c in d if c.startswith('def_') and not c.endswith('_alt')]
assert len(defcols)==36,defcols
orig=d[defcols].copy();new=orig.copy(); route=pd.Series(False,index=d.index);cells=pd.Series(0,index=d.index);logs=[];inputs=[{'path':str(source.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}]
for cyc,idx in d.groupby('cycle').groups.items():
 p=next((root/'analysis/data/raw'/cyc).glob('PFQ*.xpt'))
 raw=pd.read_sas(p,format='xport').set_index('SEQN');assert raw.index.is_unique
 raw=raw.reindex(d.loc[idx,'SEQN']);raw.index=idx
 early=cyc in ['1999-2000','2001-2002']
 req=['PFQ048','PFQ056','PFQ059'] if early else ['PFQ049','PFQ057','PFQ059','PFQ051','PFQ054']
 r=d.loc[idx,'RIDAGEYR'].between(50,59)&raw[req].eq(2).all(axis=1)
 if early:r &= ~raw[['PFQ050','PFQ055']].eq(1).any(axis=1)
 route.loc[idx]=r
 cnt={}
 for letter,name in items.items():
  col=('PFQ060' if early else 'PFQ061')+letter
  mask=r&raw[col].isna()
  assert orig.loc[idx[mask],'def_'+name].isna().all()
  new.loc[idx[mask],'def_'+name]=0
  cells.loc[idx]+=mask.astype(int)
  cnt[letter]=int(mask.sum())
 inputs.append({'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 logs.append({'cycle':cyc,'n_age50':len(idx),'route_eligible':int(r.sum()),'modified_cells_by_suffix':cnt,'modified_cells':sum(cnt.values()),'persons_any_modified':int(cells.loc[idx].gt(0).sum())})
strict=orig.sum(axis=1,min_count=36)/36; revised=new.sum(axis=1,min_count=36)/36
assert np.allclose(strict,d.FI_candidate36,equal_nan=True)
assert np.allclose(strict[strict.notna()],revised[strict.notna()])
assert orig[~route].equals(new[~route])
assert not (orig.notna() & orig.ne(new)).any().any()
for record in logs:
 idx=d.index[d.cycle.eq(record['cycle'])]
 record.update(strict_complete=int(strict.loc[idx].notna().sum()),route_complete=int(revised.loc[idx].notna().sum()),new_complete=int((strict.loc[idx].isna()&revised.loc[idx].notna()).sum()))
markers=['NLR','MLR','SIRI','SII'];positive=d[markers].gt(0).all(axis=1)&np.isfinite(d[markers]).all(axis=1)
summary={'reviewer':'continuation_review','method':'Independent raw PFQ reconstruction, no implementation-agent code read; no fitting','inputs':inputs,'n_age50':len(d),'route_eligible':int(route.sum()),'persons_any_modified':int(cells.gt(0).sum()),'modified_cells':int(cells.sum()),'strict_complete':int(strict.notna().sum()),'route_complete':int(revised.notna().sum()),'new_complete':int((strict.isna()&revised.notna()).sum()),'strict_complete_positive4markers':int((strict.notna()&positive).sum()),'route_complete_positive4markers':int((revised.notna()&positive).sum()),'strict_shared_fi_identical':True,'observed_deficits_unchanged':True,'outside_route_unchanged':True,'by_cycle':logs}
(out/'expected_pfqqa.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
pd.DataFrame({'SEQN':d.SEQN,'cycle':d.cycle,'route_eligible':route,'modified_cells':cells,'strict_FI':strict,'route_FI':revised}).to_csv(out/'expected_pfqqa_rows.csv',index=False)
print(json.dumps({k:v for k,v in summary.items() if k not in ['inputs','by_cycle']},indent=2))
