from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET
from pypdf import PdfReader

root = Path(__file__).resolve().parent
files = []
for path in root.joinpath('supplementary').glob('**/*.pdf'):
    data = path.read_bytes()
    reader = PdfReader(path)
    text = '\n\n'.join(f'PAGE {i + 1}\n{page.extract_text()}' for i, page in enumerate(reader.pages))
    out = root / f'{path.stem}.txt'
    out.write_text(text, encoding='utf-8')
    files.append({'file': str(path.relative_to(root)), 'bytes': len(data), 'md5': hashlib.md5(data).hexdigest(), 'sha256': hashlib.sha256(data).hexdigest(), 'pdf_magic': data[:5].decode('ascii'), 'pages': len(reader.pages), 'text': out.name})
    print(text)
    try:
        import fitz
        document = fitz.open(path)
        for i in range(len(document)):
            document[i].get_pixmap(matrix=fitz.Matrix(1.8, 1.8)).save(root / f'supplement-page-{i + 1}.png')
        print('RENDERED', len(document), 'pages')
    except ImportError:
        print('NO_FITZ')

xml = ET.parse(root / 'PMC10262359.fullText.xml')
for table in xml.findall('.//table-wrap'):
    label = ''.join(table.find('label').itertext())
    rows = []
    for row in table.findall('.//tr'):
        rows.append('\t'.join(''.join(cell.itertext()).strip() for cell in list(row)))
    out = root / (label.lower().replace(' ', '_') + '.tsv')
    out.write_text('\n'.join(rows), encoding='utf-8')
    foot = table.find('table-wrap-foot')
    foottext = ''.join(foot.itertext()) if foot is not None else ''
    print(label, foottext)
    files.append({'table': label, 'output': out.name, 'footnotes': foottext})
(root / 'source_inspection.json').write_text(json.dumps(files, ensure_ascii=False, indent=2), encoding='utf-8')
print('MANIFEST', json.dumps(files, ensure_ascii=False))
