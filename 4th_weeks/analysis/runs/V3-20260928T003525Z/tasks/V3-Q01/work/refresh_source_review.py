from pathlib import Path
import hashlib,json,re
root=Path.cwd();p=root/'4주차/염증과 노쇠 - 분석 길잡이/13-sources 근거와 용어 찾아보기.md';s=p.read_text(encoding='utf-8-sig');q=root/'analysis/tasks/V3-Q01/rev-1/work/document_review.json';r=json.loads(q.read_text(encoding='utf-8'))
for item in r['reviewed_versions']:
 if item['path'].endswith(p.name):item['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
a=p.parent/'assets/V3-20260928T003525Z/source_audit.md';origin=root/'analysis/tasks/V3-P01/rev-1/work/source_audit.md';assert a.exists() and a.read_bytes()==origin.read_bytes()
r['source_addendum_review']={'status':'accept','scope':'Final13sources officialPFQ1999,DRDDRSTS1999,DR2TOT2003URLs andsourceauditlink inspected; noresult/methodchange.','asset':str(a.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(a.read_bytes()).hexdigest(),'matches_source':True}
q.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print('Final13sourceshash andsourceasset verified; accept retained')
