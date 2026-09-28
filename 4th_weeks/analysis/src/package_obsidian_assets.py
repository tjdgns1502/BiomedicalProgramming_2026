"""Make appended evidence visible inside the existing Obsidian vault.
Copies referenced evidence/figures as snapshots; source analysis remains in analysis/.
Only the new appended note blocks are adjusted; original note bytes remain unchanged.
"""
from pathlib import Path
import json,re,shutil,hashlib
from project import ROOT,WORK,write,event,sha,stamp
auditpath=ROOT/'runs/D01-documents/append_audit.json'
audit=json.loads(auditpath.read_text(encoding='utf-8'));copied={};adjust=[]
for row in audit['files']:
    p=WORK/row['path']
    if 'frailty-learning' in str(p):continue
    b=p.read_bytes();prefix=b[:row['original_bytes']];tail=b[row['original_bytes']:].decode('utf-8')
    if hashlib.sha256(prefix).hexdigest()!=row['before_sha256']:raise RuntimeError('Original prefix drift')
    def rewrite(m):
        relative=m[1];source=ROOT/relative
        dest=p.parent/'assets/analysis-20260928'/relative
        if not source.is_file():raise RuntimeError('Missing source '+str(source))
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
        copied[str(dest.relative_to(WORK))]=dict(source=str(source.relative_to(WORK)),sha256=sha(source),bytes=source.stat().st_size)
        return '(assets/analysis-20260928/'+relative+')'
    changed=re.sub(r'\(../../analysis/([^\)]+)\)',rewrite,tail)
    changed+='\n> Obsidian의 그림·근거 링크는 보관함 내부의 이번 실행 스냅샷입니다. 실행 코드·자료의 기준 원본은 상위 작업 폴더의 `analysis/`이며, 새 분석을 실행하면 스냅샷도 검토 후 갱신해야 합니다.\n'
    new=prefix+changed.encode('utf-8');p.write_bytes(new)
    adjust.append(dict(path=row['path'],before_adjust_sha256=hashlib.sha256(b).hexdigest(),after_sha256=sha(p)))
    row['after_sha256']=sha(p);row['added_bytes']=len(new)-len(prefix)
audit['obsidian_adjustment']='Only appended block links changed to internal evidence snapshots; original byte prefixes still preserved.'
write(auditpath,audit)
write(ROOT/'runs/D01-documents/obsidian_asset_manifest.json',dict(created_at=stamp(),files=copied,adjusted_notes=adjust))
event('OBSIDIAN_ASSETS','D01','Referenced figures and evidence copied inside existing vault for local note rendering; analysis source remains authoritative',count=len(copied))
print(f'Copied {len(copied)} referenced artifacts; adjusted {len(adjust)} appended note blocks.')
