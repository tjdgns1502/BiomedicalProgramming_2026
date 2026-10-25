# 6주차 분석 — Wallen et al. (2016) 심박수 시계 정확도

최종 전달물: [`../최종분석보고서.html`](../최종분석보고서.html) · 학습 문서: [`../docs/learning/`](../docs/learning/00-학습문서읽기지도.md) · 실행 기준: [`config/실행프롬프트-6주차.md`](config/실행프롬프트-6주차.md), [`config/전체실행프롬프트-v2.1.md`](config/전체실행프롬프트-v2.1.md)

## 다시 실행하기
모든 명령은 이 폴더(`6th_project/analysis`)에서 실행한다. Rscript는 저장소 루트의 `bin/Rscript.exe` (R 4.6.1). 한글 경로 때문에 Git Bash가 아닌 PowerShell에서 실행한다.

```powershell
# 0) 원자료 준비: 저장소는 **/data/raw/를 커밋하지 않는다
Copy-Item ..\dataset\pone.0154420.s001.xlsx data\raw\   # SHA-256 50cae0d2...fcff 이어야 함
# 1) 주 분석 (이미 있는 run_id에는 쓰지 않음 → 새로 돌리려면 새 run_id와 config/plan_<run_id>.json 필요)
Rscript src/run_analysis.R R1-20261025
Rscript tests/test_stats.R runs/R1-20261025
# 2) 탐색적 반올림 후보
Rscript src/run_candidates.R R2-20261025
# 3) 학습 문서와 보고서 (통계를 다시 계산하지 않음)
Rscript src/10_render_docs.R
Rscript src/20_build_report.R
```

## 폴더
| 경로 | 역할 |
|---|---|
| `config/` | 실행 프롬프트 사본, 실행 전 계획(`plan_R1…`, 탐색 계획 `plan_R2…`), 원문 Table 1 HR 전사 |
| `data/raw/` | 원자료 (변경 금지, git 제외) |
| `data/derived/<data_version>/` | 88쌍 파생 자료 (버전 = CSV SHA-256 앞 20자리) |
| `src/` | `01`–`05` 분석 함수, `run_*.R` 실행기, `10` 문서 렌더, `20` HTML 빌드 |
| `tests/` | 공식 대조 검사 |
| `runs/<run_id>/` | 불변 실행 결과: tables, figures, models, logs, env, manifest.json |
| `templates/` | PAPER MD 템플릿(`{{v:…}}` 자리표시자)과 HTML 껍데기 |
| `memory/` | 문제 원장 `issues.json`, 결정·요구·진행·사실·사건 기록, 작업 등록부 |
| `reviews/` | 코드 감사, 브라우저 점검 |
| `stage_registry.json` | 단계 HR01–HR07: 입출력, 읽기 순서, 실행 의존성, 문서 경로, 문제 ID |
| `output_coverage.json` | 과제 요구사항·원문 표/그림별 구현·비교 상태 |

## 규칙 요약
- PAPER MD(`docs/learning/HR0x-paper.md`, `00-…`)는 템플릿에서 생성한다. 숫자를 고치려면 템플릿을 고쳐 다시 렌더한다. CONCEPT MD는 직접 편집한다(가상 숫자만).
- 원자료·기존 run·실패 기록을 덮어쓰지 않는다. 통계 코드가 바뀌면 새 run_id로 실행한다.
