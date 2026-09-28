# 논문 분석 구현 프로젝트

현재 후속 실행은 `tasks/V3-I01/rev-1/work/`에 있습니다. `prepare.R`는 자료 재구성, `models.R`는 회귀·추세·곡선·상호작용, `descriptions.R`는 기술표·군 비교·그림을 구현합니다. `coverage_manifest.json`에서 논문 출력과 파일을 연결하고, 독립 검토는 `tasks/V3-Q01/rev-1/work/result_review.json`에서 확인합니다. 검토된 실행 사본은 `runs/V3-20260928T003525Z/`, 현재 표·그림별 상태는 `memory/output_coverage.json`입니다. 읽기용 결과는 기존 Obsidian 학습 노트의 각 paper 3구역 첫 부분에 통합했습니다.

분석 환경: Windows, R 4.6.1. Python 보조 작업은 `uv`를 사용합니다.
실행 위치는 이 폴더의 상위인 기존 **4주차 작업 폴더**입니다.

이 폴더는 코드·설정·원자료·실행 로그를 보존합니다. v2부터 학습 문서의 편집 기준은 기존 Obsidian `4주차/염증과 노쇠 - 분석 길잡이/`입니다. `frailty-learning/source`는 이전 실행의 대응 사본이며 앞으로 유지하면 검토된 단방향 미러로 관리합니다. 별도 최종 보고서나 HTML을 생성하지 않습니다.

전체 실행 계약은 [오케스트레이션 프롬프트 v2.0](../frailty-agent-workflow/docs/05-prompts.md)을 따릅니다. 기존 실행과 메모리는 당시 결과로 보존합니다. 아래 실행 방법은 이미 구현된 분석의 재실행 안내이며, v2의 모든 에이전트·상태 전이를 자동 실행하는 프로그램이라는 뜻은 아닙니다.

## 실행

```powershell
uv run analysis/src/project.py environment
uv run analysis/src/project.py status
```

R은 `C:/Program Files/R/R-4.6.1/bin/Rscript.exe`를 사용합니다. `Rscript`가 PATH에 없어도 프로젝트의 실행 도구가 전체 경로를 사용합니다. 실행별로 `LANG=C`, `LC_ALL=C`를 지정하며 전역 환경 설정은 변경하지 않습니다.

`analysis/config/analysis_plan.json`은 실제 자료의 결과를 보기 전에 작성한 분석 계획입니다. 원문 결과를 이미 알고 있다는 사실을 기록했습니다. FI 재구성 규칙이 원문에서 완전히 확인되지 않으면 이를 재구성 후보로 명명하고 원 논문 FI와 동일하다고 단정하지 않습니다.

통계 코드는 `src/`, 데이터와 출처는 `data/`, 개별 실행과 stdout/stderr·환경·해시는 `runs/`, 사용자 요구·의사결정·진행 상태는 `memory/`에 둡니다. 원자료는 덮어쓰지 않으며 실행별 결과를 보존합니다.

## 환경과 실행 순서

현재 확인: R 4.6.1, `foreign` 0.8-91, `survey` 4.5, VS Code의 REditorSupport.r 확장 설치됨. 전체 R 패키지 버전은 `runs/E00-environment/session-info.txt`에 있습니다. Python 자료 처리는 `uv run`과 스크립트별 의존성(`pandas==3.0.3`)을 사용합니다. 다른 컴퓨터의 R 실행 경로는 `src/project.py`의 `R` 값에서 지정합니다. 의존성의 무조건적인 최신 업데이트는 실행 재현과 구분합니다.

현재 작업 폴더에서 아래 순서로 실행할 수 있습니다. 원자료는 캐시 검증 후 재사용하며, 원본을 수정하지 않습니다. 데이터 재생성은 파생 파일을 다시 쓰므로 기존 실행의 입력 해시와 대조해야 합니다. 통계 재실행은 `{run_dir}`로 새 실행 폴더에 결과를 보존합니다.

```powershell
uv run analysis/src/download_nhanes.py
uv run analysis/src/prepare_nhanes.py
uv run analysis/src/prepare_nhanes_design.py
uv run analysis/src/construct_fi_candidate.py
uv run analysis/src/project.py run T01 analysis/tests/test_group_analysis.R
uv run analysis/src/project.py run T02 analysis/tests/test_model_extensions.R '{run_dir}/synthetic-artifacts'
uv run analysis/src/project.py run A01 analysis/src/group_analysis.R analysis/data/derived/candidate_complete36.csv '{run_dir}/artifacts'
uv run analysis/src/project.py run A02 analysis/src/model_extensions.R analysis/data/derived/candidate_complete36.csv analysis/data/derived/nhanes_design_all.csv '{run_dir}/artifacts'
uv run analysis/src/project.py run A03 analysis/src/fi_coding_sensitivity.R analysis/data/derived/candidate_all_age50.csv '{run_dir}/artifacts'
uv run analysis/src/project.py run M01 analysis/src/simulation.R --out-dir '{run_dir}/artifacts' --B 10000 --seed 20260928
uv run analysis/src/project.py run M02 analysis/src/procedure_simulation.R '{run_dir}/artifacts' 2000 20260929
uv run analysis/src/verify_delivery.py
```

`.vscode/tasks.json`에서 환경 확인, 코드 검사, 군 비교, 원리 모의실험을 실행할 수 있습니다. 복합표본 분석은 전체 연령의 설계를 먼저 구성한 뒤 후보 완전사례 집단을 선택합니다. 보통의 ANOVA와 같은 추론이라고 부르지 않습니다.

`runs/A01-groups`, `A02-models`, `A03-coding`은 이번 검토의 실제 결과입니다. 실행 시각·코드·입력 해시는 같은 task ID로 시작하는 시각별 폴더의 `execution.json`, 표준 출력·오류 로그에 있습니다. `M01-simulation`, `M02-procedure`에는 모의실험 계획·seed·원 복제 결과·수치 요약이 있습니다.

문서 추가 스크립트는 이전의 검토된 실행만 대상으로 하며 중복 실행을 거부합니다. 기존 `frailty-learning/build.py`는 실행하지 않습니다. 원본 문서 보존 검증은 `runs/D01-documents/`에 있습니다. 설명은 Obsidian의 `00-start 처음부터 따라가는 분석 흐름.md`에서 시작합니다. 이 실행 당시 문서 해시와 이후의 명시적 문서 개정은 구별하며, 운영 프롬프트를 바꿨다고 분석 수치가 재검증된 것은 아닙니다.
