from pathlib import Path
import json,csv,re,sys,hashlib,datetime
root=Path(sys.argv[1]).resolve();run=root/'analysis/runs'/sys.argv[2]
with (run/'tables/device_summary.csv').open(encoding='utf-8-sig',newline='') as f:summary=list(csv.DictReader(f))
table=json.loads((root/'sources/published_tables.json').read_text(encoding='utf-8'))[0]
assert table['id']=='pone.0154420.t001'
rr=table['rows']; devices=[x['device'] for x in summary]
numbers=lambda v:[float(x) for x in re.findall(r'[-+]?\d+(?:\.\d+)?',v.replace('−','-'))]
comparisons=[]
rowmap=[(1,'n',0),(2,'mean_device',.05),(3,'mean_reference',.05),(6,'bias',.05)]
for j,z in enumerate(summary):
 for row,key,tol in rowmap:
  pub=numbers(rr[row][j+2])[0];calc=float(z[key]);comparisons.append({'device':z['device'],'metric':key,'published':pub,'calculated':calc,'delta':calc-pub,'tolerance':tol,'within_rounding':abs(calc-pub)<=tol+1e-12,'method':'same statistic'})
 for row,key in [(2,'sd_device'),(3,'sd_reference'),(6,'error_sd')]:
  pub=numbers(rr[row][j+2])[1];calc=float(z[key]);comparisons.append({'device':z['device'],'metric':key,'published':pub,'calculated':calc,'delta':calc-pub,'tolerance':.05,'within_rounding':abs(calc-pub)<=.05+1e-12,'method':'sample SD n-1'})
 source=rr[4][j+2];method='Spearman' if '*' in source else 'Pearson';key='spearman_rho' if method=='Spearman' else 'pearson_r';pub=numbers(source)[0];calc=float(z[key]);comparisons.append({'device':z['device'],'metric':'paper_method_correlation','published':pub,'calculated':calc,'delta':calc-pub,'tolerance':.005,'within_rounding':abs(calc-pub)<=.005+1e-12,'method':method})
for j,z in enumerate(summary[:3]):
 for row,key in [(7,'classical_loa_high'),(8,'classical_loa_low')]:
  pub=numbers(rr[row][j+2])[0];calc=float(z[key]);comparisons.append({'device':z['device'],'metric':key,'published':pub,'calculated':calc,'delta':calc-pub,'tolerance':.05,'within_rounding':abs(calc-pub)<=.05+1e-12,'method':'direct unrounded sample bias +/-1.96 sample SD; paper intermediate rounding unknown'})
with (run/'tables/publication_comparison.csv').open('w',encoding='utf-8-sig',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=list(comparisons[0]));writer.writeheader();writer.writerows(comparisons)
rounding_diagnostic=[]
for j,z in enumerate(summary[:3]):
 pub_bias=numbers(rr[6][j+2])[0];pub_sd=numbers(rr[6][j+2])[1]
 for sign,row in [(1,7),(-1,8)]:
  pub=numbers(rr[row][j+2])[0];derived=pub_bias+sign*1.96*pub_sd
  rounding_diagnostic.append({'device':z['device'],'bound':'upper' if sign==1 else 'lower','reported_bias':pub_bias,'reported_SD':pub_sd,'reported_LoA':pub,'LoA_using_rounded_reported_inputs':derived,'difference':derived-pub,'interpretation':'Compatibility diagnostic only; author calculation procedure not established; primary outputs unchanged'})
with (run/'tables/reported_rounding_diagnostic.csv').open('w',encoding='utf-8-sig',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=list(rounding_diagnostic[0]));writer.writeheader();writer.writerows(rounding_diagnostic)
issues_path=root/'analysis/memory/issues.json';issues=json.loads(issues_path.read_text(encoding='utf-8'))
new=[
 {'id':'D05','type':'metadata precision','question':'Key labels HR values Integer although spreadsheet contains decimals.','finding':'Observed HR values have decimals.','action':'Retain numeric decimals; no integer coercion or rounding before statistics.','status':'controlled'},
 {'id':'C01','type':'publication-method mismatch','question':'Why is Samsung primary Pearson about0.743 while paper reports0.67?','finding':'Table1 footnote * marks Samsung HR as Spearman. Observed Spearman is0.6702428.','action':'Keep Pearson as assignment primary for all watches; compare paper using its stated statistic.','status':'resolved without tuning'},
 {'id':'C02','type':'small reporting discrepancy','question':'Some raw-data bias/LoA differ slightly from printed1-decimal figures.','finding':'Samsung raw bias=-7.04818 vs table-7.1; several directly computed LoA differ. Substituting printed rounded bias/SD yields all six constant published bounds within0.05.','action':'Report raw results and differences; show rounded-input compatibility diagnostic separately; do not claim author method identified or alter raw values.','status':'partial; original precision/rounding procedure unknown'},
 {'id':'C03','type':'non-comparable agreement specification','question':'Can Mio reported regression-varying LoA be reproduced by constants?','finding':'Paper upper=-0.44*average+52.69; lower=0.4*average-61.2.','action':'Do not compare fixed descriptive LoA as exact reproduction; preserve equations in comparison notes.','status':'not directly comparable; limitation retained'}]
known={x['id'] for x in issues};issues.extend(x for x in new if x['id'] not in known)
issues_path.write_text(json.dumps(issues,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
meta={'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':'sources/paper.manuscript.xml','source_sha256':hashlib.sha256((root/'sources/paper.manuscript.xml').read_bytes()).hexdigest(),'scope':'HR Table1 count, means, SD, method-labelled r and constant LoA; not full ICC/EE/steps reproduction','comparisons':len(comparisons),'within_stated_rounding':sum(x['within_rounding'] for x in comparisons),'correlations_match':sum(x['within_rounding'] for x in comparisons if x['metric']=='paper_method_correlation'),'Mio_regression_LoA':'not directly comparable to fixed limits','raw_statistics_unchanged':True,'rounded_input_diagnostic':'post-result explanatory check; not primary analysis or proven author procedure'}
meta['tolerances_origin']='n,r,mean fixed in pre-analysis plan; SD/LoA0.05 applied after Table1 extraction using one-decimal reporting precision.'
(run/'publication_comparison_manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(meta,ensure_ascii=False))
print('OUTSIDE_TOLERANCE',json.dumps([x for x in comparisons if not x['within_rounding']],ensure_ascii=False))
