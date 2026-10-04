# 확장 변수 정의의 독립 출처 감사

검토자: 논문 출처 확보 담당 P 및 별도 구현 인스턴스에 대한 Q-data. 발표된 목표 수치에 노출되었다. 내부 독립 검토이며 외부·블라인드 검증은 아니다. 구현 파일을 source하거나 모델을 재적합하지 않는다.

## 공식 변수와 단위

| 분석 변수 | 공식 변수 및 단위 | 확인 |
| --- | --- | --- |
| BMI | BMXBMI, kg/m² | <18.5 / 18.5–<25 / 25–<30 / ≥30 후보 분류 |
| 수면 | F–H SLD010H; I–J SLD012, 시간 | I–J 반시간 소수값 유지. 두 시기 질문과 산출 방식은 다름 |
| 음주 | F–I ALQ120Q/U·ALQ130; J ALQ111/121·ALQ130 | 주당 빈도×음주한 날의 평균 잔 수를 사용한 후보 |
| 활동 | PAQ605/620/635/650/665 | 업무·이동·여가 질문 중 하나라도 Yes이면 Active, 전부 No일 때 Inactive |
| CVD | MCQ160B/C/D/E/F | 하나라도 Yes이면 Yes, 전부 No일 때 No인 후보 |
| 당뇨 | DIQ010 | 1 Yes, 2 No. 3 borderline은 별도 원시 상태로 감사하고 모델에서는 Missing |
| sodium | DR1TSODI, mg | Day1 회상 영양소 |
| fat | DR1TTFAT, g | Day1 회상 영양소 |
| total cholesterol | LBXTC, mg/dL | TCHOL 참조법 결과 |
| creatinine | LBXSCR, mg/dL | BIOPRO 검사 |
| triglycerides | LBXSTR, mg/dL | BIOPRO 후보; CDC 권고 참조법 LBXTR과 다름 |
| HbA1c | LBXGH, % | 원 논문 mg/dL 표기와 단위가 다름 |
| HDL | LBDHDD, mg/dL | HDL 참조법 결과 |

출처: [BMX_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BMX_J.htm), [SLQ_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/SLQ_F.htm), [SLQ_I](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/SLQ_I.htm), [ALQ_F](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2009/DataFiles/ALQ_F.htm), [ALQ_I](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/ALQ_I.htm), [ALQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/ALQ_J.htm), [PAQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/PAQ_J.htm), [MCQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/MCQ_J.htm), [DIQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DIQ_J.htm), [DR1TOT_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DR1TOT_J.htm), [TCHOL_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/TCHOL_J.htm), [GHB_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/GHB_J.htm), [HDL_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/HDL_J.htm).

## 코드 처리와 분석자 가정

SLD012는 평일/근무일 주된 수면의 시작·종료 시간에서 산출되고 반시간 단위로 반올림된다. 낮잠을 합친 24시간 총수면으로 해석하지 않는다. 소수값을 유효한 연속 범위로 받아야 한다. 과거 직접 응답 SLD010H와의 통합은 측정의 완전한 동일성을 보장하지 않는다. [SLQ_I](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/SLQ_I.htm)

ALQ는 2017–2018에 질문 체계가 바뀌었다. J ALQ111=2는 평생 음주 없음, ALQ121=0은 지난 1년 음주 없음이다. F–I ALQ120Q=0도 직접 응답한 비음주 빈도이다. F–I ALQ101=2 및 ALQ110=2는 평생 12잔 미만이므로 정확한 금주와 같지 않다. 이를 No drinks로 묶는 E1 규칙은 명시된 근사 가정이다. J의 구간 빈도를 연간 대표값으로 치환하는 것도 분석자 가정이다. ALQ130의 15는 I–J에서 15잔 이상이라는 상한 범주이며, 777/999는 수량이 아니다. [ALQ_I](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/ALQ_I.htm), [ALQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/ALQ_J.htm)

DIQ010=3 borderline, 7 refused, 9 unknown 및 질문 부재를 원시 상태별로 구분하여 감사한다. 원 논문 Table1 diabetes의 대규모 Missing은 실제 변수 매핑이 공개되지 않아 해소되지 않았다. DIQ050/DIQ070 분포 대조가 비슷하더라도 매핑을 입증하지 않는다. 논문 수치를 맞추기 위한 변수 변경은 하지 않는다. [DIQ_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DIQ_J.htm)

중앙값 채움과 결측 지시자는 저자 구현이 아닌 분석자 가정이다. E1은 core 분석 domain의 관측값 중앙값을 사용한다. 이는 결측의 원인을 복원하거나 편향을 제거한다는 보장이 아니다.

## A/B 가중치

Day1 영양자료를 MEC 자료와 함께 사용하는 분석에는 WTDRD1이 권고된다. 이는 추가 미응답과 회상 요일의 차이를 반영한다. B는 양수 WTDRD1/5 전체 모집단에서 설계를 만들고, 이후 core domain·DR1DRSTZ=1·관측 sodium/fat를 선택해야 한다. DR1DRSTZ=1은 회상의 신뢰성과 최소 기준 충족을 의미한다. A의 MEC/5 후보와 B의 식이 가중 민감도를 동일한 통계 모집단으로 묘사하지 않는다. [DR1TOT_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DR1TOT_J.htm)

## 검사 주기 간 보정과 E1/E2 범위

BIOPRO_J는 2017–2018 검사 장비 변화에 따른 주기 통합 보정식을 권고한다. J 값을 이전 장비 척도로 변환하는 역방향 점추정식은 다음과 같다.

- 크레아티닌: `1.051 × LBXSCR − 0.06945` mg/dL.
- 중성지방: `0.9655 × LBXSTR − 7.020` mg/dL.

E1의 원시값 후보 회귀 계산 자체를 무효라고 판단하지 않는다. 다만 이를 CDC 권고에 따라 검사 주기를 조화한 통합 분석이라고 승인할 수 없다. E1은 원시 검사값 후보로 보존한다. 주기 보정을 적용한 E2를 주된 조화 후보로 사용한다는 프로젝트 결정을 따른다. 원시값은 별도로 보존하고, J 변환을 중앙값 채움 전에 적용하며, M3·M3 기반 추세·상호작용·보충표·검사값 Table1·forest를 같은 새 자료 버전에서 다시 계산해야 한다. M1/M2 재사용은 입력 변수와 domain의 불변성 및 출처를 확인해야 한다. [BIOPRO_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm)

E2 역시 비공복 BIOPRO TG 선택, 미공개 저자 정의, 결측 처리 가정을 해소한 완전한 검증은 아니다. TCHOL_J와 HDL_J는 해당 주기 검사 방법·장비·기관 변화가 없다고 설명하므로 이 두 BIOPRO 변수의 변환을 TC/HDL에 적용하지 않는다. [TCHOL_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/TCHOL_J.htm), [HDL_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/HDL_J.htm)

## R2 약 복용 결측 처리의 추가 강건성 확인

R2 master.rds를 읽어 확인한 BPQ050A raw 7/9는 전체 2명, 분석 domain 1명이다. 이 중 medication_structural_no로 재분류된 사람은 전체 및 domain 모두 0명이다. 현재 자료의 결과에는 영향이 없다. 향후 입력에서 구조적 건너뛰기와 7/9가 충돌하면 실제 raw NA에만 구조적 No 규칙을 적용하는 guard가 강건하다. 이 수는 원시 코드와 frozen R2 파생값을 대조한 내부 QA 사실이다.

## 원문 Table1의 별도 출처 감사

원문 Table1 고혈압군은 총 11,017명으로 표기된다. 같은 열의 Male 5,412명과 Female 5,606명은 합계 11,018명으로 총계보다 1명 많다. 공개 원문 웹 표와 EuropePMC 공식 full-text XML에서 동일하게 읽힌 값이다. 여기서 확인한 사실은 표 내 산술 불일치이며, 어떤 셀이나 총계를 고쳐야 하는지는 저자 정정·코드 없이 결정하지 않는다. 현재 후보 자료를 이 차이에 맞춰 변경하지 않는다. [논문 원문, Table1](https://link.springer.com/article/10.1186/s12889-023-16012-z), [EuropePMC 공식 XML](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC10262359/fullTextXML)

원문 diabetes는 비고혈압/고혈압 순으로 Yes 874/2,872, No 732/1,232, Missing 9,177/6,913이다. DIQ010 기반 후보의 Yes·No·borderline·unknown 분포와 크게 다르다. DIQ070의 질문 건너뛰기 때문에 큰 결측이 발생하는 구조는 비슷하지만, 후보의 DIQ070 Yes 630/2,066, No 972/1,898, Missing 9,166/6,719도 원문과 일치하지 않는다(추가 special code 1/6명은 별도). 변수 이름을 확정하거나 저자 코딩 오류로 단정하지 않는다. 해당 차이는 미해결 구현 질문으로 유지한다. [논문 Table1](https://link.springer.com/article/10.1186/s12889-023-16012-z), [DIQ_J 공식 코드북](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DIQ_J.htm)
