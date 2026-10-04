# 오즈비와 보정 모형 — 논문 적용

## 처음의 논문 설명과 남겨 둔 의문

Table2 Model1은 나이·성별·인종·교육을 보정합니다. 치주질환 Yes의 출판 OR는 M1 1.35(1.22–1.49), M2 1.20(1.08–1.34), M3 1.21(1.09–1.35)입니다. 첫 모형을 crude로 부르면 안 됩니다.

M2는 BMI·수면·음주·활동·CVD·당뇨·나트륨·지방을 추가하고 M3는 TC·creatinine·TG·HbA1c·HDL을 추가합니다. 결측은 범주/지시변수로 처리했다고 쓰지만 연속값 대체 규칙은 미공개입니다. Table3 각주는 다르게 구성되어 별도로 검토합니다.

**ISSUE-07:** 숨은 공변량 구현/가중치/결측 처리(replication_config). **ISSUE-08:** 교란·측정오류·역인과·비축약성(statistical_validity). 출판값에 가까운 후보를 통계적 개선으로 선택하지 않습니다.

근거: [논문 Methods·Tables](https://link.springer.com/article/10.1186/s12889-023-16012-z), [CDC 가중치 지침](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx).

## 구현

R-CAT-001 / `R2-20261004` / plan1.1 → R-EXT-002 / `E1-20261004` / plan1.4 → R-REPAIR-003 / `E2-20261004` / plan1.5. 주 후보 21,458명(고혈압10,689, 비고혈압10,769)를 공통 분모로 사용합니다. 상류 core 자료해시를 확장 실행이 확인하고 동일 사람의 코딩을 재사용했습니다. E1 원시 검사값 실행을 보존하고 E2에서 CDC 검사법 보정을 적용했습니다. 영향을 받지 않는 M1/M2의 재사용 출처와 모든 M3 하류 재계산을 기록했습니다.

A는 MEC/5 후보, B는 식이 day1 가중치 민감도입니다. TG는 BIOPRO의LBXSTR 후보이며 일반 TG 분석에서 권고되는 referenceLBXTR와 다릅니다. [CDC BIOPRO_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm)의 검사법 변경 권고에 따라 J 주기 크레아티닌은 1.051×원값−0.06945, TG는 0.9655×원값−7.020으로 이전 주기 척도에 맞췄습니다. 원값은 보존하고 결측 대체 전에 적용했습니다. 저자가 같은 보정을 했는지는 미확인입니다. 수면0.5시간을 보존하고 음주 주기별 문항변경을 조정했습니다. 식·표본·자유도·수렴은 [모형별 기록](../analysis/runs/E2-20261004/tables/model_sample_counts_formulas.csv)에 있습니다.

본문 Table2 M2와 Table3 M2, 보충표 M2는 서로 다른 변수를 보정했습니다. 보충 I는 진단/치료 음성인 사람의 측정고혈압 vs 정상, II는 진단/치료 고혈압 vs 원래 비고혈압으로 후보집단을 만들었습니다. 공개분모를 근거로 추론한 선정이므로 author-code-verified라고 표시하지 않습니다.

## 재현 비교

| 모형 | 대비 | 논문 OR (95%CI) | 계산 OR (95% t CI) | OR 차이 |
| --- | --- | --- | --- | --- |
| Model1 | oral_healthGood | 1.23 (1.12–1.35) | 1.218 (1.109–1.337) | -0.012 |
| Model2 | oral_healthGood | 1.14 (1.03–1.26) | 1.121 (1.017–1.237) | -0.019 |
| Model3 | oral_healthGood | 1.13 (1.02–1.27) | 1.125 (1.018–1.243) | -0.005 |
| Model1 | oral_healthFair | 1.48 (1.32–1.65) | 1.463 (1.301–1.646) | -0.017 |
| Model2 | oral_healthFair | 1.32 (1.17–1.49) | 1.297 (1.151–1.461) | -0.023 |
| Model3 | oral_healthFair | 1.30 (1.15–1.47) | 1.297 (1.154–1.457) | -0.003 |
| Model1 | oral_healthPoor | 1.84 (1.58–2.15) | 1.815 (1.550–2.124) | -0.025 |
| Model2 | oral_healthPoor | 1.49 (1.24–1.79) | 1.480 (1.247–1.756) | -0.010 |
| Model3 | oral_healthPoor | 1.48 (1.22–1.79) | 1.474 (1.235–1.758) | -0.006 |
| Model1 | periodontalYes | 1.35 (1.22–1.49) | 1.343 (1.218–1.482) | -0.007 |
| Model2 | periodontalYes | 1.20 (1.08–1.34) | 1.224 (1.100–1.363) | +0.024 |
| Model3 | periodontalYes | 1.21 (1.09–1.35) | 1.227 (1.103–1.366) | +0.017 |

| 표/집단 | 대비 | 논문 M3 OR | 계산 M3 OR (95% t CI) |
| --- | --- | --- | --- |
| table2/Non-Smoking | oral_healthGood | 1.12 | 1.101 (0.982–1.235) |
| table2/Non-Smoking | oral_healthFair | 1.49 | 1.467 (1.262–1.705) |
| table2/Non-Smoking | oral_healthPoor | 1.62 | 1.672 (1.301–2.149) |
| table2/Smoking | oral_healthGood | 1.13 | 1.125 (0.962–1.315) |
| table2/Smoking | oral_healthFair | 1.11 | 1.099 (0.922–1.310) |
| table2/Smoking | oral_healthPoor | 1.31 | 1.279 (1.025–1.597) |
| table2/Non-Smoking | periodontalYes | 1.22 | 1.217 (1.017–1.456) |
| table2/Smoking | periodontalYes | 1.16 | 1.180 (1.005–1.385) |
| table3/30-44 | oral_healthGood | 1.11 | 1.096 (0.919–1.307) |
| table3/30-44 | oral_healthFair | 1.27 | 1.288 (1.076–1.543) |
| table3/30-44 | oral_healthPoor | 1.71 | 1.608 (1.200–2.155) |
| table3/45+ | oral_healthGood | 1.10 | 1.084 (0.971–1.211) |
| table3/45+ | oral_healthFair | 1.25 | 1.207 (1.037–1.405) |
| table3/45+ | oral_healthPoor | 1.29 | 1.256 (1.041–1.517) |
| table3/30-44 | periodontalYes | 1.51 | 1.462 (1.212–1.764) |
| table3/45+ | periodontalYes | 1.05 | 1.058 (0.931–1.204) |
| supplement_measured/Overall | oral_healthGood | 1.13 | 1.114 (0.913–1.360) |
| supplement_measured/Overall | oral_healthFair | 1.30 | 1.271 (1.027–1.572) |
| supplement_measured/Overall | oral_healthPoor | 1.42 | 1.359 (1.016–1.817) |
| supplement_measured/Overall | periodontalYes | 0.88 | 0.828 (0.678–1.011) |
| supplement_diagnosed_treated/Overall | oral_healthGood | 1.17 | 1.151 (1.034–1.283) |
| supplement_diagnosed_treated/Overall | oral_healthFair | 1.39 | 1.368 (1.198–1.562) |
| supplement_diagnosed_treated/Overall | oral_healthPoor | 1.66 | 1.619 (1.340–1.957) |
| supplement_diagnosed_treated/Overall | periodontalYes | 1.37 | 1.377 (1.242–1.528) |

모든 M1–M3와 출판 OR/CI 비교는 [전체 수치 비교](../analysis/comparisons/E2-20261004/all_published_OR_comparisons.csv)입니다. OR/CI 반올림 허용오차0.005, 정수 n 오차0을 실행 전에 고정했습니다. 분석집단과 숨은 설정이 다르므로 가까운 숫자도 정확 재현으로 승격하지 않습니다.

## 검토·추가 분석

![[assets/E2-20261004/A_model1_3_forest.png]]

A 주 후보 21,458명. 치주질환 Yes vs No와 구강상태 각 범주 vs Excellent/Very good. M1/M2/M3의 보정범위는 본문 Table2 각주, 95%CI는 survey t 자유도입니다.
![[assets/E2-20261004/B_model1_3_forest.png]]

B: 식이 응답 및 식이 day1 가중치를 반영한 민감도 분석. A와 동일 분모로 읽으면 안 됩니다. 모형별 n을 위 기록에서 확인합니다.

| 후보 | 노출 | 수정요인 | joint Wald p |
| --- | --- | --- | --- |
| A | periodontal | smoking | 0.702667 |
| A | oral_health | smoking | 0.0250438 |
| A | periodontal | age_group | 0.00187615 |
| A | oral_health | age_group | 0.317545 |
| B | periodontal | smoking | 0.189188 |
| B | oral_health | smoking | 0.010247 |

상호작용은 한 층의 유의/다른 층의 비유의 차이가 아니라 joint Wald로 확인했습니다. 원문의 interaction값과 다르더라도 모델·설계·표본 및 숨은 설정 차이가 있으므로 논문 오류로 단정하지 않습니다.

## 갱신된 해석

ISSUE-07 미해결/부분 재현: 연속결측 대체, TG, 활동, 음주, 당뇨, 식이·측정의 저자 세부 구현을 유일하게 식별하지 못했습니다. ISSUE-08 조건부 지지: 후보 데이터에서 연관을 추정했으며 잔여 교란·역인과·측정오류·결측 지시변수 편향의 한계를 유지합니다. Table3의 나이군 내부 연령은 각주처럼 연속 보정하지 않아 잔여 교란이 남을 수 있습니다.

반영 시점: 2026-10-04T08:05:56.540689+00:00. 자료 버전 `nhanes-2009-2018-harmonizedJ-d8f04b7c96c89c31956a`; core는 `nhanes-2009-2018-7ad570c1e84a460b267c`.


보충집단 분모: I 12,401명(측정 고혈압1,632, 비고혈압10,769), II 19,815명(진단/치료9,046, 비고혈압10,769)입니다. 주 분석 고혈압10,689명 중 진단·복약 상태 미확인인 측정 고혈압11명은 두 보충집단에서 제외됩니다. 보충 case 두 수를 더하면10,678이며 주 분석과 같은 양성분모가 아닙니다. 독립 자료 감사에서 확인한 차이를 숨기지 않습니다.

전체 기준범주를 포함한 [Table2/3 수준별 분모 비교](../analysis/comparisons/E2-20261004/table2_3_all_level_population_comparison.csv)와 [출판 추세 p 비교](../analysis/comparisons/E2-20261004/published_trend_p_comparisons.csv)를 확인할 수 있습니다.

출판 상호작용 p와 후보 joint Wald의 [비교표](../analysis/comparisons/E2-20261004/published_interaction_p_comparisons.csv)를 별도로 연결합니다. 출판 OR 84행 중 선언한 OR 오차 안의 행은 7행이며, 이것만으로 정확 재현을 판정하지 않습니다.

모형 공식과 실제 계수 열의 구분: B의 식이 domain에서는 sodium_missing와 fat_missing가 모두0이므로 해당 지시변수는 공식에 있어도 계수 추정에서 제외됩니다. 상수·공선성 열의 제외는 모형 행렬의 rank와 자유도에 반영됩니다. svyglm의 aliased metadata 빈 배열만으로 제외가 없다고 결론내리지 않고 독립 수치 감사의 제외 목록을 확인합니다.

E2 독립 검토: 자료·변환·연계·점추정 380개와 새 모형 수치 371개 점검을 통과했습니다. 자료 검토는 모델 추론의 승인과 구분하며, 수치 검토의 승인이 저자 설정을 확인했다는 의미는 아닙니다.
