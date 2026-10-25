# HR07 · PAPER — 문제 기록, 검증 범위, 결론의 한계

> 논문·실제 데이터 적용 페이지. 문제 원장은 `analysis/memory/issues.json`, 검토 기록은 `analysis/reviews/`. 일반 개념은 [HR07-concept](HR07-concept.md).

## 입력
HR01–HR06에서 남긴 문제 ID, 실행 run `{{meta:run_id}}`(주 분석)와 `{{meta:cand_run_id}}`(탐색적 후보), 공식 검사 결과, 별도 문맥 코드 감사.

## 이번 질문
무엇을 확인했고, 무엇을 못 했으며, 이 자료로 어디까지 말할 수 있는가?

## 방법과 이유
### 실행한 확인과 그 범위
| 확인 | 결과 | 범위와 한계 |
|---|---|---|
| 자료 QA (`hr01_qa_checks.csv`) | {{n:hr01_qa_checks|pass=TRUE}}/{{n:hr01_qa_checks|pass=TRUE}}개 점검 통과 | 88쌍, 결측 0, trial별 ECG 공유 {{n:hr01_trial_qa|consistent=TRUE}}/44 |
| 공식 검사 `tests/test_stats.R` | 45개 모두 통과 | R 내장함수 = 교과서 공식. 같은 R 환경 안의 자기 점검 |
| 덮어쓰기 방지 | 같은 run_id 재실행 시 중단 확인 | 운영 규칙이며 파일 권한 잠금은 아님 |
| 코드 감사 `reviews/R1_R2_code_audit.json` | 결과를 바꾸는 오류 없음, 표기 2건 | 다른 문맥의 같은 계열 AI 검토자. 외부·맹검·독립 심사 아님 |
| Python 교차 구현 | **실행하지 않음** | uv가 설치되어 있지 않음 (ISS-15) |
| 원문 수치 대조 | 사전 규칙 부분 일치, 탐색 후보로 모두 호환 | HR06 참고 |
| 브라우저 확인 | `reviews/browser_review.json` | 보고서 화면·기능 |

### 판정 (주장별)
| 주장 | 통계 검토 판정 | 범위 |
|---|---|---|
| 네 기기 모두 평균 HR을 ECG보다 낮게 읽었다 | 조건부 지지 | 22명, 약 58분 평균 HR. Apple은 bias CI가 0 포함 |
| 상관은 '중간~강함'이다 | 지지 | Pearson r {{v:hr02_correlation|Samsung|pearson_r|2}}–{{v:hr02_correlation|Apple|pearson_r|2}}, CI 넓음 |
| 상관이 높아도 일치는 다르다 | 지지 | Fitbit·Mio: 높은 r과 음의 bias, 넓은 LoA |
| "These devices accurately measure heart rate" (원문 결론) | 판정 불가 | 허용 오차 기준이 미리 정의되지 않았고, 평균 HR만으로는 순간·활동별 정확도를 판단할 수 없다 |
| 기기 간 우열 | 판정 불가 (검정하지 않음) | 기기 간 비교는 같은 사람의 반복이라 짝 구조를 반영한 별도 분석이 필요하다 |

## 출력
### 문제 원장 요약
| ID | 단계 | 종류 | 내용 | 상태 |
|---|---|---|---|---|
| ISS-01 | HR01 | data_quality | F열 헤더 `Fitbit_metamax` ↔ Key: ECG HR | 해결 (코드북 + trial 일치) |
| ISS-02 | HR01 | data_quality | `Trial_number` 헤더 4회 중복 | 해결 (위치 매핑) |
| ISS-03 | HR01 | input_unavailable | 15초·활동별 HR 미공개 | 미해결 (입력 불가) |
| ISS-04 | HR01 | unreported | 평균 HR 산출 방식 미보고 | 미해결 |
| ISS-05 | HR02 | estimand | 원문 Samsung 0.67 = Spearman, 과제 Pearson {{v:hr02_correlation|Samsung|pearson_r|3}} | 해결 (다른 통계량으로 구분) |
| ISS-06 | HR02 | unreported | 정규성 판정 방법 미보고 | 미해결 |
| ISS-07 | HR06 | replication_config | r CI 경계 2개 불일치; 반올림 r 기반 Fisher z와 호환 | 부분 해결 (탐색적) |
| ISS-08 | HR06 | replication_config | Samsung bias −7.05 vs −7.1; 두 경로 모두 호환 | 식별 불가 |
| ISS-09 | HR06 | replication_config | LoA 4개 불일치; 반올림된 bias·SD 경로와 호환 | 부분 해결 (탐색적) |
| ISS-10 | HR04/06 | scope | Mio 가변 LoA: 고정 LoA와 다른 추정 대상, 세부 미보고 | 범위 밖 |
| ISS-11 | HR06 | conflict | 본문 "Fitbit HR systematic bias" ↔ Table 1 점추정 LoA | 미해결 (원문 상충) |
| ISS-12 | HR01 | design | 88쌍은 독립 아님 → 기기별 n = 22 | 해결 (설계 반영) |
| ISS-13 | HR01 | data_quality | Key의 Gender 코딩·Worksheet_5 설명 오류 | 기록 (HR 영향 없음) |
| ISS-14 | HR05 | validity | Cook's D > 4/n 참가자 다수 | 해결 (유지, 범위 보고) |
| ISS-15 | HR07 | environment | uv 미설치로 Python 교차검증 미실시 | 보류 |
| ISS-16 | HR07 | review | 코드 감사는 같은 계열 AI의 별도 문맥 검토 | 표기 (self/separate-context) |
| ISS-17 | HR01 | provenance | 프롬프트의 이전 실행(R1-20261024)·문서가 이 저장소에 없음 | 기록 (새로 구축) |
| ISS-18 | HR01 | provenance | 원자료를 공식 URL에서 재다운로드해 대조하지 않음 | 미해결 |
| ISS-19 | HR07 | requirements | 저장소의 이전 강의계획 PDF는 6주차에 다른 논문 지정 ↔ 수정 슬라이드는 Wallen 2016 | 해결 (프롬프트가 지정한 수정 슬라이드를 따름) |
| ISS-20 | HR04 | label | `pct_bias`는 부호 있는 값 (계획서 표기는 \|bias\|) | 해결 (문서에 명시, 재실행 안 함) |

### 이 자료로 말할 수 있는 것
- 이 22명(젊고 건강한 대학 구성원, 19–41세)의 약 58분 실험실 protocol에서 네 기기의 **평균 HR**은 ECG 평균 HR과 강하게 상관했고, 평균적으로 낮게 읽었다.
- 상관의 크기와 일치의 정도는 기기마다 순서가 다르다. 상관만으로 정확도를 판단하면 안 된다.

### 말할 수 없는 것
- 임상적으로 ECG와 **바꿔 써도 된다**는 것 (허용 기준이 없음)
- **지금 판매되는** 시계의 성능 (2015년 기기·펌웨어)
- 운동 강도별·순간 HR의 정확도 (평균 자료뿐)
- 왜 틀리는가(피부, 움직임)에 대한 인과 설명
- 시계 ~ ECG 회귀식이 새 사람의 값 보정에 쓸 만하다는 것 (외부 검증 없음)

## 남은 질문
- 원시 15초 자료가 있으면 활동별 오차와 반복측정 모형으로 순간 정확도를 볼 수 있다.
- 14주차 최종 발표를 위해 같은 주 분석을 두 번째 언어(Python, uv 환경)로 구현해 대조하는 작업이 남아 있다.
