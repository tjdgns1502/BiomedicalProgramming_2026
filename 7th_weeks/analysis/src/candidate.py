from pathlib import Path
import argparse, hashlib, json, platform, sys
import numpy as np, pandas as pd, pyreadstat, statsmodels.api as sm
from scipy.stats import t
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_curve, roc_auc_score
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--run-id',required=True); args=parser.parse_args()
if not args.run_id or Path(args.run_id).name != args.run_id or args.run_id in {'.','..'}: parser.error('run-id must be one directory name')
OUT=ROOT/'analysis/runs'/args.run_id
OUT.mkdir(parents=True,exist_ok=False)
raw=ROOT/'analysis/data/raw'; OLD=raw
parts=[]; hashes=[]
for suff,year in [('G',2011),('H',2013),('I',2015),('J',2017)]:
    f=[]
    for stem,base in [('DEMO',OLD),('BMX',OLD),('DXX',raw)]:
        p=base/f'{stem}_{suff}.xpt'; hashes.append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        z=pyreadstat.read_xport(str(p))[0]
        assert z.SEQN.is_unique
        f.append(z)
    z=f[0].merge(f[1],on='SEQN',how='left',validate='one_to_one').merge(f[2],on='SEQN',how='left',validate='one_to_one'); z['cycle']=year; parts.append(z)
d=pd.concat(parts,ignore_index=True)
cpath=ROOT/'analysis/data/derived/covariates_candidate.csv'
c=pd.read_csv(cpath); hashes.append({'path':str(cpath),'sha256':hashlib.sha256(cpath.read_bytes()).hexdigest()})
d=d.merge(c,on=['SEQN','cycle'],how='left',validate='one_to_one',suffixes=('','_cov'))
limbs=['DXDLALE','DXDRALE','DXDLLLE','DXDRLLE']; basic=['RIAGENDR','BMXBMI','BMXHT','BMXWAIST','WTMEC2YR','SDMVSTRA','SDMVPSU']+limbs
valid=(d.RIDAGEYR>=20)&d[basic].notna().all(axis=1)&(d.WTMEC2YR>0)&(d.BMXBMI>0)&(d.BMXHT>0)&(d.BMXWAIST>0)
d['asm']=d[limbs].sum(axis=1,min_count=4)/1000
d['SA']=np.where(d.RIAGENDR==1,d.asm/d.BMXBMI<.789,d.asm/d.BMXBMI<.512).astype(int); d['SO']=(d.SA.eq(1)&d.BMXBMI.ge(30)).astype(int)
h=d.BMXHT/100; w=d.BMXWAIST/100
d['BMI']=d.BMXBMI; d['WHtR']=w/h; d['ABSI']=w/(d.BMI**(2/3)*h**.5); d['BRI']=364.2-365.5*np.sqrt(1-(w/(2*np.pi))**2/(.5*h)**2)
logabs=np.log(d.loc[valid,'ABSI']); d['LBSIZ']=(np.log(d.ABSI)-logabs.mean())/logabs.std()
# Units are explicit and chosen for numerical stability, not known author units.
d['ABSI_001']=d.ABSI/.01; d['WHtR_01']=d.WHtR/.1
cols2=['age','sex','race','poverty','education']; cols3=cols2+['diabetes_self_report','hypertension_self_report','cholesterol_self_report','inactivity','sedentary','energy','protein']
common=valid & d[cols3].notna().all(axis=1) & d.weight_diet2.gt(0)
flow=[{'stage':'all','n':len(d)},{'stage':'age >=20','n':int((d.RIDAGEYR>=20).sum())},{'stage':'basic DXA and measurements','n':int(valid.sum())},{'stage':'model 3 complete candidate','n':int(common.sum())}]
pd.DataFrame(flow).to_csv(OUT/'selection.csv',index=False,encoding='utf-8-sig')
# Construct full survey design clusters from examined participants; zero domain contributions retained.
design=d.loc[d.weight_diet2.gt(0)&d.SDMVSTRA.notna()&d.SDMVPSU.notna(),['cycle','SDMVSTRA','SDMVPSU']].drop_duplicates().copy()
design['stratum']=design.cycle.astype(str)+'_'+design.SDMVSTRA.astype(int).astype(str); design['psu']=design.SDMVPSU.astype(int).astype(str)
stratum_counts=design.groupby('stratum').psu.nunique(); assert (stratum_counts>=2).all()
def matrix(x,index,model):
    names=[] if model==1 else cols2 if model==2 else cols3
    cat=[v for v in ['sex','race','education','diabetes_self_report','hypertension_self_report','cholesterol_self_report','inactivity','sedentary'] if v in names]
    X=pd.get_dummies(x[[index]+names],columns=cat,drop_first=True,dtype=float).astype(float)
    return sm.add_constant(X,has_constant='add')
def survey_fit(x,index,outcome,model):
    X=matrix(x,index,model); y=x[outcome].to_numpy(); weights=x.weight_diet2.to_numpy()/x.weight_diet2.mean()
    fit=sm.GLM(y,X,family=sm.families.Binomial(),freq_weights=weights).fit(maxiter=200)
    if not fit.converged: raise RuntimeError('not converged')
    p=np.asarray(fit.predict(X)); xx=X.to_numpy(); bread=np.linalg.inv(xx.T @ ((weights*p*(1-p))[:,None]*xx))
    scores=xx*(weights*(y-p))[:,None]; q=pd.DataFrame(scores,columns=X.columns)
    q['stratum']=x.cycle.astype(int).astype(str).to_numpy()+'_'+x.SDMVSTRA.astype(int).astype(str).to_numpy(); q['psu']=x.SDMVPSU.astype(int).astype(str).to_numpy()
    sums=q.groupby(['stratum','psu'],as_index=False)[list(X.columns)].sum(); psu=design[['stratum','psu']].merge(sums,on=['stratum','psu'],how='left').fillna(0)
    meat=np.zeros((X.shape[1],X.shape[1]))
    for _,g in psu.groupby('stratum'):
        a=g[X.columns].to_numpy(); a=a-a.mean(axis=0); meat+=len(a)/(len(a)-1)*a.T@a
    v=bread@meat@bread; k=X.columns.get_loc(index); se=np.sqrt(v[k,k]); df=int(len(design)-design.stratum.nunique()-X.shape[1]+1)
    if df<=0: raise ValueError('nonpositive design df')
    coef=fit.params[index]; crit=t.ppf(.975,df); pv=2*t.sf(abs(coef/se),df)
    return np.exp(coef),np.exp(coef-crit*se),np.exp(coef+crit*se),pv,df
x=d.loc[common].copy(); print('flow',flow,flush=True)
results=[]
for outcome in ['SA','SO']:
 for index,unit in [('ABSI_001','0.01'),('BRI','1'),('BMI','1 kg/m2'),('WHtR_01','0.1'),('LBSIZ','1 SD')]:
  for model in [1,2,3]:
   try:
    or_,lo,hi,p,df=survey_fit(x,index,outcome,model)
    results.append(dict(outcome=outcome,index=index,increment=unit,model=model,n=len(x),events=int(x[outcome].sum()),OR=or_,CI_low=lo,CI_high=hi,p=p,design_df=df,status='ok'))
   except Exception as e: results.append(dict(outcome=outcome,index=index,increment=unit,model=model,status=str(e)))
pd.DataFrame(results).to_csv(OUT/'survey_or.csv',index=False,encoding='utf-8-sig')
roc=[]
for outcome in ['SA','SO']:
 train,test=train_test_split(np.arange(len(x)),test_size=.2,random_state=42,stratify=x[outcome]); a=x.iloc[train]; b=x.iloc[test]
 for index in ['ABSI','LBSIZ','BRI','BMI','WHtR']:
  fpr,tpr,thr=roc_curve(a[outcome],a[index],sample_weight=a.weight_diet2,drop_intermediate=False); k=np.argmax(tpr-fpr); cutoff=thr[k]; pred=b[index]>=cutoff
  se=np.average(pred[b[outcome].eq(1)],weights=b.loc[b[outcome].eq(1),'weight_diet2']); sp=np.average(~pred[b[outcome].eq(0)],weights=b.loc[b[outcome].eq(0),'weight_diet2'])
  auc=roc_auc_score(a[outcome],a[index],sample_weight=a.weight_diet2); testauc=roc_auc_score(b[outcome],b[index],sample_weight=b.weight_diet2)
  roc.append(dict(outcome=outcome,index=index,train_n=len(a),test_n=len(b),train_auc=auc,cutoff=cutoff,train_youden=tpr[k]-fpr[k],train_sensitivity=tpr[k],train_specificity=1-fpr[k],test_auc=testauc,test_sensitivity=se,test_specificity=sp))
  plt.plot(fpr,tpr,label=f'{index} {auc:.3f}')
 plt.plot([0,1],[0,1],'k--'); plt.xlabel('1 - specificity'); plt.ylabel('sensitivity'); plt.title(f'{outcome}: direct index, weighted, training'); plt.legend(); plt.tight_layout(); plt.savefig(OUT/f'ROC_{outcome}.png',dpi=150); plt.close()
pd.DataFrame(roc).to_csv(OUT/'roc_direct.csv',index=False,encoding='utf-8-sig')
pd.DataFrame(hashes).to_csv(OUT/'input_sha256.csv',index=False,encoding='utf-8-sig')
(OUT/'environment.json').write_text(json.dumps({'python':sys.version,'platform':platform.platform(),'seed':42,'design':'WTDR2D/4; Taylor strata PSU; all dietary clusters in design; t df clusters-strata-parameters+1','scope':'candidate, full model complete cases, not exact authors methods'},indent=2),encoding='utf-8')
print('events',x.SA.sum(),x.SO.sum()); print(pd.DataFrame(results).to_string(index=False)); print(pd.DataFrame(roc).to_string(index=False))
