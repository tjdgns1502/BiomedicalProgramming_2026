from pathlib import Path
import re,hashlib,json
root=Path.cwd();notes=root/'4주차/염증과 노쇠 - 분석 길잡이';selected=[]
for p in notes.glob('*.md'):
 if p.name.startswith('00-start') or any(p.name.startswith(x+'-paper') for x in ['03','04','05','07','08','09','10']) or any(p.name.startswith(x+'-concept') for x in ['03','08','10']):selected.append(p)
links=[];copies=[]
for p in selected:
 s=p.read_text(encoding='utf-8-sig')
 for target in re.findall(r'\]\((assets/V3-[^)]+)\)',s):
  dest=notes/target;links.append({'source':p.name,'target':target,'exists':dest.exists()})
  if dest.exists():
   src=root/'analysis/tasks/V3-I01/rev-1/work'/dest.name
   if not src.exists():src=root/'analysis/tasks/V3-Q01/rev-1/work'/dest.name
   if src.exists():copies.append({'name':dest.name,'identical':hashlib.sha256(src.read_bytes()).digest()==hashlib.sha256(dest.read_bytes()).digest()})
assert all(x['exists'] for x in links);assert all(x['identical'] for x in copies)
q=root/'analysis/tasks/V3-Q01/rev-1/work'
(q/'document_link_checks.json').write_text(json.dumps({'status':'PASS','selected_notes':len(selected),'v3_asset_links':len(links),'source_copy_checks':len(copies),'links':links,'copies':copies},ensure_ascii=False,indent=2),encoding='utf-8')
print(len(selected),len(links),len(copies),'PASS')
