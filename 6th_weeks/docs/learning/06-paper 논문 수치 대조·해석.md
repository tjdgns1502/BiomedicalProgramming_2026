# 논문 수치 대조·해석 — 논문·실제 데이터 적용 (paper)

학습 단계: HR06 · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: wallen-hr-355eb8cf25fa3f49fd17 · 실행: R1-20261024

## 입력 → 이번 질문

공식 원문 Table 1과 Figure 2를 고정된 R1 결과와 대조했습니다. 이번 비교 범위는 공개 HR 요약치 일부이며 ICC·에너지 소비·걸음 수와 논문 전체의 재현이 아닙니다.

## 논문 원문과 직접 계산의 구분

Samsung 원문의 0.67은 Spearman입니다. 같은 종류로 대조하면 상관 4개는 허용오차 0.005 이내입니다. 과제 Pearson 0.743은 그대로 유지했습니다. Mio의 원문 가변 LoA는 이번 상수 LoA와 직접 동등 판정하지 않았습니다.

## 이번 비교 선택과 결과

n·r·평균의 허용오차는 실행 전 계획에 있었고, SD·LoA의 0.05는 원문 표 추출 후 소수 첫째 자리 정밀도에 적용했습니다. 38개 필드 중 33개가 각 허용오차 이내이며 이 비율을 정확도 점수로 해석하지 않습니다.

## 남은 의문

C01–C03에 연결됩니다. 인쇄된 bias·SD를 대입한 고정 LoA 6개가 원문과 양립하는지는 사후 설명 점검입니다. 저자의 실제 반올림 순서는 미확인이고 원자료 계산값은 수정하지 않았습니다.

## 실제 산출물

원문 방식 상관 4/4 허용오차 내; 직접 비교 38필드 중 33 허용오차 내.

| 기기 | 항목 | 원문 | 계산 | 차이 |
| --- | --- | --- | --- | --- |
| Samsung Gear S | bias | -7.1 | -7.048182 | 0.051818 |
| Apple Watch | classical_loa_low | -9.9 | -9.836879 | 0.063121 |
| Fitbit Charge HR | classical_loa_high | 7.4 | 7.300741 | -0.099259 |
| Fitbit Charge HR | classical_loa_low | -26.0 | -25.936196 | 0.063804 |
| Samsung Gear S | classical_loa_low | -27.3 | -27.152278 | 0.147722 |


출처 근거: paper Table 1, Figure 2, Statistical analysis; sources/published_tables.json

원본 결과: analysis/runs/R1-20261024/tables/publication_comparison.csv, analysis/runs/R1-20261024/tables/reported_rounding_diagnostic.csv

그림: 직접 연결 그림 없음

문제 ID: C01, C02, C03

[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)

짝 문서: 06-concept 논문 수치 대조·해석.md
