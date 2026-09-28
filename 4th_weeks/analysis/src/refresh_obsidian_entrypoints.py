"""Connect existing operational notes to actual reviewed results without replacing user edits."""
from pathlib import Path
from datetime import datetime, timezone
import json,re,hashlib
r=Path(__file__).resolve().parents[1];w=r.parent;vault=w/'4주차';ops=vault/'4주차 과제 - 에이전트 실행 설계'
stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ');backup=r/'backups'/('obsidian-entrypoints-'+stamp);backup.mkdir(parents=True)
start='염증과 노쇠 - 분석 길잡이/00-start 처음부터 따라가는 분석 흐름'
block=f'''<!-- CURRENT-EXECUTION-START -->
## 현재 실행 결과 — 2026-09-28 갱신

**분석은 실행·독립 검토까지 완료했습니다.** 이 폴더는 에이전트 운영 설명이고, 실제 분석 설명·표·그림은 기존 **[[{start}|염증과 노쇠 — 분석 길잡이 시작 문서]]**에 있습니다. 각 paper 문서의 **3구역 첫 부분**이 후속 실행 결과입니다.

| 확인할 내용 | 실제 상태 | 결과를 읽을 위치 |
|---|---|---|
| 설문 분기와 FI 후보 | 공식 분기 재구성·독립 대조 완료; FI 완비 후보 13,289명 | [[염증과 노쇠 - 분석 길잡이/03-paper 03 이 논문은 FI를 어떻게 정의했나|03 FI 정의와 재구성]] |
| 표본 선정 | 기준 집단 13,252명, Model2 10,874명 | [[염증과 노쇠 - 분석 길잡이/04-paper 04 표본 선정과 단면자료의 한계|04 표본 흐름]] |
| 기술표·군 비교 | Table1·S2–S5 요약과 85개 비교 검정 완료; 구조적으로 연결된 5개는 제외 이유 기록 | [[염증과 노쇠 - 분석 길잡이/05-paper 05 Table 1을 읽는 순서|05 Table1]] |
| 회귀·사분위·추세 | 보충 분석 포함 120개 모형 적합·검토 완료 | [[염증과 노쇠 - 분석 길잡이/08-paper 08 Table 2의 Model 1과 Model 2|08 Model1·Model2]] · [[염증과 노쇠 - 분석 길잡이/09-paper 09 Table 3은 같은 데이터를 어떻게 다시 보나|09 사분위·추세]] |
| 곡선·하위집단·민감도 | 비선형 진단 8개, 상호작용 24개, 그림 4개 완료 | [[염증과 노쇠 - 분석 길잡이/10-paper 10 Figure를 통해 결론의 범위 정하기|10 그림과 검토 결과]] |

**남은 제한:** 저자와 정확히 동일한 FI 코딩·음주·활동량·스플라인 설정은 일부 미확인입니다. 위 상태는 명시한 후보 구현의 완료이며 원 논문의 동일 수치 재현을 인증한 것은 아닙니다. 일반 beta regression은 FI=0이 있어 그대로 적용하지 않았고, 기존 fractional 분석은 별도 평균-FI 질문의 결과로 유지합니다.

실제 코드·로그 기준은 작업 루트의 `analysis/tasks/V3-I01/rev-1/work/`, 독립 검토는 `analysis/tasks/V3-Q01/rev-1/work/`, 표·그림별 완료 상태는 `analysis/memory/output_coverage.json`입니다. 아래 옛 설계에 나오는 예시 경로·작업 ID를 실제 완료 파일 목록으로 읽지 마세요.
<!-- CURRENT-EXECUTION-END -->

'''
changed=[]
for name in ['00-start.md','01-lineage.md','02-context.md','03-tasks.md','04-protocol.md','06-audit.md']:
 path=ops/name;old=path.read_text(encoding='utf-8-sig');(backup/name).write_text(old,encoding='utf-8')
 text=re.sub(r'<!-- CURRENT-EXECUTION-START -->.*?<!-- CURRENT-EXECUTION-END -->\s*','',old,flags=re.S)
 add=block if name in ['00-start.md','03-tasks.md'] else f'<!-- CURRENT-EXECUTION-START -->\n> **현재 실행 상태:** 아래는 운영 설계 설명입니다. 실제 완료 상태는 [[4주차 과제 - 에이전트 실행 설계/03-tasks|현재 작업·결과 연결표]], 분석 설명은 [[{start}|기존 학습 문서]]에서 확인하세요.\n<!-- CURRENT-EXECUTION-END -->\n\n'
 if name=='03-tasks.md':text=text.replace('상태는 모두 **계획됨**입니다. 작업 설명을 작성한 것을 통계 분석 완료로 세지 않습니다. 입력이 확보되고 의존 산출물이 검수되면 실행할 수 있습니다.','아래 표는 **초기 v1에서 계획했던 작업 목록**입니다. 현재 실행 상태는 위의 결과 연결표를 기준으로 읽습니다. 아래 작업 ID와 산출물 경로는 당시 설계 예시이며 실제 V3 실행 파일과 일대일로 일치하지 않습니다.')
 path.write_text(add+text,encoding='utf-8');changed.append(path.relative_to(w).as_posix())
errors=[]
for name in ['00-start.md','03-tasks.md','01-lineage.md','02-context.md','04-protocol.md','06-audit.md']:
 for target in re.findall(r'\[\[([^\]|]+)(?:\|[^\]]*)?\]\]',(ops/name).read_text(encoding='utf-8')):
  target=target.split('#')[0]
  if not any((base/(target+'.md')).exists() or (base/target).exists() for base in [ops,vault]):errors.append(name+':'+target)
assert not errors,errors
(backup/'change_manifest.json').write_text(json.dumps({'changed':changed,'reason':'Operational notes remained stale while learning notes held current results','links_verified':True,'backup':str(backup)},ensure_ascii=False,indent=2),encoding='utf-8')
with (r/'memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'timestamp':stamp,'kind':'obsidian_entrypoint_repair','changed':changed,'analysis_rerun':False,'user_edits_preserved':True},ensure_ascii=False)+'\n')
print('Updated six existing operational notes; links verified; originals backed up.')
