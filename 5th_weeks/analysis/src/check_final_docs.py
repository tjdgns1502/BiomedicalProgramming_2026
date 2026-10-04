from pathlib import Path
import re,json,sys,hashlib,urllib.parse,datetime,csv
r=Path(sys.argv[1]);a=r/'analysis';n=r/'치주질환과 고혈압 - 분석 길잡이'
mds=list(n.glob('*.md'))+[r/'README.md',a/'README.md',r/'실행 설계/05-prompts-week5.md']
stems={p.stem:p for p in r.rglob('*.md') if 'r-library' not in p.parts and '.uv-cache' not in p.parts}
issues=[];links=0;images=0
for p in mds:
 text=p.read_text(encoding='utf-8-sig')
 text=re.sub(r'```[\s\S]*?```','',text)
 for target in re.findall(r'!?\[\[([^\]]+)\]\]',text):
  target=target.split('|')[0].split('#')[0];links+=1
  exists=(p.parent/target).exists() or target in stems or (p.parent/(target+'.md')).exists()
  if not exists:issues.append({'file':str(p),'missing_wikilink':target})
 for target in re.findall(r'(?<!!)\[[^\]]+\]\(([^\n]+?)\)',text):
  target=target.strip('<>').split('#')[0]
  if target.startswith(('https:','http:','app:','codex:','mailto:')):continue
  links+=1
  target=urllib.parse.unquote(target)
  if not (p.parent/target).exists():issues.append({'file':str(p),'missing_markdown_link':target})
 if p.name[2:8]=='-paper':
  for heading in ('## 구현','## 재현 비교','## 검토·추가 분석','## 갱신된 해석'):
   if heading not in text:issues.append({'file':str(p),'missing_heading':heading})
  if '계획 검토 후 실행 대기.' in text or '아직 결과 없음.' in text:issues.append({'file':str(p),'stale_placeholder':True})
assets=json.loads((n/'assets/manifest.json').read_text(encoding='utf-8'))
for rec in assets:
 p=Path(rec['copy']);actual=hashlib.sha256(p.read_bytes()).hexdigest();images+=1
 if actual!=rec['sha256']:issues.append({'asset':str(p),'hash_mismatch':True})
cov=json.loads((a/'memory/output_coverage.json').read_text(encoding='utf-8'))
for x in cov:
 if x.get('required') and (x.get('implementation')=='pending' or x.get('continues_possible_required')):issues.append({'coverage_pending':x})
for run in ('R2-20261004','E1-20261004','E2-20261004'):
 if json.loads((a/'runs'/run/'status.json').read_text(encoding='utf-8'))['status']!='success':issues.append({'failed_current_run':run})
for file in ('result.json','manifest.json','typeI_error.csv','power.csv','course_examples.csv','published_OR_PR.csv'):
 if not (a/'runs/V1-20261004'/file).exists():issues.append({'missing_validation_output':file})
json.loads((a/'runs/V1-20261004/result.json').read_text(encoding='utf-8'))
reviews=[]
for name in ('R2-20261004-q-review.json','R2-data-review.json','E1-20261004-q-review.json','E1-data-review.json','E2-20261004-q-review.json','E2-20261004-data-review.json','V1-20261004-q-review.json'):
 p=a/'reviews'/name
 if not p.exists():issues.append({'missing_review':name});continue
 d=json.loads(p.read_text(encoding='utf-8-sig'));decision=d.get('decision',d.get('status',d.get('verdict')))
 if isinstance(decision,dict):decision=decision.get('value',decision.get('status'))
 reviews.append({'name':name,'decision':decision,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 if not str(decision).lower().startswith('accept'):issues.append({'review_not_accepted':name,'decision':decision})
comp=list(csv.DictReader((a/'comparisons/E2-20261004/all_published_OR_comparisons.csv').open(encoding='utf-8-sig')))
if len(comp)!=84:issues.append({'OR_comparison_count':len(comp)})
out={'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checked_documents':len(mds),'links':links,'asset_hashes':images,'OR_comparison_rows':len(comp),'reviews':reviews,'issues':issues}
(a/'reviews/final-document-check.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(out,ensure_ascii=False))
if issues:sys.exit(1)
