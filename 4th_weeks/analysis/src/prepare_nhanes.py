# /// script
# requires-python = ">=3.11"
# dependencies = ["pandas==3.0.3"]
# ///
"""Prepare auditable NHANES observed variables. No frailty score is inferred here.
uv run analysis/src/prepare_nhanes.py
"""
from pathlib import Path
import json,re,html
import numpy as np
# pandas 3.0.3 XPORT decoder returns IBM floating-point zero as 16**-65.
# Correct that exact representation to zero; verified against R foreign::read.xport.
import pandas as pd
ROOT=Path(__file__).resolve().parents[1];RAW=ROOT/'data/raw';OUT=ROOT/'data/derived';RUN=ROOT/'runs/S02-nhanes-data'
DEMO=['SEQN','SDDSRVYR','RIAGENDR','RIDAGEYR','RIDRETH1','RIDRETH3','DMDEDUC2','INDFMPIR','WTMEC2YR','WTMEC4YR','WTINT2YR','WTINT4YR','SDMVPSU','SDMVSTRA']
KEEP=set(DEMO+['BMXBMI','SMQ020','ALQ101','ALQ110','ALQ120Q','ALQ120U','ALQ130','ALQ100','DRXTKCAL','DR1TKCAL','DR2TKCAL','DRDDRSTZ','DR1DRSTZ','DR2DRSTZ','DRDINT','RXDUSE','RXDCOUNT','RXD030','RXD295'])
KEEP.update(['LBXWBCSI','LBDLYMNO','LBDMONO','LBDNENO','LBXPLTSI','LBXRDW','LBXNEPCT','LBXMOPCT','LBXLYPCT','LBXSBU','LBDSBUSI','LBXSC3SI','LBXSLDSI','LBDSLDSI','LBXSAPSI','LBDSAPSI','LBDSUASI','LBDSCASI','LBXSUA','LBXSCA'])
PREFIXES=('PFQ','MCQ','MCD','HUQ','HUD','HSD','BPQ','DIQ','KIQ','BPX','PAQ','PAD')
def wanted(c):return c in KEEP or c.startswith(PREFIXES)

def main():
 OUT.mkdir(parents=True,exist_ok=True); schema=[]; qc=[];cycles=[]
 for folder in sorted(RAW.iterdir()):
  demos=list(folder.glob('DEMO*.xpt'))
  if not demos:continue
  df=pd.read_sas(demos[0],format='xport').replace(16.0**-65,0.0);df=df[[x for x in DEMO if x in df]].copy()
  original_n=len(df); df['cycle']=folder.name; df['cycle_start']=int(folder.name[:4])
  for file in sorted(folder.glob('*.xpt')):
   if '_2_' in file.stem: continue  # Repeat-exam convenience sample is not used.
   data=pd.read_sas(file,format='xport').replace(16.0**-65,0.0); filename=file.stem
   book=file.with_suffix('.htm'); titles={}
   if book.exists():
    for raw in re.findall(r'<h3[^>]*>(.*?)</h3>',book.read_text(encoding='utf-8-sig'),re.S):
     title=html.unescape(re.sub('<[^>]+>',' ',raw)); title=' '.join(title.split())
     if ' - ' in title: k,v=title.split(' - ',1);titles[k]=v
   for c in data:
    if wanted(c):schema.append(dict(cycle=folder.name,file=filename,variable=c,label=titles.get(c,''),n=len(data),n_nonmissing=int(data[c].notna().sum()),url=f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{folder.name[:4]}/DataFiles/{filename}.htm#{c}'))
   if file==demos[0]:continue
   cols=['SEQN']+[x for x in data if x!='SEQN' and wanted(x) and x not in df]
   if len(cols)==1:continue
   data=data[cols]
   if filename.startswith('RXQ_RX'):
    # Person-level drug count/use variables repeat across medicines. Never count rows as drugs.
    for c in cols[1:]:
     if data.groupby('SEQN')[c].nunique().max()>1:raise ValueError(f'Conflicting person-level medication values: {filename}/{c}')
    data=data.groupby('SEQN',as_index=False).first()
   if data.SEQN.duplicated().any():raise ValueError(f'Duplicate person key {filename}')
   df=df.merge(data,on='SEQN',how='left',validate='one_to_one')
  adult=df[df.RIDAGEYR>=50].copy()
  for c in ['LBDLYMNO','LBDNENO','LBDMONO','LBXPLTSI']:
   if c not in adult:adult[c]=np.nan
  denom=adult.LBDLYMNO.where(adult.LBDLYMNO>0)
  adult['NLR']=adult.LBDNENO/denom;adult['MLR']=adult.LBDMONO/denom
  adult['SIRI']=adult.LBDNENO*adult.LBDMONO/denom;adult['SII']=adult.LBXPLTSI*adult.LBDNENO/denom
  for c in ['NLR','MLR','SIRI','SII']:adult['ln_'+c]=np.log(adult[c].where(adult[c]>0))
  adult['cbc_complete_positive']=adult[['LBDLYMNO','LBDNENO','LBDMONO','LBXPLTSI']].gt(0).all(axis=1)
  # Official NHANES 1999-2016 18-year combined exam weight. Early four-year weights are required.
  adult['weight_mec_18yr']=adult['WTMEC2YR']/9
  if int(folder.name[:4]) in [1999,2001]:
   adult['weight_mec_18yr']=adult['WTMEC4YR']*2/9 if 'WTMEC4YR' in adult else np.nan
  qc.append(dict(cycle=folder.name,n_demo=original_n,n_age50=len(adult),n_cbc_complete_positive=int(adult.cbc_complete_positive.sum()),n_psu=int(adult.SDMVPSU.nunique()),n_strata=int(adult.SDMVSTRA.nunique()),n_mec_weight_positive=int(adult.WTMEC2YR.gt(0).sum())))
  adult.to_csv(OUT/f'nhanes_{folder.name}_age50_observed.csv',index=False)
  cycles.append(adult)
  print(folder.name, 'prepared', len(adult), flush=True)
 merged=pd.concat(cycles,ignore_index=True)
 assert not merged.SEQN.duplicated().any(),'SEQN not unique across cycles'
 merged.to_csv(OUT/'nhanes_1999_2016_age50_observed.csv',index=False)
 pd.DataFrame(schema).to_csv(RUN/'variable_schema.csv',index=False)
 pd.DataFrame(qc).to_csv(RUN/'cohort_availability.csv',index=False)
 pd.DataFrame([dict(variable=c,n_present=int(merged[c].notna().sum()),n_missing=int(merged[c].isna().sum())) for c in merged]).to_csv(RUN/'missingness_observed.csv',index=False)
 (RUN/'preparation_summary.json').write_text(json.dumps(dict(cycles=len(cycles),n=len(merged),columns=len(merged.columns),fi_computed=False,biomarker_units='cell counts 1000 cells/uL; SIRI and SII in 1000 cells/uL; NLR/MLR unitless',notes=['Observed raw codes retained, including refused/dont-know sentinel values.','Age is public-use topcoded; use RIDAGEYR as released.','No author-specific FI coding inferred.','Use cbc_complete_positive for logarithmic biomarker analyses.','MEC combined weight 1999/2001 WTMEC4YR*(4/18); later WTMEC2YR*(2/18).','Single-cycle analysis must use original WTMEC2YR.']),indent=2),encoding='utf8')
 print(pd.DataFrame(qc).to_string(index=False));print('Merged',len(merged),'rows',len(merged.columns),'columns')
if __name__=='__main__':main()
