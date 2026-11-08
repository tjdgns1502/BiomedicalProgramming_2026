"""Download public NHANES files; verify exact checksums before moving into raw/."""
from pathlib import Path
import hashlib, json, tempfile, urllib.request
ROOT=Path(__file__).resolve().parents[2]
raw=ROOT/'analysis/data/raw'; raw.mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/'analysis/data/nhanes_sources.json').read_text(encoding='utf8'))
for item in manifest:
    path=raw/item['file']
    if path.exists():
        if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
            raise RuntimeError(f'Existing file hash mismatch: {path}; preserved unchanged')
        print(f'Verified {path.name}',flush=True); continue
    with urllib.request.urlopen(item['url'],timeout=90) as response, tempfile.NamedTemporaryFile(dir=raw,delete=False) as tmp:
        tmp_path=Path(tmp.name)
        try:
            digest=hashlib.sha256()
            while chunk:=response.read(1024*1024):
                digest.update(chunk); tmp.write(chunk)
        except BaseException:
            tmp.close(); tmp_path.unlink(missing_ok=True); raise
    if digest.hexdigest()!=item['sha256']:
        tmp_path.unlink(missing_ok=True); raise RuntimeError(f'Download hash mismatch: {item["file"]}')
    tmp_path.replace(path); print(f'Downloaded and verified {path.name}',flush=True)
