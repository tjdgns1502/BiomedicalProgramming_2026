# E2 부분 검사 조화 후보의 독립 자료 검토

**decision: accept — 380개 점검 모두 통과.** 승인 범위는 E1 기반 부분 검사 조화 후보의 자료 정의·변환·연계·점추정 검산이다. 모델 추론 수치 검토는 Q-stat의 별도 역할이며, 원 논문의 정확한 복제나 모든 편향 해결을 승인한 결과가 아니다.

대상은 `E2-20261004`, 자료 버전 `nhanes-2009-2018-harmonizedJ-d8f04b7c96c89c31956a`이다. 상류 E1의 master와 보고서·목록 해시를 확인하고, 구현 함수를 source하거나 모델을 재적합하지 않고 변환·분모·출처를 별도로 검산했다. 검토자는 P 출처 확보 담당으로 목표 수치에 노출되었음을 공개한다. 내부 독립 검토이며 외부 검증은 아니다.

J(2017–2018)의 크레아티닌에는 `1.051 × LBXSCR − 0.06945`, BIOPRO TG에는 `0.9655 × LBXSTR − 7.020` mg/dL가 적용되었다. 이는 이전 검사 장비 척도로 변환하는 CDC 역방향 점추정식이다. 원시 LBXSCR/LBXSTR, assay_raw 및 before_harmonization 열을 모두 확인했다. F–I의 관측값과 두 검사 외 모든 E1 필드는 변하지 않았다. 변환 후 결측과 분석 domain도 유지되었다. [CDC BIOPRO_J 주기 통합 안내](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm)

| 항목 | 크레아티닌 | BIOPRO TG |
| --- | ---: | ---: |
| J 전체에서 변환된 관측 기록 | 5,903 | 5,901 |
| A domain에서 변환된 관측 기록 | 3,941 | 3,940 |
| A 관측 n | 20,220 | 20,206 |
| A 결측 n | 1,238 | 1,252 |
| E1 채움 중앙값 | 0.86 mg/dL | 125.00 mg/dL |
| E2 채움 중앙값 | 0.850 mg/dL | 122.357 mg/dL |

중앙값은 J 변환 후 A domain의 관측값에서 다시 산출되었고, 기존 결측 지시자는 그대로 유지되었다. A 21,458명, B 19,925명의 분석 domain, 가중치, 설계 ID와 모든 모델별 n·cases·controls·공변량 식이 E1과 일치한다. E1에서 검산한 보충표의 공통 controls와 미확인 진단/복약 상태 11명 처리도 그대로 유지된다.

M1/M2의 계수·추세·모델 표 행은 E1 수치와 일치한다. 복사된 모든 미변경 파일의 원본 해시와 명시된 출처를 대조했다. M3·M3 추세·상호작용과 새 lean 모델은 새 자료 버전에 연결되어 있다. 변경된 검사 Table1의 모든 A/B 행에서 원시 n, 원시 평균 및 가중 평균이 독립 계산과 일치하며, 미변경 Table1 행은 E1과 같다. 160개 XPT/코드북 입력과 주요 E2 산출물의 SHA256도 일치한다.

E2는 검사 척도 조화를 적용한 부분 재구성이다. 비공복 BIOPRO TG가 공복 참조법 LBXTR가 되는 것은 아니며, 음주 근사·당뇨/흡연의 저자 정의·결측 지시자 처리·보충 domain의 저자 구현은 여전히 미확인이다. E2 경고 수는 이번 repair의 경고이며, 재사용된 E1 범주형 검정의 희소 셀 경고가 해결되었다는 뜻이 아니다. [CDC BIOPRO_J](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/BIOPRO_J.htm)

정확한 실행 SHA256: `38ac14542f2147f096d0035b3397964b66a255868811d6215d2eef08f2a09ab3`.
master.rds SHA256: `ed831aa35c25da5b032d5a1dc846268326a1ba6cede793a295b67ffa99fe4b60`.
보고서 SHA256: `1d0ac88a02fd05bd0d1d72b8c877e1fe72bb8f9d8750ea102fc28b2fd6aa4cc2`.

검토 판정과 accepted_scope/excluded_scope는 `review.json`에 있다. 검토 소스는 `q_harmonization_data_review.R`, 독립 요약은 `independent_harmonization_counts.csv`, `independent_median_missing_counts.csv`, `independent_reuse_hashes.csv`, `independent_lean_model_versions.csv`, `independent_changed_table1_points.csv`, `source_hash_check.csv`이다.
