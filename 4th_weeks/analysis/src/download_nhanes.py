# /// script
# requires-python = ">=3.11"
# ///
"""Download validated, immutable NHANES raw files and codebooks from CDC.
Run: uv run analysis/src/download_nhanes.py [--years 2015 2013 ...]
All URLs are discovered from official per-cycle data listings; never guessed.
"""
from pathlib import Path
import argparse, concurrent.futures, datetime, hashlib, html, json, re, urllib.request
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'data'/'raw'
RUN=ROOT/'runs'/'S02-nhanes-data'
PREFIXES={'DEMO','CBC','PFQ','MCQ','HUQ','HSQ','KIQ','KIQ_U','BPQ','DIQ','RXQ_RX','BPX','BMX','BIOPRO','SMQ','ALQ','PAQ','DRXTOT','DR1TOT','DR2TOT'}

def fetch(url,path,kind):
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    info=dict(url=url,path=str(path.relative_to(ROOT)),checked_at_utc=now,kind=kind)
    try:
        if path.exists():
            b=path.read_bytes(); info['status']='cache_validated'
        else:
            with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'NHANES academic reproducibility study'}),timeout=120) as resp:
                b=resp.read(); info.update(http_status=resp.status,content_type=resp.headers.get('Content-Type'),final_url=resp.url)
            info['status']='downloaded'
        valid=(b.startswith(b'HEADER RECORD*******LIBRARY HEADER RECORD') if kind=='xpt' else b'<html' in b[:2000].lower() or b'<!doctype html' in b[:2000].lower())
        if not valid: raise ValueError('Invalid content signature; file not saved')
        info.update(valid=True,bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
        if not path.exists():
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open('xb') as f:f.write(b)
    except Exception as e: info.update(status='error',valid=False,error=str(e))
    return info

def cycle(year):
    label=f'{year}-{year+1}'
    url=f'https://wwwn.cdc.gov/nchs/nhanes/search/DataPage.aspx?Cycle={label}'
    path=RAW/label/'listing.html'; rec=fetch(url,path,'html')
    if not rec['valid']: return [rec],[]
    rows=[]; jobs=[]
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>',path.read_text(encoding='utf-8-sig'),re.S):
        links=re.findall(r'href="([^"]+)"',row)
        xpt=next((x for x in links if x.lower().endswith('.xpt')),None)
        if not xpt: continue
        stem=xpt.rsplit('/',1)[-1].split('.')[0]
        prefix=re.sub(r'_[B-I]$','',stem)
        desc=html.unescape(re.sub('<[^>]+>',' ',row)); desc=' '.join(desc.split())
        keep=prefix in PREFIXES or re.search('Complete Blood Count|Standard Biochemistry Profile',desc)
        if not keep: continue
        for link in links:
            if not link.lower().endswith(('.xpt','.htm')): continue
            full='https://wwwn.cdc.gov'+link if link.startswith('/') else link
            filename=link.rsplit('/',1)[-1]
            jobs.append((full,RAW/label/filename,'xpt' if filename.lower().endswith('.xpt') else 'html'))
        rows.append(dict(cycle=label,file=stem,description=desc,xpt_url='https://wwwn.cdc.gov'+xpt))
    records=[rec]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for result in pool.map(lambda a:fetch(*a),jobs):
            records.append(result)
    print(label,len(rows),'modules',sum(x['valid'] for x in records),'valid files',flush=True)
    return records,rows

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--years',nargs='+',type=int,default=[2015,1999,2001,2003,2005,2007,2009,2011,2013]);args=parser.parse_args()
    RUN.mkdir(parents=True,exist_ok=True)
    records=[];modules=[]
    for year in args.years:
        rec,mods=cycle(year);records+=rec;modules+=mods
        # Append-only request log; an immutable raw file is never overwritten.
        with (RUN/'download_manifest.jsonl').open('a',encoding='utf8') as f:
            for item in rec:f.write(json.dumps(item,ensure_ascii=False)+'\n')
        (RUN/'module_inventory.json').write_text(json.dumps(modules,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(dict(files=len(records),failed=[r for r in records if not r['valid']]),ensure_ascii=False),flush=True)
if __name__=='__main__':main()
