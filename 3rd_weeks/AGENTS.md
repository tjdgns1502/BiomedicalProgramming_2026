# Fagerland 재현 분석

목표: 논문 수치와 로컬 R 결과를 재현 가능한 방법으로 비교·설명한다.

## 공통 규칙

1. `STATUS.md`, `config.R`, 자기 역할 파일만 먼저 읽는다.
2. 원자료와 논문 참조값을 수정하지 않는다. 모든 난수 실행은 고정 시드와 `replicate()`를 쓴다.
3. 결과는 `results/`에, 가정 변경과 원인은 `results/logs/reconciliation.md`에 남긴다.
4. 일치 기준은 `R/07_validation.R`의 결합 Monte Carlo 오차다. 소수점 강제 맞춤을 금지한다.
5. 한 라운드는 실험 → 검증 순서다. 최대 3회 후 불일치는 실패와 원인을 보고한다.

## 두 역할

- 실험·조절: `agents/experimenter.md`
- 독립 검증: `agents/validator.md`
- 교환 규약: `agents/protocol.md`

## 완료 기준

- 논문형 Figure 1–3과 추가 Q-Q·재표본·CI·격자도를 생성한다.
- Welch 자유도가 Satterthwaite 직접값과 `1e-10` 이내로 일치한다.
- 중앙값이 같아도 WMW가 유의한 반례와 `Pr(X<Y)`를 제시한다.
- 차이의 크기, 판정, 원인, 수정 전후를 로그와 보고서에 남긴다.

