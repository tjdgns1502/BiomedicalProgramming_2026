import pandas as pd
from pathlib import Path
p=Path('analysis/runs/candidate_20261108_v2')
r=pd.read_csv(p/'survey_or.csv')
paper={'SA':{'ABSI_001':[3.17,2.34,2.34],'BRI':[1.57,1.66,1.67],'BMI':[1.13,1.15,1.15],'WHtR_01':[3.30,3.85,3.93],'LBSIZ':[1.04,1.03,1.03]},'SO':{'ABSI_001':[2.48,1.79,1.78],'BRI':[1.76,1.89,1.91],'BMI':[1.18,1.21,1.21],'WHtR_01':[4.67,5.73,5.89],'LBSIZ':[1.03,1.02,1.02]}}
r['paper_OR']=[paper[a][b][c-1] for a,b,c in zip(r.outcome,r['index'],r.model)]
r['difference_exploratory']=r.OR-r.paper_OR
r['comparability']='not equivalent: sample, unit, coding and weight uncertain'
r.to_csv(p/'table3_comparison.csv',index=False,encoding='utf-8-sig')
t=pd.read_csv(p/'roc_direct.csv')
auc={'SA':{'ABSI':.759,'LBSIZ':.758,'BRI':.867,'BMI':.835,'WHtR':.862},'SO':{'ABSI':.742,'LBSIZ':.741,'BRI':.855,'BMI':.825,'WHtR':.857}}
t['paper_auc']=[auc[a][b] for a,b in zip(t.outcome,t['index'])];t['difference_exploratory']=t.train_auc-t.paper_auc;t['comparability']='not equivalent: direct score vs authors unspecified models'
t.to_csv(p/'table4_comparison.csv',index=False,encoding='utf-8-sig')
