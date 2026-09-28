# /// script
# requires-python = ">=3.11"
# dependencies = ["pandas==3.0.3"]
# ///
"""Construct versioned operational 36-item candidate, explicitly not Han's recovered code.
Run uv run analysis/src/construct_fi_candidate.py
"""
from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'data/derived';RUN=ROOT/'runs/S02-nhanes-data';CFG=ROOT/'config/fi_candidate.json'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def get(d,*cols):
 result=pd.Series(np.nan,index=d.index)
 for col in cols:
  if col in d:result=result.fillna(d[col])
 return result

def yes(s):return s.map({1:1.,2:0.})
def range_deficit(s,bounds):
 low,high=bounds
 normal=pd.Series(True,index=s.index)
 if low is not None:normal &= s.ge(low)
 if high is not None:normal &= s.le(high)
 return (~normal).astype(float).where(s.notna())

def visits(d,threshold,cfg):
 out=pd.Series(np.nan,index=d.index)
 for var,key in [('HUQ050','healthcare_early_HUQ050'),('HUQ051','healthcare_late_HUQ051')]:
  vals=get(d,var)
  for code,(low,high) in cfg[key].items():
   if high<threshold:out.loc[vals.eq(float(code))]=0
   elif low>=threshold:out.loc[vals.eq(float(code))]=1
 return out

def meds(d,threshold):
 use=get(d,'RXDUSE','RXD030');count=get(d,'RXDCOUNT','RXD295')
 # Codebook reports integer medicine counts; no-use responses provide the only explicit zero.
 valid_count=count.ge(0)&count.le(100)&count.mod(1).eq(0)
 out=count.ge(threshold).astype(float).where(valid_count & use.eq(1))
 out.loc[use.eq(2)]=0
 return out

def main():
 cfg=json.loads(CFG.read_text(encoding='utf-8-sig')); inp=ROOT/cfg['input'];d=pd.read_csv(inp).copy(); f=pd.DataFrame(index=d.index)
 assert len(d)==d.SEQN.nunique()
 aliases=[('angina',['MCQ160D']),('heart_attack',['MCQ160E']),('coronary_heart_disease',['MCQ160C']),('stroke',['MCQ160F']),('thyroid',['MCQ160M','MCD160M','MCQ160I']),('cancer',['MCQ220']),('arthritis',['MCQ160A']),('hypertension',['BPQ020']),('diabetes',['DIQ010']),('kidney',['KIQ022','KIQ020']),('confusion',['PFQ057','PFQ056'])]
 for name,cols in aliases:f['def_'+name]=yes(get(d,*cols))
 function=[('managing_money','A'),('stooping','D'),('lifting','E'),('walking_rooms','H'),('chair_rise','I'),('bed','J'),('dressing','L'),('grasping','P'),('social_event','R')]
 for name,letter in function:f['def_'+name]=get(d,'PFQ061'+letter,'PFQ060'+letter).map({1:0.,2:1.,3:1.,4:1.})
 health=get(d,'HUQ010');f['def_self_rated_health']=health.isin(cfg['self_rated_health_primary']).astype(float).where(health.isin([1,2,3,4,5]))
 f['def_healthcare_use']=visits(d,cfg['healthcare_primary_min_visits'],cfg)
 f['def_health_last_year']=get(d,'HUQ020').map({1:0.,2:1.,3:0.})
 f['def_hospital_stay']=yes(get(d,'HUQ071','HUD070','HUQ070'))
 f['def_medications']=meds(d,cfg['medications_primary_min_count'])
 bp_sys=pd.concat([get(d,'BPXSY'+str(i)).rename(str(i)) for i in range(1,5)],axis=1)
 bp_dia=pd.concat([get(d,'BPXDI'+str(i)).rename(str(i)) for i in range(1,5)],axis=1)
 d['candidate_sbp_mean']=bp_sys.where(bp_sys>0).mean(axis=1)
 d['candidate_dbp_mean']=bp_dia.where(bp_dia>0).mean(axis=1)
 d['candidate_pulse_pressure_mean']=(bp_sys-bp_dia).where((bp_sys>0)&(bp_dia>0)).mean(axis=1)
 vals={ 'pulse':get(d,'BPXPLS'),'sbp':d.candidate_sbp_mean,'pulse_pressure':d.candidate_pulse_pressure_mean,'platelets':get(d,'LBXPLTSI'),'bun':get(d,'LBXSBU'),'bicarbonate':get(d,'LBXSC3SI'),'rdw':get(d,'LBXRDW'),'ldh':get(d,'LBXSLDSI','LBDSLDSI'),'alp':get(d,'LBXSAPSI','LBDSAPSI'),'calcium':get(d,'LBDSCASI') }
 # Preserve Han S1 item order: uric acid precedes calcium.
 for name in ['pulse','sbp','pulse_pressure','platelets','bun','bicarbonate','rdw','ldh','alp']:
  f['def_'+name]=range_deficit(vals[name],cfg['lab_normal_ranges_inclusive'][name])
 ua=get(d,'LBDSUASI');f['def_uric_acid']=np.nan
 for code,sex in [(1,'male'),(2,'female')]:
  mask=d.RIAGENDR.eq(code);f.loc[mask,'def_uric_acid']=range_deficit(ua,cfg['lab_normal_ranges_inclusive']['uric_acid_'+sex])[mask]
 f['def_calcium']=range_deficit(vals['calcium'],cfg['lab_normal_ranges_inclusive']['calcium'])
 assert f.shape[1]==36
 assert set(f.stack().dropna().unique()) <= {0.,1.}
 alt=f.copy()
 alt['def_self_rated_health']=health.isin(cfg['self_rated_health_alt']).astype(float).where(health.isin([1,2,3,4,5]))
 alt['def_healthcare_use']=visits(d,cfg['healthcare_alt_min_visits'],cfg)
 alt['def_medications']=meds(d,cfg['medications_alt_min_count'])
 d['candidate36_observed_items']=f.notna().sum(axis=1)
 d['candidate36_alt_observed_items']=alt.notna().sum(axis=1)
 d['FI_candidate36']=f.sum(axis=1,min_count=36)/36
 d['FI_candidate36_alt']=alt.sum(axis=1,min_count=36)/36
 d['FI']=d.FI_candidate36
 d['frail_candidate36']=d.FI_candidate36.gt(.3).astype(float).where(d.FI_candidate36.notna())
 d['frail_candidate36_alt']=d.FI_candidate36_alt.gt(.3).astype(float).where(d.FI_candidate36_alt.notna())
 d['FI_provenance']=cfg['version']+'; analyst candidate, not author-identical'
 d['age_band']=np.where(d.RIDAGEYR<60,'50-59','60+')
 f['deficit_29']=f['def_platelets']
 full=pd.concat([d,f,alt[['def_self_rated_health','def_healthcare_use','def_medications']].add_suffix('_alt')],axis=1)
 full.to_csv(OUT/'candidate_all_age50.csv',index=False)
 full[d.FI_candidate36.notna()].to_csv(OUT/'candidate_complete36.csv',index=False)
 full[d.FI_candidate36_alt.notna()].to_csv(OUT/'candidate_complete36_alt.csv',index=False)
 misses=[]
 for cycle,ix in d.groupby('cycle').groups.items():
  for name in [c for c in f if c.startswith('def_')]:misses.append(dict(cycle=cycle,item=name,n=len(ix),n_observed=int(f.loc[ix,name].notna().sum()),n_missing=int(f.loc[ix,name].isna().sum()),n_deficit=int(f.loc[ix,name].eq(1).sum())))
 pd.DataFrame(misses).to_csv(RUN/'fi_candidate_item_missingness.csv',index=False)
 flow=[]
 for (cycle,ageband),a in d.groupby(['cycle','age_band']):
  flow.append(dict(cycle=cycle,age_band=ageband,n_age50=len(a),n_cbc_positive=int(a.cbc_complete_positive.sum()),n_FI_complete36=int(a.FI_candidate36.notna().sum()),n_FI_complete36_and_cbc=int((a.FI_candidate36.notna()&a.cbc_complete_positive).sum()),n_alt_complete36=int(a.FI_candidate36_alt.notna().sum()),n_early_healthcare_bin_straddles6=int(get(a,'HUQ050').eq(3).sum())))
 pd.DataFrame(flow).to_csv(RUN/'fi_candidate_retention_flow.csv',index=False)
 eligible=full[full.FI_candidate36.notna()]
 trace=eligible.iloc[0] if len(eligible) else full.iloc[0]
 trace_dict=dict(SEQNunidentified=float(trace.SEQN),cycle=trace.cycle,age=float(trace.RIDAGEYR),status=cfg['status'],item_values={x:None if pd.isna(trace[x]) else float(trace[x]) for x in f if x.startswith('def_')},FI_candidate36=None if pd.isna(trace.FI_candidate36) else float(trace.FI_candidate36),denominator=36)
 (RUN/'fi_candidate_one_person_trace.json').write_text(json.dumps(trace_dict,indent=2),encoding='utf8')
 checks=dict(n_input=len(d),n_primary_complete=int(d.FI_candidate36.notna().sum()),n_primary_complete_cbc_positive=int((d.FI_candidate36.notna()&d.cbc_complete_positive).sum()),n_primary_frail=int(d.frail_candidate36.eq(1).sum()),n_alt_complete=int(d.FI_candidate36_alt.notna().sum()),n_alt_complete_cbc_positive=int((d.FI_candidate36_alt.notna()&d.cbc_complete_positive).sum()),n_alt_frail=int(d.frail_candidate36_alt.eq(1).sum()),n_items=len([c for c in f if c.startswith('def_')]),all_nonmissing_deficits_binary=bool(set(f.stack().dropna().unique())<={0.,1.}),all_FI_complete36=bool(d.loc[d.FI_candidate36.notna(),'candidate36_observed_items'].eq(36).all()),FI_equals_alias=bool(d.FI.equals(d.FI_candidate36)),FI_bounds_ok=bool(d.FI_candidate36.dropna().between(0,1).all()),primary_complete_by_cycle=d.groupby('cycle').FI_candidate36.count().to_dict())
 provenance=dict(config=cfg,input_sha256=sha(inp),configuration_sha256=sha(CFG),script_sha256=sha(Path(__file__)),checks=checks,output_sha256={p.name:sha(p) for p in [OUT/'candidate_all_age50.csv',OUT/'candidate_complete36.csv',OUT/'candidate_complete36_alt.csv']})
 (RUN/'fi_candidate_provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf8')
 print(json.dumps(checks,indent=2),flush=True)
if __name__=='__main__':main()
