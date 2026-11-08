# 공변량 후보 생성 기록

`uv run --with pandas --with numpy --with pyreadstat -- python analysis/src/covariates.py`로 재생성한다. NHANES 2011–2018 원본의 `SEQN`을 one-to-one으로 결합하며 원본 경로·공식 URL과 SHA-256은 `covariates_sources.json`에 있다. 출력 `covariates_candidate.csv`는 전체 조사 참가자 39,156명이며, 분석 대상 선정은 별도로 적용해야 한다.

| 출력 | 원자료와 후보 코딩 |
|---|---|
| age, sex, race | RIDAGEYR, RIAGENDR, RIDRETH3 |
| education | DMDEDUC2 중 1–5만 사용; 거절·모름은 결측 |
| poverty | INDFMPIR 연속값; 범주화는 별도 근거 확인 필요 |
| diabetes_self_report | DIQ010의 1=1, 2·3=0, 그 외 결측. 경계성 3은 진단 당뇨가 아니라고 분류하는 후보 |
| hypertension_self_report | BPQ020 1=1, 2=0, 그 외 결측 |
| cholesterol_self_report | BPQ080 1=1, 2=0, 그 외 결측 |
| inactivity | PAQ605–675의 활동에 8 또는 4 MET를 곱한 주당 총량이 600 미만이면 1. 활동 없음은 0분, 거절·모름·활동량 계산 불가는 결측. 논문과 동일 여부 미확인 |
| sedentary | PAD680 분을 <4, 4–<6, 6–<8, ≥8시간으로 구분. 경계값 처리의 논문 일치 여부 미확인 |
| energy, protein | 1·2일 회상 상태가 모두 신뢰 가능(각 DRxDRSTZ=1)할 때 2일 수치 평균. kcal/일, g/일 |
| weight_mec, weight_diet2 | 각각 WTMEC2YR/4, WTDR2D/4. 두 날 식이 분석에는 CDC가 2일 식이 가중치 권고; 저자의 실제 선택은 미확인 |
| SDMVSTRA, SDMVPSU | 원자료 가상 층과 PSU. 복합표본 분석에 함께 사용 |

세 자가보고 변수는 논문의 고혈당·고혈압·고콜레스테롤 정의에 대한 **대체 후보**이며 임상 측정·약물·진단 조합과 동일하다고 간주하면 안 된다. 본 자료만으로 저자의 모델 3을 재현했다고 판단하지 않는다. 데이터와 결과의 독립 검토는 받지 않았다. 참고 코드북: [PAQ](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2011/DataFiles/PAQ_G.htm), [식이가중치](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx), [식이자료](https://wwwn.cdc.gov/nchs/NHANES/tutorials/dietaryanalyses.aspx).
