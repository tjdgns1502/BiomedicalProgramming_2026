# 6주차: 상관·단순 선형회귀·측정 오차

[최종 분석 보고서 HTML](최종분석보고서.html)을 브라우저로 여세요. 각 학습 단계의 **일반 통계 개념(concept) → 논문·실제 데이터 적용(paper)** 구분을 7쌍으로 복원했습니다. 이론에는 가상 계산·가정·대안을, 적용에는 원문 사실·이번 구현의 선택·실제 결과·남은 의문을 담았습니다. 그림7개, 전체88쌍, 결과·문제·한계와 모든 MD29개가 HTML 안에 내장되어 있습니다. 최종 보고서 HTML은 한 개입니다.

- `data/raw`: 공개 XLSX 원본. 변경하지 않습니다.
- `docs/learning`: 학습 정본. 7단계 concept/paper 14개 MD와 읽기 지도 1개. 각 문서는 입력→질문→방법과 이유→출력→남은 질문으로 연결합니다.
- `docs/00–09`, `docs/devices`: 기존 단계별10개·기기별4개 보조 기록을 보존합니다.
- `analysis/stage_registry.json`: 단계ID, 관측 단위, 입출력, concept/paper 경로, 원문 근거, 그림·문제ID. 학습 순서와 실행 의존성을 별도로 기록합니다.
- `analysis/config`: 실행 전 고정한 계획·자료 정의·보강 프롬프트.
- `analysis/src`: R 통계와Python 보조·검산·문서 생성 코드.
- `analysis/runs/R1-20261024`: CSV, 모형, 그림, 수식검사, Python 교차검사, 원문 비교, 환경과경고.
- `analysis/memory`: 현재 상태와 발견 문제의 정본.
- `sources`: 원문·수정 슬라이드·표 추출·원본해시. 원본페이지는 최종HTML과 구별해source.txt에 보관합니다.

현재 참가자는22명·기기별22쌍이며 총88쌍입니다. 원자료의HR가 참가자별평균이므로15초·활동별 분석을 생성하지 않았습니다. 주 분석 제외·축소·대체는0입니다. 큰 오차를 유지하고 한 명씩제외하는 별도민감도만 수행했습니다.

## 재실행

R4.6.1, readxl1.6.0, jsonlite, digest를 사용합니다. 프로젝트의analysis/r-library를 먼저참조합니다. 아래는프로젝트루트에서 새runID로 실행하는예입니다.

```powershell
$taskRscript='C:\Program Files\R\R-4.6.1\bin\Rscript.exe'
& $taskRscript 'analysis/src/analyse_heart_rate.R' '.' 'R-new-run'
uv run 'analysis/src/crosscheck_and_source.py' '.' 'R-new-run'
uv run 'analysis/src/compare_publication.py' '.' 'R-new-run'
uv run 'analysis/src/build_report.py' '.' 'R-new-run'
```

Python 보조는 numpy와 openpyxl이 있는 환경에서 uv로 실행합니다. 원자료는 불변이며 기존 run ID를 덮어쓰지 않습니다. 보고서는 지정한 run의 CSV에서 읽어 HTML 한 파일을 갱신하므로, 여러 run이 있으면 자료 버전을 확인하세요. 출처 원본과 분석 단계 변경의 검토 범위를 기록합니다.

자체수식검사와언어간대조를했으며외부심사는아닙니다. 원문삼성상관0.67은Spearman이고과제Pearson0.743과구별합니다. 원문의일부반올림·가변LoA는정확재현주장을제한합니다.


## GitHub 공유본

이 폴더는 사용자 지정 6주차 작업 폴더의 `PAIR1-20261024` 결과를 공유한 스냅샷입니다. 기존 2–5주차와 같은 저장소의 `doyun` 브랜치에 `6th_weeks/`로 추가했습니다.

- 최종 HTML은 [최종분석보고서.html](최종분석보고서.html) 한 파일이며 그림·표·전체 88쌍·concept/paper 학습 설명·MD를 내장합니다. GitHub 파일 화면에서는 HTML이 실행되지 않으므로 내려받아 브라우저로 여세요.
- [학습 읽기 지도](docs/learning/00-학습문서읽기지도.md)에서 일반 개념과 논문 적용의 7쌍을 확인할 수 있습니다.
- 공식 공개 S1 XLSX는 59,512바이트이며 재현 입력을 고정하기 위해 포함했습니다. 출처는 [PLOS S1 Dataset](https://doi.org/10.1371/journal.pone.0154420.s001), 원 논문은 [Wallen et al. (2016)](https://doi.org/10.1371/journal.pone.0154420)입니다. 출처·라이선스 표기는 공식 원문을 따릅니다.
- R1 CSV·모형·원본 그림, STYLE1 그림 표시 수정, 문제·실패·검토·이전 설명 기록을 포함합니다. 원자료와 통계 결과를 다시 계산하거나 수정하지 않았습니다.
- 설치된 `analysis/r-library`, Python 바이트코드와 캐시는 제외했습니다. R 패키지는 `analysis/src/setup_environment.R`로 준비할 수 있으며 버전은 실행 환경 기록에서 확인하세요. Python 보조 스크립트는 numpy·openpyxl을 준비한 환경에서 `uv run`을 사용합니다.
- 과거 실행·검토·일부 보조 QA 스크립트에는 당시 로컬 절대경로가 남아 있습니다. 해당 기록은 그대로 보존하며 새 컴퓨터에서 전체 재실행을 검증한 패키지로 표시하지 않습니다.
- 원래 `analysis/project_manifest.json`은 로컬 분석본 기준입니다. 이 공유본의 README·게시 설정 추가에 따른 실제 파일 목록과 해시는 [publication_manifest.json](publication_manifest.json)을 기준으로 확인하세요.

Jev 및 토큰 효율화는 검토·계획만 진행했으며 설치·적용·절감률 계측을 수행한 결과는 이 공유본에 포함하지 않습니다.
