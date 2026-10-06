# 5주차 — 범주형 자료와 분할표

NHANES 2009–2018 치주질환·구강건강과 고혈압 논문의 부분 재현 및 범주형 통계 검증 과제입니다. 기존 v2.0 실행 흐름에 따라 이론·논문 적용·의문·R 구현·독립 검토·결과 해석을 연결했습니다.

논문: Li et al. (2023), *The association of periodontal disease and oral health with hypertension, NHANES2009–2018*. [공식 원문](https://link.springer.com/article/10.1186/s12889-023-16012-z), DOI 10.1186/s12889-023-16012-z, PMID 37308938. 자가보고 구강건강 자료를 사용한 횡단면 연구입니다.

## 먼저 읽기

- [분석 과정·프롬프트·문제·한계 HTML](analysis-process.html): 2026-10-06 후속 설명 자료. plot 10개 내장, 의문 펼치기·인쇄 기능. 다운로드 후 브라우저로 열어 읽습니다.
- [학습 문서 시작](치주질환과%20고혈압%20-%20분석%20길잡이/00-start%20처음부터%20따라가는%20분석%20흐름.md)
- [R 코드·재실행 안내](analysis/README.md)
- [원본 실행 프롬프트](실행%20설계/05-prompts-v2.0-original.md)와 [5주차 실행 규칙](실행%20설계/05-prompts-week5.md)
- [최종 학습 문서 독립 검토](analysis/reviews/final-learning-note-review.json)

## 현재 결과와 그림

- R2: 분할표, Pearson·Yates·Fisher·Rao–Scott 검정 및 Model 1. [표·그림](analysis/runs/R2-20261004/)
- E1: 검사값 보정 전 진단 기록과 M1/M2 재사용 출처. [기록](analysis/runs/E1-20261004/)
- E2: CDC의 2017–2018 검사법 보정을 반영한 현재 A/B 후보. [Table 1–3·보충 분석·비교](analysis/runs/E2-20261004/), [논문 수치 비교](analysis/comparisons/E2-20261004/)
- V1: Fisher 검정의 실제 유의수준·검정력, OR/PR 비교, 짝지음 McNemar 검증. [결과](analysis/runs/V1-20261004/)

학습 문서에 연결된 plot PNG 10개를 모두 포함합니다: [이미지 폴더](치주질환과%20고혈압%20-%20분석%20길잡이/assets/). Mosaic/Pearson 잔차, forest plot, 검정 크기·검정력 및 OR/PR 곡선이 있습니다.

**재현 판정은 부분 재현입니다.** 현재 기본 분석 표본은 21,458명으로 논문 21,800명과 다르며 미공개 코딩·결측 설정이 남아 있습니다. 독립 검토는 계산 검산과 문서 일관성을 확인했으며 저자의 분석 설정을 완전히 복원했다는 뜻은 아닙니다. 논문 수치를 본 상태에서 구현·검토했으므로 맹검 분석으로 주장하지 않습니다. 이전 실패 실행과 보정 전 결과는 기록으로 보존합니다.

## 공유 범위와 재실행

이 폴더는 기존 로컬 분석을 공유한 스냅샷입니다. R 코드, 설정, 집계 표, 모든 분석 plot, 학습 문서 및 검토·환경·실행 기록을 포함합니다. 원자료 XPT, 개인별 파생 CSV, RDS 모형·중간객체, 설치된 R 패키지, uv 캐시 및 강의 파일·다운로드 캐시는 제외했습니다. 학습 문서에서 참조하는 CC BY 4.0 논문 XML·보충자료는 링크 유지를 위해 포함합니다. 원자료는 분석 코드가 공식 NHANES URL에서 내려받습니다. 논문·보충자료는 위 공식 원문에서 확인하세요.

저장소 루트에서 `5th_weeks/`로 이동해 `analysis/README.md`를 따릅니다. R 4.6.1, survey 4.5, haven 2.5.5, jsonlite 2.0.0, digest 0.6.39를 사용했습니다. R 패키지는 별도로 설치해야 하며 다른 컴퓨터에서 전체 재실행을 검증한 패키지는 아닙니다. Python 스크립트는 `uv run`으로 실행합니다.

과거 로그·검토·원본 manifest는 실행 당시의 로컬 절대경로와 제외된 원자료·중간파일의 해시를 포함합니다. 해당 기록은 당시 결과의 증거로 보존하며 새 체크아웃 경로로 일괄 수정하지 않습니다. 학습 문서의 이미지·분석 결과 링크는 상대경로입니다. 원본 `analysis/final_bundle_manifest.json`은 전체 로컬 산출물 기준이고, **실제 GitHub 공유 파일 목록과 해시는 [publication_manifest.json](publication_manifest.json)**에 있습니다.

HTML 재생성: `uv run analysis/src/build_analysis_process_html.py .` (5th_weeks에서 실행). [근거·검토 기록](analysis/documentation/html-explainer-20261006/)을 함께 보관했습니다. 재생성으로 HTML 해시가 달라지면 기존 문서 검토의 적용 범위를 다시 확인해야 합니다.
