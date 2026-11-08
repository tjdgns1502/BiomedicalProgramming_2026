from pathlib import Path
import hashlib,json
import numpy as np
import pandas as pd
import pyreadstat

ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'analysis/data/raw'
RAW=ROOT/'analysis/data/raw'
OUT=ROOT/'analysis/data/derived'
OUT.mkdir(parents=True,exist_ok=True)
cycles={'G':2011,'H':2013,'I':2015,'J':2017}
columns={
'DEMO':['SEQN','RIDAGEYR','RIAGENDR','RIDRETH3','DMDEDUC2','INDFMPIR','WTMEC2YR','SDMVPSU','SDMVSTRA'],
'DIQ':['SEQN','DIQ010'], 'BPQ':['SEQN','BPQ020','BPQ080'],
'PAQ':['SEQN','PAQ605','PAQ610','PAD615','PAQ620','PAQ625','PAD630','PAQ635','PAQ640','PAD645','PAQ650','PAQ655','PAD660','PAQ665','PAQ670','PAD675','PAD680'],
'DR1TOT':['SEQN','WTDR2D','DR1DRSTZ','DR1TKCAL','DR1TPROT'],
'DR2TOT':['SEQN','DR2DRSTZ','DR2TKCAL','DR2TPROT']}
parts=[]; manifest=[]
for suffix,year in cycles.items():
    frames=[]
    for stem,cols in columns.items():
        path=(RAW if stem=='DR2TOT' else OLD)/f'{stem}_{suffix}.xpt'
        manifest.append({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'url':f'https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{year}/DataFiles/{stem}_{suffix}.xpt'})
        df,_=pyreadstat.read_xport(str(path),usecols=cols)
        if df.SEQN.duplicated().any(): raise ValueError(f'Duplicate SEQN {path}')
        frames.append(df)
    d=frames[0]
    for f in frames[1:]: d=d.merge(f,on='SEQN',how='left',validate='one_to_one')
    d['cycle']=year
    parts.append(d)
d=pd.concat(parts,ignore_index=True)
d['age']=d.RIDAGEYR; d['sex']=d.RIAGENDR; d['race']=d.RIDRETH3
d['education']=d.DMDEDUC2.where(d.DMDEDUC2.isin([1,2,3,4,5]))
d['poverty']=d.INDFMPIR
# These are narrower proxies for paper labels; never claim equivalent to clinical definitions.
d['diabetes_self_report']=d.DIQ010.map({1:1,2:0,3:0})
d['hypertension_self_report']=d.BPQ020.map({1:1,2:0})
d['cholesterol_self_report']=d.BPQ080.map({1:1,2:0})
components=[]
for flag,days,minutes,mult in [('PAQ605','PAQ610','PAD615',8),('PAQ620','PAQ625','PAD630',4),('PAQ635','PAQ640','PAD645',4),('PAQ650','PAQ655','PAD660',8),('PAQ665','PAQ670','PAD675',4)]:
    value=pd.Series(np.nan,index=d.index)
    value.loc[d[flag].eq(2)]=0
    ok=d[flag].eq(1)&d[days].between(1,7)&d[minutes].between(1,1440)
    value.loc[ok]=d.loc[ok,days]*d.loc[ok,minutes]*mult
    components.append(value)
d['activity_met_min_week']=pd.concat(components,axis=1).sum(axis=1,min_count=5)
d['inactivity']=(d.activity_met_min_week<600).astype(float).where(d.activity_met_min_week.notna())
sit=d.PAD680.where(d.PAD680.between(0,1440))
d['sedentary']=pd.cut(sit,[-1,240,360,480,1440],labels=['<4','4-6','6-8','>=8'],right=False).astype('string')
valid=d.DR1DRSTZ.eq(1)&d.DR2DRSTZ.eq(1)
d['diet2_valid']=valid.astype(int)
d['energy']=((d.DR1TKCAL+d.DR2TKCAL)/2).where(valid)
d['protein']=((d.DR1TPROT+d.DR2TPROT)/2).where(valid)
d['weight_mec']=d.WTMEC2YR/4
d['weight_diet2']=d.WTDR2D/4
out=['SEQN','cycle','age','sex','race','education','poverty','diabetes_self_report','hypertension_self_report','cholesterol_self_report','activity_met_min_week','inactivity','sedentary','diet2_valid','energy','protein','SDMVSTRA','SDMVPSU','weight_mec','weight_diet2']
d[out].to_csv(OUT/'covariates_candidate.csv',index=False,encoding='utf-8-sig')
(OUT/'covariates_sources_generated.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('rows',len(d),'duplicate',d.SEQN.duplicated().sum())
print(d[out].notna().sum().to_string())
