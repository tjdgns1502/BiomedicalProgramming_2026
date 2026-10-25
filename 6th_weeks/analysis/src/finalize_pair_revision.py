"""Finalize documentation-only correction and verify unchanged source/statistical outputs."""
from pathlib import Path
import json,csv,hashlib,shutil,datetime,sys

root=Path(sys.argv[1]).resolve()
qa=Path(sys.argv[2]).resolve()
revision='PAIR1-20261024'
run=root/'analysis/runs/R1-20261024'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def writej(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
baseline=load(root/'analysis/documentation/history'/revision/'preservation_baseline.json')
for item in baseline['preserved_artifacts']:
    assert sha(root/item['file'])==item['sha256'],item['file']
with (run/'artifact_hashes.csv').open(encoding='utf-8-sig',newline='') as f:
    frozen=list(csv.DictReader(f))
for item in frozen:assert sha(run/item['file'])==item['sha256'],item['file']
manifest=load(root/'analysis/report_manifest.json')
report=root/manifest['html']
assert sha(report)==manifest['html_sha256']
assert manifest['paired_stages']==7 and len(manifest['markdown'])==29
for item in manifest['markdown']:assert sha(root/item['file'])==item['sha256']
for item in manifest['images']:assert sha(root/item['file'])==item['sha256']
registry=load(root/'analysis/stage_registry.json')
assert len(registry['stages'])==7
for item in registry['stages']:
    assert (root/item['concept']).exists() and (root/item['paper']).exists()
assert len(list(root.glob('*.html')))==1
text=report.read_text(encoding='utf-8')
assert text.count('class="learning-part concept"')==text.count('class="learning-part paper"')==7
assert text.count('src="data:image/png;base64,')==7
assert '<script src=' not in text and '<link rel="stylesheet"' not in text
browser=load(qa/'browser_review.json')
assert browser['decision']=='pass' and browser['sha256']==sha(report)
assert browser['desktop']['mdRecords']==29
destination=root/'analysis/reviews/PAIR1-20261024'
destination.mkdir(parents=True,exist_ok=True)
for item in qa.iterdir():
    if item.is_file():shutil.copyfile(item,destination/item.name)
shutil.copyfile(qa/'browser_review.json',root/'analysis/reviews/browser_review.json')
assert sha(root/'analysis/src/paired_learning.py')=='975f0a67c7822dce86fa994a82d18232b80c992d62340033b0829ae87cc5f614'
assert sha(report)=='4fdf6816963ffc0846835ea7d0c414217d58378a4ba2cfdfffaacd64ec8c5f23'
review=dict(date_utc=now,revision=revision,reviewer='/root/paired_content_review',decision='accept',html_sha256=sha(report),paired_learning_source_sha256=sha(root/'analysis/src/paired_learning.py'),scope='New documentation content and static HTML structure only; no numerical reanalysis or independent validation of original statistics',checks=['7 visible concept/paper pairs','hypothetical examples separate from actual data','paper BA regression distinct from course device~ECG OLS and supplemental diagnostics','input/question/method/reason/output/remaining questions','OLS normality wording clarified','plot wording acknowledges STYLE1 display changes','Pearson point/r/CI/p definitions'],remaining_actions=[])
writej(root/'analysis/reviews/documentation_content_review.json',review)
verification=load(root/'analysis/documentation/history'/revision/'previous-verification_summary.json')
verification.update(status='completed',documentation_revision=revision,documentation_only_change=True,statistics_refits=0,unchanged_preserved_artifacts=len(baseline['preserved_artifacts']),frozen_R_artifacts_sha_verified=len(frozen),MD_sha_verified=len(manifest['markdown']),paired_learning_stages=7,concept_MD=7,paper_MD=7,learning_guide_MD=1,existing_process_and_device_MD_preserved=14,HTML_sha256=sha(report),root_final_HTML_files=1,browser='desktop/mobile:7 visible concept/paper pairs,7plots,88rows,29MD,filter,CSV,demo,print passed',browser_review='analysis/reviews/browser_review.json',documentation_content_review='analysis/reviews/documentation_content_review.json',updated_utc=now)
writej(root/'analysis/reviews/verification_summary.json',verification)
state=load(root/'analysis/memory/project.json')
state.update(status='completed',documentation_revision=revision,docs_count=29,paired_learning_stages=7,html=report.name,html_sha256=sha(report),updated_utc=now,documentation_review='accept; content and browser only, not independent numerical review')
writej(root/'analysis/memory/project.json',state)
with (root/'analysis/memory/events.jsonl').open('a',encoding='utf-8') as f:
    f.write(json.dumps(dict(time_utc=now,stage='documentation-pairing-revision',revision=revision,run_id='R1-20261024',stats_refits=0,preserved_artifacts_verified=len(baseline['preserved_artifacts']),paired_stages=7,MD_files=29,html_sha256=sha(report),browser='pass',documentation_content_review='accept'),ensure_ascii=False)+'\n')
manifest.update(browser_review='analysis/reviews/browser_review.json',documentation_content_review='analysis/reviews/documentation_content_review.json',verification_summary='analysis/reviews/verification_summary.json',source_code=[{'file':'analysis/src/'+name,'sha256':sha(root/'analysis/src'/name)} for name in ['build_report.py','paired_learning.py']],stage_registry_sha256=sha(root/'analysis/stage_registry.json'))
writej(root/'analysis/report_manifest.json',manifest)
files=[p for p in root.rglob('*') if p.is_file() and p!=root/'analysis/project_manifest.json' and 'r-library' not in p.parts and '__pycache__' not in p.parts and '.uv-cache' not in p.parts]
writej(root/'analysis/project_manifest.json',dict(created_utc=now,documentation_revision=revision,excludes=['analysis/r-library runtime','__pycache__','.uv-cache','this manifest'],files=[dict(file=p.relative_to(root).as_posix(),bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(files)]))
print(json.dumps(dict(status='completed',html_sha256=sha(report),unchanged_artifacts=len(baseline['preserved_artifacts']),frozen_R_hashes=len(frozen),concept_paper_pairs=7,MD_files=29,plots=7,raw_pairs=88,browser='pass',documentation_review='accept',project_manifest_files=len(files)),ensure_ascii=False))
