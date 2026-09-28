from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as ET
import json, hashlib
import fitz

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
pdf = fitz.open(ROOT / 's12889-024-20908-9.pdf')
pages = [{'page': i+1, 'text': p.get_text()} for i,p in enumerate(pdf)]
(OUT/'pdf_pages.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2),encoding='utf-8')
for i in [1,2,4,5]:
    pdf[i].get_pixmap(matrix=fitz.Matrix(1.4,1.4)).save(OUT/f'paper_page_{i+1}.png')
ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile(ROOT/'supplement.docx') as z:
    root=ET.fromstring(z.read('word/document.xml'))
tables=[]
for ti,t in enumerate(root.findall('.//w:tbl',ns),1):
    rows=[]
    for ri,r in enumerate(t.findall('w:tr',ns),1):
        rows.append({'row':ri,'cells':['\n'.join(''.join(p.itertext()) for p in c.findall('w:p',ns)) for c in r.findall('w:tc',ns)]})
    tables.append({'table':ti,'rows':rows})
(OUT/'supplement_tables.json').write_text(json.dumps(tables,ensure_ascii=False,indent=2),encoding='utf-8')
paragraphs=[''.join(p.itertext()) for p in root.findall('.//w:p',ns)]
(OUT/'supplement_extracted.txt').write_text('\n'.join(paragraphs),encoding='utf-8')
print('PDF pages:',len(pages),'DOCX tables:',len(tables))
for t in tables:
    print('TABLE',t['table'],'ROWS',len(t['rows']))
    print(json.dumps(t['rows'][:2],ensure_ascii=False))
