from pathlib import Path
import csv,json
root=Path.cwd(); out=Path(__file__).parent
groups={
'education':['DMDEDUC2'], 'poverty':['INDFMPIR'], 'BMI':['BMXBMI'],
'smoking':['SMQ020'], 'drinking':['ALQ100','ALQ101','ALQ110','ALQ120Q','ALQ120U','ALQ130'],
'activity':['PAD200','PAD320','PAQ650','PAQ665','PAQ605','PAQ620','PAQ635'],
'energy':['DRXTKCAL','DR1TKCAL','DR2TKCAL','DRDDRSTZ','DR1DRSTZ','DR2DRSTZ'],
'diabetes':['DIQ010','DIQ050','DIQ070'], 'hypertension':['BPQ020','BPQ050A','BPXSY1','BPXDI1'],
'subgroups':['RIDAGEYR','RIAGENDR','RIDRETH1','DMDEDUC2','INDFMPIR','BMXBMI','SMQ020'],
'FI':['candidate36_observed_items','FI_candidate36','FI_candidate36_alt','deficit_29'],
'survey':['SEQN','SDMVPSU','SDMVSTRA','weight_mec_18yr']}
headers={}
for name in ['candidate_complete36.csv','candidate_all_age50.csv','nhanes_design_all.csv']:
 with (root/'analysis/data/derived'/name).open(encoding='utf-8-sig',newline='') as f:headers[name]=next(csv.reader(f))
raw={p.parent.name:[] for p in (root/'analysis/data/raw').glob('*/*.xpt')}
for p in sorted((root/'analysis/data/raw').glob('*/*.xpt')):raw[p.parent.name].append(p.name)
inventory={'scope':'Schema and existing raw-file inventory only; no models or effect outputs read','derived':{n:{'column_count':len(h),'groups':{g:{v:v in h for v in vs} for g,vs in groups.items()}} for n,h in headers.items()},'raw_files_by_cycle':raw}
(out/'data_availability_inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
wanted=set(sum(groups.values(),[]))
with (root/'analysis/runs/S02-nhanes-data/variable_schema.csv').open(encoding='utf-8-sig',newline='') as f:
 reader=csv.DictReader(f); rows=[r for r in reader if r['variable'] in wanted]
with (out/'covariate_schema_by_cycle.csv').open('w',encoding='utf-8',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=['cycle','file','variable','label','n','n_nonmissing','url']);writer.writeheader();writer.writerows(rows)
print('Inventory complete:',len(rows),'source schema rows;',len(raw),'cycles; no fitting')
