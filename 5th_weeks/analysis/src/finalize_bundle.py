from pathlib import Path
import json,sys,hashlib,datetime
r=Path(sys.argv[1]);a=r/'analysis';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
checks=load(a/'reviews/final-document-check.json')
if checks['issues']:raise RuntimeError('Resolve document checks first')
project=load(a/'memory/project.json')
project.update(current_core_run='R2-20261004',current_extended_run='E2-20261004',raw_extended_diagnostic_run='E1-20261004',current_validation_run='V1-20261004',current_plan='config/plan-v1.5.json',environment_snapshot='environment/ENV2-20261004',status='completed defined scope; partial reproduction',completed_at=now,blinding='Publication values visible during source review; independent agents, not blinded',data_version=load(a/'runs/E2-20261004/report.json')['data_version'])
(a/'memory/project.json').write_text(json.dumps(project,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
readme=a/'README.md'
if '최종 현재 실행:' not in readme.read_text(encoding='utf-8'):
 with readme.open('a',encoding='utf-8') as f:
  f.write('\n\n최종 현재 실행: R2(core), E1(원시 검사값 진단 및 M1/M2 재사용 출처), E2(CDC 검사법 보정한 주 후보), V1(독립 이항·OR/PR·짝지음 교육 검증). 모든 계산이 완료됐으며 범위별 독립 감사를 통과했습니다. 환경 기록은 ENV2-20261004입니다. ENV-20261004는 환경 JSON 직렬화 실패를 보존한 기록입니다. 논문 정확 복제 판정은 부분 재현이며 n 및 미공개 설정 차이가 남습니다.\n')
files=[]
for base in (a/'src',a/'config',a/'reviews',a/'memory',a/'comparisons/E2-20261004',r/'치주질환과 고혈압 - 분석 길잡이',r/'실행 설계'):
 for p in base.rglob('*'):
  if p.is_file():files.append({'file':str(p.relative_to(r)),'bytes':p.stat().st_size,'sha256':sha(p)})
for p in (r/'README.md',a/'README.md'):files.append({'file':str(p.relative_to(r)),'bytes':p.stat().st_size,'sha256':sha(p)})
out={'created_at':now,'status':'defined required scope complete','reproduction':'partial','files':files,'run_manifests':{id:sha(a/'runs'/id/('manifest.json' if id=='V1-20261004' else 'artifact_hashes.csv')) for id in ('R2-20261004','E1-20261004','E2-20261004','V1-20261004')},'warnings_scope':'E2 new warnings do not replace historical warnings of E1 reused outputs; LC startup warnings disclosed.','archived_failures':['R1-20261004','ENV-20261004']}
(a/'final_bundle_manifest.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'manifest_files':len(files),'run_ids':list(out['run_manifests']),'current_data_version':project['data_version']},ensure_ascii=False))
