# 7주차: 로지스틱 회귀와 진단 성능

[최종 분석 보고서](최종분석보고서.html)는 단일 파일로 열 수 있다. [학습 길잡이](근감소증과%20인체계측%20-%20분석%20길잡이/00-start%20처음부터%20따라가는%20분석%20흐름.md), [논문 근거](논문%20근거.md), [독립 검토](analysis/독립검토.md), [최신 실행 프롬프트](실행%20설계/전체실행프롬프트-v2.1-7주차.md)도 제공한다. 논문은 Wu et al. 2024, DOI [10.1038/s41598-024-82751-7](https://doi.org/10.1038/s41598-024-82751-7).

현재 결과는 공개 NHANES 자료의 **후보 분석**이다. 공통 완전사례 8,086명은 논문의 8,159명과 다르고, 건강 변수의 대체 정의와 저자의 모형·분할·가중치 미보고 때문에 정확 재현이라고 주장할 수 없다. 식이 가중치 및 층·PSU 선형화 분산을 적용했다. 직접 지표 ROC는 저자의 단계적 회귀 예측모형과 동일하지 않다. 논문 Table 4에는 컷오프 수치가 없고, 보고서 컷오프는 후보 추정치다. 외부 패키지와의 분산 대조, ROC 신뢰구간 및 BIA 별도 검증은 미완료다.

## 원자료와 재실행

원자료 XPT 및 참가자 단위 파생 CSV는 저장소에 포함하지 않는다. `analysis/data/nhanes_sources.json`은 CDC 공식 URL과 사용한 원본 SHA256을 기록한다. 아래 명령은 이 폴더에서 실행한다. 기존 raw 파일의 해시가 다르면 덮어쓰지 않고 중단한다.

```powershell
uv run analysis/src/download_nhanes.py
uv run --with pandas --with numpy --with pyreadstat -- python analysis/src/covariates.py
uv run --with pandas --with scipy --with scikit-learn --with statsmodels --with matplotlib --with pyreadstat -- python analysis/src/candidate.py --run-id candidate-new
```

`candidate-new`는 사용하지 않은 새 run ID로 바꾼다. 이미 존재하는 run을 덮어쓰지 않는다. CDC 파일이 개정되어 해시가 달라지면 이전 분석과 동일한 입력이 아니므로 출처와 차이를 조사한다. `analysis/runs/candidate_20261108_v2`는 보고서에 사용한 기존 결과이며 `candidate_20261108`은 실패 실행을 보존한 것이다. `analysis/src/initial.py`는 과거의 예비 탐색 코드로, 다른 주차 경로에 의존하고 위 재현 경로의 일부가 아니다.

## 이전 검토와 이식 변경

`analysis/src/history/candidate_reviewed.py`는 독립 검토 당시의 원본 코드(SHA256 `82cef63aea802c219df2a5bd24febe74fd2c6ca11e341925c5e8ee98524123fd`)다. 저장소의 `analysis/src/candidate.py`는 5주차 외부 경로 대신 7주차 raw 경로를 쓰고 새 `--run-id`를 받도록 이식한 코드다. 기존 독립 검토는 이식본에 대한 새로운 독립 통계 검증이 아니다. 원본의 출력·분석 설정은 변경하지 않았다.

2026-11-08에 원자료 32개의 SHA256을 검증하고 그중 DXX_G는 CDC에서 새로 받아 확인했다. 공변량 생성 결과 39,156행의 CSV 해시는 기존과 일치했고, 이식본으로 별도 실행한 선정표 4행, 회귀표 30행, ROC표 10행은 기존 결과와 수치 최대 절대차 0이었다. 별도 검증 run은 저장소에 포함하지 않는다. 이는 동일 환경에서의 재실행 확인이며, 저자 방법의 정확성이나 독립적인 새로운 표본 검증이 아니다.
