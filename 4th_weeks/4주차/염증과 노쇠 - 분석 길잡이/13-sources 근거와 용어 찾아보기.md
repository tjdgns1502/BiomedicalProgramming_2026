---
tags:
  - 염증과노쇠
  - 학습안내
순서: 24
---

# 근거와 용어 찾아보기

[[00-start 처음부터 따라가는 분석 흐름|전체 흐름]]

## 가장 먼저 확인할 원문

| 자료 | 위치 | 이 학습자료에서 확인한 내용 |
|---|---|---|
| Han et al., BMC Public Health 2024;24:3408 | [논문 웹페이지](https://link.springer.com/article/10.1186/s12889-024-20908-9), [로컬 PDF](assets/paper.pdf) | 대상자, 변환, 회귀, 결과, Figures 1–3 |
| 원문 보충자료 | [로컬 DOCX](assets/supplement.docx) | 36항목 FI, S6–S7의 추가 보정, Figure S1 |
| 추출된 원문 페이지 | 각 figure 페이지에 포함 | 원문 번호와 문맥을 함께 확인 |

초기 원문 해설의 발표 수치는 논문에서 직접 읽어 옮겼습니다. 이후 공개 NHANES에서 명시한 FI 후보를 구성해 회귀와 보충 분석을 실행했으며, 그 결과는 각 paper 문서 3–6구역에 구분해 수록했습니다. 저자의 비공개 코드와 동일하게 실행했다고 주장하지 않습니다. 원문 페이지 이미지는 이전에 추출해 둔 파일을 사용했습니다. 가상 데이터는 설명용이며 임상 기준·실제 참여자·분석 결과를 대신하지 않습니다.

## 개념을 더 확인할 자료

후속 재구성에서 확인한 공식 자료와 주기별 규칙은 [출처 감사 기록](assets/V3-20260928T003525Z/source_audit.md)에 있습니다. 특히 [1999 PFQ 설문 분기](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/PFQ.htm#PFQ059A), [1999 식이 응답 상태 DRDDRSTS](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/DRXTOT.htm#DRDDRSTS), [2003년 2일 식이 자료와 가중치](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2003/DataFiles/DR2TOT_C.htm)를 확인했습니다. 이 코드북은 공개자료의 의미를 설명하며, 저자가 실제 사용한 비공개 코드 자체는 아닙니다.

- [Fried et al. — Frailty in older adults: evidence for a phenotype](https://pubmed.ncbi.nlm.nih.gov/11253156/): 신체적 노쇠의 5가지 기준과 분류. [원 연구 PDF](https://dms.ufpel.edu.br/static/bib/fried_frailty.pdf).
- [Schuster et al. — Noncollapsibility and its role in quantifying confounding bias](https://pubmed.ncbi.nlm.nih.gov/34225653/): 보정 전후 OR 변화와 교란의 구별.

- [Searle et al. — A standard procedure for creating a frailty index](https://pmc.ncbi.nlm.nih.gov/articles/PMC2573877/): FI의 결손 누적과 구성 원리.
- [How to construct a frailty index from an existing dataset in 10 steps](https://pmc.ncbi.nlm.nih.gov/articles/PMC10733590/): 항목 선정·코딩·검토 절차.
- [Altman & Royston — The cost of dichotomising continuous variables](https://pmc.ncbi.nlm.nih.gov/articles/PMC1458573/): 이분화에 따른 정보 손실.
- [CDC — NHANES sample design](https://wwwn.cdc.gov/nchs/nhanes/tutorials/SampleDesign.aspx): 표집 대상과 복합표본 설계.
- [CDC — NHANES weighting](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx): 가중치와 여러 조사 주기 결합.
- [CDC — Variance estimation](https://wwwn.cdc.gov/nchs/nhanes/tutorials/varianceestimation.aspx): 층화·군집과 표준오차.
- [Penn State — Logistic regression](https://online.stat.psu.edu/stat462/node/207/): 확률·로그오즈·모형 연결. 검색에 확인된 공개 강의 노트이며 직접 열기는 접속 오류가 있었음.
- [statsmodels — Pitfalls](https://www.statsmodels.org/stable/pitfalls.html): 공선성·분리·수렴과 식별 문제.
- [MedlinePlus — CRP](https://medlineplus.gov/lab-tests/c-reactive-protein-crp-test/): 무엇을 측정하는지와 원인 특이성의 한계.
- [MedlinePlus — ESR](https://medlineplus.gov/lab-tests/erythrocyte-sedimentation-rate-esr/): 적혈구 침강 검사의 의미.
- [NCI — IL-6](https://www.cancer.gov/publications/dictionaries/cancer-terms/def/il-6): 신호 단백질의 정의.

## 짧은 용어 사전

| 용어 | 여기서의 뜻 |
|---|---|
| 모집단 | 연구 질문을 적용하려는 사람들의 전체 집합 |
| 표본 | 실제 관측한 일부 사람들 |
| 변수 | 사람마다 값이나 범주가 기록되는 열 |
| 설명변수 X | 관계를 조사하는 관심 값 |
| 결과변수 Y | 모형이 설명하려는 결과 |
| 공변량 C | 모형에서 함께 고려하는 다른 특성 |
| 교란 | 다른 요인 때문에 관심 관계의 해석이 섞이는 문제 |
| 보정 | 선택한 변수들을 함께 고려하는 모형화 |
| 결측 | 관측 또는 기록되지 않은 값; 0과 다름 |
| 중앙값 | 정렬했을 때 가운데 위치 |
| P25·P75 | 누적분포의 25%·75% 위치 |
| IQR | P75−P25; 표에는 두 끝값을 적기도 함 |
| 사분위군 | 순서대로 약 25%씩 묶은 네 집단 |
| 오즈 | p/(1−p) |
| OR | 두 조건의 오즈를 나눈 값 |
| CI | 표본 변동에 따른 추정값의 불확실성을 표현하는 구간 |
| p값 | 귀무가설과 모형 아래 관측만큼 또는 더 극단적인 결과가 나올 확률 |
| 유병비 PR | 비교 시점에서 두 집단의 상태 보유 비율을 나눈 값 |
| 상호작용 | 한 변수의 연관성이 다른 변수의 수준에 따라 달라지는 현상 |
| 민감도 분석 | 분석 선택이나 가정을 바꿨을 때 결과의 안정성 점검 |

## 보고의 공백과 추가 제안을 구분하기

로그 밑, 일부 결측 처리, 통합 조사설계 설정, RCS 매듭·기준값, 추세 검정 구현 등은 원문 보고만으로 충분히 확인되지 않습니다. 지수 중복 항목 제외, 다른 FI 기준, 연속 FI 모형, PR 추정은 학습 자료의 추가 제안입니다. 저자가 실제로 수행했다고 서술하지 않았습니다.

---

[[12-reusable-prompt 다음 논문에도 사용할 요청 프롬프트|이전: 다음 논문에도 사용할 요청 프롬프트]]
