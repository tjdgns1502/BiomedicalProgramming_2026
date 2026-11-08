from pathlib import Path
import hashlib, json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_curve, roc_auc_score
import statsmodels.api as sm
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'analysis/runs/initial'
OLD=ROOT.parent/'5주차/analysis/data/raw/nhanes'
cycles={'G':2011,'H':2013,'I':2015,'J':2017}
parts=[]; hashes=[]
for suffix,year in cycles.items():
    frames=[]
    for stem,base in [('DEMO',OLD),('BMX',OLD),('DXX',ROOT/'analysis/data/raw')]:
        path=base/f'{stem}_{suffix}.xpt'
        hashes.append({'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        frame=pd.read_sas(path,format='xport')
        if frame.SEQN.duplicated().any(): raise ValueError(f'duplicate IDs: {path}')
        frames.append(frame)
    d=frames[0].merge(frames[1],on='SEQN',how='left',validate='one_to_one').merge(frames[2],on='SEQN',how='left',validate='one_to_one')
    d['cycle']=year; parts.append(d)
d=pd.concat(parts,ignore_index=True)
limbs=['DXDLALE','DXDRALE','DXDLLLE','DXDRLLE']
rows=[{'stage':'all participants','n':len(d)}]
d=d[d.RIDAGEYR>=20].copy(); rows.append({'stage':'age >=20','n':len(d)})
needed=['RIAGENDR','BMXBMI','BMXHT','BMXWAIST','WTMEC2YR',*limbs]
d=d.dropna(subset=needed); d=d[(d.WTMEC2YR>0)&(d.BMXBMI>0)&(d.BMXHT>0)&(d.BMXWAIST>0)].copy()
rows.append({'stage':'valid DXA, body measures and MEC weight; no covariate filtering','n':len(d)})
d['asm']=d[limbs].sum(axis=1)/1000
d['SA']=np.where(d.RIAGENDR==1,d.asm/d.BMXBMI<.789,d.asm/d.BMXBMI<.512).astype(int)
d['SO']=(d.SA.eq(1)&d.BMXBMI.ge(30)).astype(int)
h=d.BMXHT/100; waist=d.BMXWAIST/100
d['BMI']=d.BMXBMI; d['WHtR']=waist/h
d['ABSI']=waist/(d.BMI**(2/3)*h**.5)
d['BRI']=364.2-365.5*np.sqrt(1-(waist/(2*np.pi))**2/(.5*h)**2)
# Analytical candidate: whole-sample unweighted standardization, unknown authors' reference.
d['LBSIZ']=(np.log(d.ABSI)-np.log(d.ABSI).mean())/np.log(d.ABSI).std(ddof=1)
d['weight']=d.WTMEC2YR/4
pd.DataFrame(rows).to_csv(OUT/'selection.csv',index=False,encoding='utf-8-sig')
pd.DataFrame(hashes).to_csv(OUT/'source_hashes.csv',index=False,encoding='utf-8-sig')
models=[]; roc=[]
for outcome in ['SA','SO']:
  for index in ['ABSI','LBSIZ','BRI','BMI','WHtR']:
    fit=sm.GLM(d[outcome],sm.add_constant(d[index]),family=sm.families.Binomial(),freq_weights=d.weight/d.weight.mean()).fit()
    models.append({'outcome':outcome,'index':index,'unit':'1 unit','OR':np.exp(fit.params[index]),'n':len(d),'events':int(d[outcome].sum())})
    train,test=train_test_split(np.arange(len(d)),test_size=.2,random_state=42,stratify=d[outcome])
    a=d.iloc[train]; b=d.iloc[test]
    fpr,tpr,threshold=roc_curve(a[outcome],a[index],sample_weight=a.weight,drop_intermediate=False)
    k=np.argmax(tpr-fpr); cut=threshold[k]
    pred=b[index]>=cut
    se=np.average(pred[b[outcome].eq(1)],weights=b.loc[b[outcome].eq(1),'weight'])
    sp=np.average(~pred[b[outcome].eq(0)],weights=b.loc[b[outcome].eq(0),'weight'])
    roc.append({'outcome':outcome,'index':index,'train_auc':roc_auc_score(a[outcome],a[index],sample_weight=a.weight),'train_cutoff':cut,'train_youden':tpr[k]-fpr[k],'train_sensitivity':tpr[k],'train_specificity':1-fpr[k],'test_auc':roc_auc_score(b[outcome],b[index],sample_weight=b.weight),'test_sensitivity_fixed_train_cutoff':se,'test_specificity_fixed_train_cutoff':sp})
    plt.plot(fpr,tpr,label=f'{index} AUC={roc[-1]["train_auc"]:.3f}')
  plt.plot([0,1],[0,1],'k--',alpha=.5); plt.xlabel('1 - Specificity'); plt.ylabel('Sensitivity'); plt.title(f'{outcome}: weighted direct-index ROC, training (exploratory)'); plt.legend(); plt.tight_layout(); plt.savefig(OUT/f'roc_{outcome}.png',dpi=150); plt.close()
pd.DataFrame(models).to_csv(OUT/'unadjusted_point_estimates.csv',index=False,encoding='utf-8-sig')
pd.DataFrame(roc).to_csv(OUT/'direct_index_roc.csv',index=False,encoding='utf-8-sig')
print(pd.DataFrame(rows).to_string(index=False)); print('SA',int(d.SA.sum()),'SO',int(d.SO.sum())); print(pd.DataFrame(roc).round(3).to_string(index=False))
