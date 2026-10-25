# 6주차: 상관·단순 선형회귀·측정 오차

[최종 분석 보고서 HTML](최종분석보고서.html)을 브라우저로 여세요. 필요한 그림7개, 전체88쌍, 결과와 해석, 문제·수정·한계, 중간MD14개를 파일 안에 내장했습니다. 최종 보고서 HTML은 한 개입니다.

- `data/raw`: 공개 XLSX 원본. 변경하지 않습니다.
- `docs`: 단계별10개·기기별4개 MD. 각 질문의 입력→방법→결과→검토→남은 한계를 보존합니다.
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
