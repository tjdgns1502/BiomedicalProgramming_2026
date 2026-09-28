from pathlib import Path
import hashlib,json,datetime
out=Path('analysis/tasks/V3-I01/rev-1/work')
inputs=[Path('analysis/data/derived/candidate_all_age50.csv'),Path('analysis/data/derived/nhanes_design_all.csv'),Path('analysis/config/fi_candidate.json')]
inputs+=list(Path('analysis/tasks/V3-I01/rev-1/packet').glob('*.md'))
inputs+=[Path('analysis/tasks/V2-I01/rev-1/work/checks.R'),Path('analysis/src/model_extensions.R')]
inputs+=list(Path('analysis/data/raw').glob('*/ALQ*.xpt'))+list(Path('analysis/data/raw').glob('*/DR2TOT*.xpt'))+[Path('analysis/data/raw/1999-2000/DRXTOT.xpt')]
rows=[{'path':p.as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in inputs]
(out/'input_provenance.json').write_text(json.dumps({'created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'read_scope':'own methods packet, candidate and survey inputs, approved reference code, ALQ and diet XPT only; no paper effect-result matching','inputs':rows},indent=2),encoding='utf-8')
