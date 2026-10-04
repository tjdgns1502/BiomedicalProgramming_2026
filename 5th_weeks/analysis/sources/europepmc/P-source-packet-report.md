# P 논문 출처 확보 및 독립 감사

조회일: 2026-10-04 (Asia/Seoul). 과제 지정 PMID 37308938과 원문이 일치한다.

## 공식 원문

- 제목: The association of periodontal disease and oral health with hypertension, NHANES 2009-2018.
- Li et al. BMC Public Health 23, 1122 (2023), DOI 10.1186/s12889-023-16012-z.
- [PubMed](https://pubmed.ncbi.nlm.nih.gov/37308938/)
- [출판사](https://link.springer.com/article/10.1186/s12889-023-16012-z)
- [EuropePMC 메타데이터 API](https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A37308938&format=json)
- [EuropePMC 원문 XML API](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10262359/fullTextXML)
- [EuropePMC 보충파일 ZIP API](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10262359/supplementaryFiles)

`europepmc_metadata.json`, `PMC10262359.fullText.xml`, `PMC10262359.supplementary.zip`은 공식 API 응답을 그대로 저장했다. 본문 PDF 후보에서 받은 HTML은 PDF로 표시하지 않았다. 원문 XML과 표 TSV는 확보했다. 임의 재조판 PDF를 원본으로 만들지 않았다.

## 보충 PDF 검증

파일: `supplementary/12889_2023_16012_MOESM1_ESM.pdf`

- PDF magic: `%PDF-`, 128533 bytes, 2 pages.
- MD5: `20dca1751450955a6992dccbccd59b8b` (원문 XML의 공식 MD5와 일치).
- SHA256: `3491386e3f09fbf2ebc32f78b15e6d582e6b0f977d036ac2d515dcb5ef330eeb`.
- 텍스트: `12889_2023_16012_MOESM1_ESM.txt`.
- 두 페이지를 PNG로 렌더링해 실제 표의 숫자, 제목, 각주와 추출 텍스트의 일치를 시각 확인했다. 원본 PDF는 변경하지 않았다.

## 모델을 표마다 구분

| 대상 | Model 1 | Model 2 추가 | Model 3 추가 |
| --- | --- | --- | --- |
| 본문 Table 2 | 나이, 성별, 인종, 교육 | BMI, 수면, 음주, 활동, CVD, 당뇨, 나트륨, 지방 | TC, creatinine, TG, HbA1c, HDL |
| 본문 Table 3 | 성별, 인종, 교육 | BMI, 수면, 음주, 활동, 흡연 | TC, creatinine, TG, HbA1c, HDL |
| 보충 I, II | 나이, 성별, 인종, 교육 | BMI, 수면, 음주, 활동 | TC, creatinine, TG, HbA1c, HDL |

각주 그대로의 차이이다. 본문 Table 2 설정을 Table 3/보충표에 재사용하면 원문과 다른 모델이 된다. Table 3은 <45와 >=45 집단 내 연속 나이 보정을 각주에 적지 않았다.

## 보충표 I: undiagnosed hypertension

| 범주 | cases/total | M1 OR (95% CI) | M2 | M3 |
| --- | --- | --- | --- | --- |
| Excellent/Very good | 499/4083 | 1 | 1 | 1 |
| Good | 553/4332 | 1.14 (0.95-1.38) | 1.15 (0.95-1.39) | 1.13 (0.92-1.39) |
| Fair | 382/2756 | 1.34 (1.09-1.65) | 1.33 (1.08-1.64) | 1.30 (1.05-1.61) |
| Poor | 194/1240 | 1.44 (1.06-1.96) | 1.39 (1.03-1.88) | 1.42 (1.04-1.93) |
| PD No | 1344/10222 | 1 | 1 | 1 |
| PD Yes | 284/2189 | 0.89 (0.74-1.08) | 0.88 (0.73-1.05) | 0.88 (0.73-1.06) |

구강상태 p-trend: <0.001 / 0.002 / 0.003; PD p-trend: 0.222 / 0.135 / 0.159.

## 보충표 II: physician diagnosed and treated hypertension

| 범주 | cases/total | M1 OR (95% CI) | M2 | M3 |
| --- | --- | --- | --- | --- |
| Excellent/Very good | 2686/6270 | 1 | 1 | 1 |
| Good | 3204/6983 | 1.25 (1.12-1.38) | 1.19 (1.07-1.32) | 1.17 (1.04-1.31) |
| Fair | 2238/4612 | 1.50 (1.33-1.70) | 1.43 (1.27-1.64) | 1.39 (1.21-1.59) |
| Poor | 1261/2307 | 1.93 (1.64-2.26) | 1.81 (1.52-2.15) | 1.66 (1.38-1.99) |
| PD No | 7495/16373 | 1 | 1 | 1 |
| PD Yes | 1894/3799 | 1.44 (1.31-1.59) | 1.42 (1.28-1.56) | 1.37 (1.24-1.53) |

구강상태/PD p-trend: 세 모델 모두 <0.001.

## 분모 검산과 해석

보충 I 전체: 12411명, cases 1628명, controls 10783명. 보충 II 전체: 20172명, cases 9389명, controls 10783명. 각 표의 cases 합은 본문 고혈압 11017명과 일치한다. 두 보충표가 같은 비고혈압 controls를 공유한다는 것은 표 수치에서 도출한 추론이며, 코드 미공개 상태에서 확정 구현이라고 주장하지 않는다. 같은 N=21800에서 outcome만 바꿔 두 회귀를 수행하는 방식과 분모가 다르다.

보충PDF에는 표와 모델 각주만 있다. 별도의 선정/제외 설명은 없다. 본문 Methods는 측정값만으로 정의한 고혈압과 의사진단 또는 치료로 정의한 고혈압의 민감도 분석을 했다고 설명한다. 보충 II 제목의 “and”를 논리적 AND 구현으로 단정하지 않는다. I이 진단/치료군을 제외하고 II가 측정값만 양성인 미진단군을 제외한다는 규칙은 `source_fact_type=analyst_inference`로 관리한다.

Table 1의 고혈압 남녀 표기 5412+5606=11018은 전체 11017과 1명 불일치한다. 이 불일치는 PDF 검색 텍스트와 공식 XML에 모두 존재한다. 원문 수치를 임의 보정하지 않고 재현 차이로 기록한다.

Table 1 당뇨 `Yes 874/2872, No 732/1232, Missing 9177/6913`은 DIQ010의 정상 응답 분포와 맞는지 독립 raw data 감사가 필요하다. DIQ050나 DIQ070 등 구조적 skip과 관련 있다는 주장은 아직 검증되지 않은 가설이다.

원문 치주질환은 OHQ835 자가보고이다. 임상 치주측정 지표로 바꾸면 별도 확장분석이 된다. `Model 1`은 crude가 아니다.

## 미공개 구현 및 가중치 근거

- OHQ835/845는 CDC 코드북으로 확인했다. [OHQ_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/OHQ_F.htm), [OHQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/OHQ_J.htm).
- BPQ050A는 skip으로 결측이 많으므로 완전 사례 조건을 무조건 적용하면 안 된다. [BPQ_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/BPQ_F.htm).
- TG `LBXTR`(TRIGLY, fasting)와 `LBXSTR`(BIOPRO) 선택이 원문에 공개되지 않았다. [TRIGLY_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/TRIGLY_F.htm), [BIOPRO_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/BIOPRO_F.htm).
- 식이 sodium/fat은 day 1 또는 day 2/양일 선택에 따라 변수와 가중치가 달라진다. [DR1TOT_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/DR1TOT_F.htm).
- 가중치 공식: MEC 기본 WTMEC2YR/5, day 1 WTDRD1/5, fasting TG WTSAF2YR/5. [CDC Weighting](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).
- 수면은 SLD010H(F/G/H)에서 SLD012(I/J)로, 음주는 ALQ120Q/U에서 ALQ121(J)로 바뀐다. [SLQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/SLQ_J.htm), [ALQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/ALQ_J.htm).
- 흡연, active/inactive, CVD/diabetes, 연속 결측값 대치 및 indicator 구현은 원문 미공개다. 원문과 동일한 숫자가 나오더라도 코드 공개 검증과 구분한다.
