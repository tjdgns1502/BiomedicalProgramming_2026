from pathlib import Path
import json, hashlib, re

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
def write(name,obj):
    (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tables=json.loads((OUT/'supplement_tables.json').read_text(encoding='utf-8'))
items=[]
for row in tables[0]['rows']:
    for ci,cell in enumerate(row['cells'],1):
        m=re.match(r'^(\d+)\. (.*)',cell.strip())
        if m:
            n=int(m.group(1))
            items.append({'number':n,'source_label':m.group(2),'source_location':f'supplement.docx, Supplemental Table S1, XML table 1 row {row["row"]} cell {ci}',
              'domain':'self_report' if n<=25 else 'laboratory_or_examination',
              'label_status':'explicit','raw_variable_name':None,'raw_variable_status':'not_reported',
              'exact_deficit_coding_status':'not_reported',
              'interpretation':('Yes/no disease or difficulty is a plausible binary deficit interpretation, but NHANES response-code mapping is not supplied.' if n<=20 else 'Threshold separating a deficit from no deficit is not supplied.' if n<=25 else 'Parenthesized range is supplied; treating outside range as a deficit is an interpretation, not an explicit direction-of-coding statement.')})
items.sort(key=lambda x:x['number'])
assert [x['number'] for x in items]==list(range(1,37))
claims=[
 ('population','explicit','NHANES 1999–2016; cross-sectional; age >=50 years.','PDF p2 Study population; p3 Results'),
 ('sample_flow','explicit',{'initial':92062,'age_under_50_excluded':70392,'cbc_insufficient_excluded':2508,'fi_insufficient_excluded':5503,'covariate_missing_excluded':152,'included':13507,'fit_n':9778,'frail_n':3729},'PDF p3 Results; p4 Fig1; p5 Table1'),
 ('cbc_formulas','explicit',{'NLR':'neutrophil_count / lymphocyte_count','MLR':'monocyte_count / lymphocyte_count','SIRI':'neutrophil_count * monocyte_count / lymphocyte_count','SII':'platelet_count * neutrophil_count / lymphocyte_count'},'PDF p2 Assessment of CBC-derived inflammatory biomarkers'),
 ('cbc_units','explicit','Cell counts reported in 10^3/uL; SIRI and SII in 10^3/uL; NLR/MLR are ratios.','PDF p5 Table1'),
 ('fi_items','explicit','Modified Rockwood FI: 36 items after omitting 10 intake/nutrition-related items from original 46.','PDF p2 Frailty assessment; supplemental S1'),
 ('fi_generic_score','explicit','Criterion met is scored 1, otherwise 0; points added. The denominator formula is not explicitly printed.','PDF p2 Frailty assessment'),
 ('fi_denominator','not_reported','Using sum of 36 binary items /36 is a reasonable complete-data FI implementation but is not an explicit denominator formula in these sources. No available-item denominator, minimum completed count, or partial-missing allowance specified.','PDF p2 Frailty assessment; supplemental S1'),
 ('frailty_cutoff','explicit',{'fit':'FI <= 0.3','frail':'FI > 0.3'},'PDF p2 Frailty assessment'),
 ('model_direction','explicit','Logistic regression uses binary frailty as outcome and each CBC-derived inflammatory marker as predictor. This is a cross-sectional association, despite the words incident/risk in table titles.','PDF pp2–3 methods; p6 Tables2–3'),
 ('log_transform','explicit','All four markers were logarithmically transformed because of nonnormality.','PDF p3 Statistical analysis; p6 Table2 footnote'),
 ('log_base','not_reported','Base of logarithm, zero handling and transformation implementation are not specified.','PDF p3 Statistical analysis; p6 Table2 footnote'),
 ('model1','explicit',['age (continuous)','sex (male/female)','NHANES cycle','race (Mexican American / Other Hispanic / Non-Hispanic White / Non-Hispanic Black / Other)'],'PDF p6 Table2 footnote; p3 Statistical analysis'),
 ('model2','explicit',['all model1 covariates','education (below high school / high school / above high school)','family PIR (<=1.0 / 1.1–3.0 / >3.0)','drinking status','smoking status','BMI (<25.0 /25.0–29.9 />29.9)','physical activity (never / moderate / active)','total energy intake','self-reported diabetes','self-reported hypertension'],'PDF p6 Table2 footnote'),
 ('covariate_definitions','explicit',{'smoking':'at least 100 cigarettes in lifetime','drinking':'at least 12 drinks in previous year; non-drinker wording also refers to lifetime','energy':'mean of 2 days','physical_activity':'3 categories; no rule supplied','hypertension_diabetes':'self-reported questionnaires'},'PDF p3 Covariate assessment'),
 ('covariate_boundaries','ambiguous','BMI p3 gives <=25 healthy and >=25 overweight (overlap at 25); Table1/Table2 specify <25. PIR labels leave (1.0,1.1) unresolved if raw PIR is more precise than one decimal. Physical-activity cutoffs, drinking harmonization, and categorical reference levels are not specified.','PDF p3 Covariate assessment; p5 Table1; p6 Table2 footnote'),
 ('missing_covariates','ambiguous','Results says 152 omitted for missing covariates, yet Table1 and S2–S5 show 627 missing drinking values. Model-specific missing handling / missing category / imputation not described. Table1 smoking counts also sum to 13495 whereas supplement sums to 13507.','PDF p3 Results; p5 Table1; supplement S2–S5'),
 ('survey_evidence','ambiguous','Table1 and S2–S5 titles say by sampling weight. Table1 footnote c says complex-survey Wilcoxon and Rao–Scott correction. Table1 and S5 footnote b say survey unweighted; S2–S4 say survey weighted. Weight variable, combined-cycle weights, design variables, lonely-PSU treatment and regression-weight specification absent.','PDF p5 Table1 title/footnotes; supplement S2–S5 captions/footnotes'),
 ('fraction_vs_percent','explicit','3729/13507 is approximately 27.61%; reported frail percentage is 24%. These are distinct reported quantities; survey weighting may explain difference, but sources conflict on percentages.','PDF p1 Abstract; p5 Table1'),
 ('quartile_method','not_reported','Markers, not FI, are divided into quartiles. Weighted vs unweighted quantile algorithm, R quantile type, tie handling and unrounded thresholds not specified.','PDF p3 Statistical analysis; p6 Table3; supplement S2–S5'),
 ('quartile_errors','ambiguous','Body gives NLR Q1 as 1.53 without inequality; SIRI Q1 <0.76 and Q3 >0.76; SII Q1 <339.58. Supplement headers resolve to <= lower cutoff, and SIRI Q3 >1.13. Prefer reporting both source statements; any implementation using supplement must be declared.','PDF p3 Statistical analysis; supplemental S2–S5 header rows'),
 ('trend_method','not_reported','p-trend reported but coding of ordinal predictor / quartile medians / test implementation not given.','PDF p6 Table3'),
 ('rcs','explicit','Restricted cubic splines compared with linear model to assess nonlinearity; p<0.05; knot count/locations and reference point not specified.','PDF p3 Statistical analysis; p7 Fig2'),
 ('software_alpha','explicit','R 4.3; two-tailed p<0.05.','PDF p3 Statistical analysis'),
 ('component_overlap','inference','Platelet count is both an SII input and FI item29; hypertension and diabetes are both FI items8/9 and model2 covariates. This overlap should be disclosed when interpreting associations.','PDF p2 formulas; p6 Table2 footnote; supplemental S1'),
 ('course_scope','task_requirement','FI quartiles -> compare NLR, MLR, SIRI, SII by ANOVA/Welch/Kruskal–Wallis/trend and Tukey/Bonferroni/BH; boxplots, four residual plots, null p histogram, 1-.95^k Monte Carlo, expand.grid and Map. These are classroom extensions and are not claimed to reproduce paper analyses.','Parent task instructions; not a claim sourced to the paper'),
]
sources=[]
for name in ['s12889-024-20908-9.pdf','supplement.docx','paper_extracted.txt']:
    p=ROOT/name
    sources.append({'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'role':'primary_source' if name!='paper_extracted.txt' else 'secondary_text_extraction_cross_checked_against_pdf'})
ev={'schema_version':'1.0','scope':'Source evidence and implementation handoff only; no empirical findings generated.','sources':sources,'verification':{'pdf_pages':11,'docx_tables':7,'pdf_visual_pages_checked':[3,5,6],'fi_items_verified':36,'table1_unweighted_footnote_confirmed_visually':True,'paper_extracted_text_role':'Used for discovery and cross-checked against independently extracted PDF pages and visual page renders; no automated equality asserted.'},'claims':[{'id':a,'status':b,'value':c,'location':d} for a,b,c,d in claims],'fi_items':items,'fi_reconstruction':{'status':'not_fully_identified_from_supplied_sources','usable_now':['CBC formulas','36 item identities','11 laboratory/examination range labels','binary FI cutoff','model covariate lists'],'must_resolve_before_paper_equivalence':['cycle-specific raw variable and response mappings','exact self-report deficit thresholds especially items21–25','measurement aggregation and units','lab deficit direction and endpoint handling','complete-item denominator and partial-missing policy','survey design specification','log base','model-specific missing data handling'],'prohibited_shortcuts':['Treat unanswered/unknown/refused as zero','Substitute Fried phenotype for Rockwood FI','Drop unavailable FI items without explicit renamed modified outcome','Choose coding/log base/weights to match published N/OR/p-values','Use rounded published marker cutoffs as FI quartiles']}}
ev['reference_followup'] = {
 'scope':'Bounded follow-up requested by root; cited original research checked for missing coding. These sources do not prove Han2024 used all their implementation choices.',
 'references':[
  {'han_reference':23,'url':'https://link.springer.com/article/10.1186/s12916-021-01918-5','supplement_url':'https://media.springernature.com/original/springer-static/esm/art%3A10.1186%2Fs12916-021-01918-5/MediaObjects/12916_2021_1918_MOESM1_ESM.docx','local_file':'reference23_supplement.docx','finding':'S2 repeats the same 36 labels/ranges without self-report scoring thresholds. Main Frailty index section explicitly divides deficit count by total possible deficits. This supports the general denominator concept, not Han partial-missing policy.'},
  {'han_reference':22,'url':'https://link.springer.com/article/10.1007/s11357-017-9993-7','supplement_url':'https://media.springernature.com/original/springer-static/esm/art%3A10.1007%2Fs11357-017-9993-7/MediaObjects/11357_2017_9993_MOESM1_ESM.docx','local_file':'reference22_supplement.docx','finding':'Frailty index construction section: outside normal range=1, otherwise0; calculate FI only when <20% variables missing. However self-report36/lab32/combined68 indices differ from Han36. Supplemental Table1 contains labels/ranges, no detailed self-report thresholds. Lab examples differ: pulse pressure30–65, calcium2.3–2.74, bicarbonate21–28, ALP20–130.'},
  {'han_reference':21,'url':'https://www.cmaj.ca/content/189/33/E1056','supplement_url':'https://www.cmaj.ca/lookup/suppl/doi:10.1503/cmaj.161034/-/DC1','finding':'Search-indexed primary article describes a46-itemFI. Primary-page and supplement direct fetch failed; no coding from this uninspected supplement is claimed.'},
  {'han_reference':None,'relationship':'Jayanama2021 cited antecedent','url':'https://link.springer.com/article/10.1186/s12916-018-1176-6','finding':'Frailty index section supports36-item deficit-count/total-considered formula and identifies10 excluded nutrition items. Its >80% rule appears in Nutrition index section and must not be attributed to FI without additional evidence.'}
 ],
 'remaining_unknowns':['Han-specific binary self-report thresholds','HUQ healthcare-use cutoff','Medication count cutoff','Han-specific FI partial-missing denominator and minimum item count'],
 'course_plan_resolution':'Root froze analysis/config/analysis_plan.json before results: primary Welch; trend uses group FI medians with HC3; pairwise family has24 comparisons across4 markers. This overrides the initial optional1–4 score/6-pair suggestions in this handoff.'
}
for ref in ev['reference_followup']['references']:
    if ref.get('local_file'):
        ref['local_sha256']=hashlib.sha256((OUT/ref['local_file']).read_bytes()).hexdigest()
write('evidence.json',ev)
targets={'schema_version':'1.0','purpose':'Published descriptive reference values, not fitting/calibration objectives or pass/fail targets.','population':{'cycles':'1999–2016','age_min':50,'n':13507,'frail_n':3729,'frail_percent_reported':24,'raw_frail_fraction':3729/13507},'outcome':'FI >0.3','fi_quartile_cutoffs':None,'marker_quartiles':{},'table2_log_marker_or':{},'table3_q4_vs_q1_or':{},'known_printing_issues':['Table3 SIRI marker printed RISI','Table3 SIRI Q4 Event/N printed 12,313,377; 1231/3377 inferred from other counts, not an exact printed fraction','Table3 SII Q4 Event/N printed 11,813,377; 1181/3377 inferred from other counts','SIRI Q3 lower boundary conflicts body .76 vs supplement1.13','Weight-related footnotes conflict'],'log_base':None,'model1_source':'PDF p6 Table2 footnote','model2_source':'PDF p6 Table2 footnote'}
for idx,marker,cut in [(2,'NLR',[1.53,2.08,2.83]),(3,'MLR',[.22,.29,.38]),(4,'SIRI',[.76,1.13,1.68]),(5,'SII',[339.58,481.85,689.61])]:
    targets['marker_quartiles'][marker]={'cutoffs':cut,'closed':'right','outer_lower_bound':None,'source':f'supplement.docx S{idx}, row1','raw_headers':tables[idx-1]['rows'][0]['cells'][2:6],'rounded':True,'construction_algorithm':None}
for marker,m1,m2,q4 in [('NLR',[4.85,3.60,6.54],[3.45,2.52,4.73],[1.73,1.45,2.06]),('MLR',[3.46,2.41,4.95],[3.58,2.44,5.25],[1.61,1.36,1.91]),('SIRI',[4.09,3.24,5.17],[2.77,2.17,3.55],[1.72,1.43,2.06]),('SII',[2.39,1.84,3.11],[1.89,1.44,2.48],[1.31,1.09,1.57])]:
    targets['table2_log_marker_or'][marker]={'model1':dict(zip(['or','ci_lower','ci_upper'],m1)),'model2':dict(zip(['or','ci_lower','ci_upper'],m2)),'p_reported':'<0.001','source':'PDF p6 Table2'}
    targets['table3_q4_vs_q1_or'][marker]={'model2':dict(zip(['or','ci_lower','ci_upper'],q4)),'p_trend_reported':'<0.001','source':'PDF p6 Table3'}
write('paper_targets.json',targets)
assert 92062-70392-2508-5503-152==13507
print(f'Validated {len(items)} FI source labels, {len(claims)} evidence claims and published reference targets.')
