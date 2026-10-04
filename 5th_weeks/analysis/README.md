# 분석 실행과 환경 기록

분석은 R 4.6.1의 `Rscript.exe`로 실행합니다. 프로젝트는 `5주차`, 패키지는 `analysis/r-library`, 결과는 `analysis/runs/<run_id>`에 있습니다. 모든 분석 스크립트는 기존 run ID가 있으면 중단합니다. 기존 결과를 지우거나 덮어쓰지 말고 새 ID를 사용하세요.

## 기존 실행 명령

아래는 R2·E1·V1의 실행 인자를 기록한 명령입니다. 기존 ID로 그대로 재실행하지 않습니다. R2·E1·E2·V1은 모두 완료된 기존 실행입니다.

```powershell
Set-Location -LiteralPath '5th_weeks' # 저장소 루트에서 실행
$taskRscript = 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe'
& $taskRscript 'analysis/src/run_analysis.R' '.' 'R2-20261004' '--stage=all'
& $taskRscript 'analysis/src/extend_models.R' '.' 'E1-20261004' '--input-run=R2-20261004' '--candidate=both' '--stage=model' '--complete-case=false'
& $taskRscript 'analysis/src/assignment_validation.R' '.' 'V1-20261004'
```

각 R 스크립트 첫 줄의 `Sys.setlocale('LC_ALL', 'English_United States.utf8')`는 Windows 한글 경로 처리에 필요합니다. `Rscript.exe` 절대경로를 사용하므로 PATH 설정에 의존하지 않습니다.

## 새 ID로 재실행

먼저 승인된 plan/config와 실행할 source를 확인합니다. 아래 명령은 현재 source의 정의를 사용합니다. 과거 결과를 정확히 재현하려면 해당 run의 `executed_script.R`, `core_script_snapshot.R`와 당시 plan·환경 기록을 확인해야 합니다. 실행 중인 작업과 설정 파일을 변경하지 않습니다.

```powershell
$taskStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
$taskCoreRun = 'R-replay-' + $taskStamp
$taskExtendedRun = 'E-replay-' + $taskStamp
$taskValidationRun = 'V-replay-' + $taskStamp
& $taskRscript 'analysis/src/run_analysis.R' '.' $taskCoreRun '--stage=all'
& $taskRscript 'analysis/src/extend_models.R' '.' $taskExtendedRun ('--input-run=' + $taskCoreRun) '--candidate=both' '--stage=model' '--complete-case=false'
& $taskRscript 'analysis/src/assignment_validation.R' '.' $taskValidationRun
```

R 단계가 성공했는지 확인한 후 E 단계를 시작합니다. 아래의 plan1.5 repair까지 실행한 결과가 검사값 보정을 반영한 primary candidate입니다. `--stage=test`는 다운로드·정의·QA·기술통계를 실행하고 회귀 적합을 생략합니다. core의 `--stage=model --input-run=<성공한 core run>`는 기존 master를 검증해 새 run에서 재사용합니다. 확장 분석은 성공한 core run의 master·manifest·캐시 해시를 확인합니다.

원자료 XPT는 `analysis/data/raw/nhanes`, 공식 codebook HTML은 `analysis/sources/cache/codebooks`에서 재사용합니다. 기존 캐시는 검증만 하고 덮어쓰지 않습니다. 누락 파일만 내려받으며 최초 시도 이후 최대 두 번 재시도합니다. XPT 헤더·SEQN 중복·해시 오류가 발생하면 임의 수정으로 통과시키지 말고 실패 기록을 확인합니다.

## plan1.5 검사값 보정

`repair_harmonization.R`는 완료된 E1의 master·모든 artifact·캐시 해시를 검증하고, frozen core/extension snapshot의 함수를 재사용합니다. E1과 raw cache는 보존합니다. 새 E2 run에서 2017–2018 BIOPRO creatinine에 `1.051*LBXSCR-0.06945`, TG에 `0.9655*LBXSTR-7.020`을 적용한 뒤 결측 대체를 계산합니다. 원값은 별도 열에 남깁니다. 승인된 `analysis/config/plan-v1.5.json`이 필요합니다.

```powershell
# 승인된 E2 실행 인자: 기존 ID가 있으면 새 ID로 바꾸세요.
& $taskRscript 'analysis/src/repair_harmonization.R' '.' 'E2-20261004' '--input-extended-run=E1-20261004' '--candidate=both' '--complete-case=false'
# 위 재실행 예시의 새 확장 결과를 입력으로 사용하려면:
$taskRepairedRun = 'E-harmonized-' + $taskStamp
& $taskRscript 'analysis/src/repair_harmonization.R' '.' $taskRepairedRun ('--input-extended-run=' + $taskExtendedRun) '--candidate=both' '--complete-case=false'
```

모든 Model3·추세·상호작용과 변경된 lab Table1·forest를 다시 계산합니다. Model1/2와 변경 없는 기술통계는 E1 결과를 출처·해시와 함께 재사용합니다. `artifact_dependencies.csv` 및 `tables/*row_provenance.csv`에서 재사용·재계산 범위를 확인하세요. E1은 보정 전 진단 기록이며 별도의 세 번째 후보가 아닙니다. 필수 A/B 분석 표의 기존 CSV 열 구조를 유지합니다.

## 정의와 완료 여부 확인

- core는 `analysis/config/plan-v1.1.json`, E1은 `plan-v1.4.json`, E2는 `plan-v1.5.json`과 각 run의 `definitions.json`을 확인합니다.
- `status.json`의 `success`, `report.json`, `logs/analysis.log`, `logs/warnings.csv`, `tables/invariants.csv`를 함께 확인합니다. V1은 해당 스크립트가 만든 실제 보고·manifest 파일을 확인합니다.
- `sources_manifest.csv`는 원자료 URL·SHA256·사이클을, `artifact_hashes.csv`는 결과 바이트를 기록합니다. manifest 자체는 자기 해시 대상에서 제외됩니다.
- E1의 `upstream_input.json`은 입력 core의 master·manifest·report 해시를 기록합니다. 실행 코드 snapshot과 `models/model_metadata.json`의 실제 공식·표본 수·자유도를 확인합니다.
- `_lean.rds`는 계수·분산행렬·공식·N·자유도 등의 작은 재현 파일입니다. 전체 survey 객체는 master·코드·설계 기록으로 다시 구성합니다.

## 환경 수집

`collect_environment.R`를 `analysis/src`에 둔 뒤 새 snapshot ID로 실행합니다. 이 스크립트는 패키지를 설치·업데이트하지 않고 `analysis/environment/<snapshot_id>`에만 새 파일을 씁니다.

```powershell
$taskEnvironmentId = 'ENV-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
& $taskRscript 'analysis/src/collect_environment.R' '.' $taskEnvironmentId '--check-run=R2-20261004'
```

`environment.json`, `project_packages.csv`, `visible_packages.csv`, `library_paths.txt`, `sessionInfo.txt`, `major_description_hashes.csv`, `plan_hashes.csv`가 생성됩니다. `--check-run`은 결과 파일의 SHA256 일치를 확인하며 통계적 타당성을 독립 검증하는 기능은 아닙니다. 완료되지 않은 run에는 최종 manifest가 없을 수 있습니다.

## 검정 결과 해석

학습용 V1은 독립 표본을 가정한 R 기본 `chisq.test`·`fisher.test`, 짝지은 예제의 McNemar 검정과 이항 검정, 고정 seed의 모의실험을 다룹니다. Pearson, 2×2 Yates, Fisher 결과를 구분하며 Fisher의 조건부 MLE OR는 단순 `ad/bc`와 다릅니다.

NHANES 주 분석은 PSU·층화·MEC 또는 식이 가중치를 사용하는 `survey` 분석입니다. 전체 유효 가중치 설계를 만든 뒤 연구 영역을 subset하며, Rao–Scott F 검정·`svyttest`·`svyglm(quasibinomial)`을 사용합니다. 비가중 기본 검정과 모자이크는 비교·학습용 결과입니다. 회귀의 주 CI/p는 survey 모형 잔차 자유도의 t 추론이며, 확장의 정규 z 결과는 별도로 표시합니다. 논문 결과값은 문서 검토 중 노출되었고 목표값에 맞춘 조건 조정은 하지 않았습니다.

Python 도구가 필요한 후처리는 사용자 규칙에 따라 `uv run`, `uv add` 또는 `uv pip install`을 사용합니다. R 분석 실행 자체는 위의 `Rscript.exe` 명령입니다.


최종 현재 실행: R2(core), E1(원시 검사값 진단 및 M1/M2 재사용 출처), E2(CDC 검사법 보정한 주 후보), V1(독립 이항·OR/PR·짝지음 교육 검증). 각 실행은 success이며 범위별 독립 감사를 통과했습니다. 환경 기록은 ENV2-20261004입니다. ENV-20261004는 환경 JSON 직렬화 실패를 보존한 기록입니다. 논문 정확 복제 판정은 부분 재현이며 n 및 미공개 설정 차이가 남습니다.
