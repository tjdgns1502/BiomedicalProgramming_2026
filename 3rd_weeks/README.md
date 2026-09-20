# Fagerland (2012) 재현 프로젝트

Welch t와 WMW 검정의 기각률을 재현하고, 논문–로컬 차이를 두 역할이 실험·검증하는 구조다.

## 실행

```powershell
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' R/run_all.R
```

`run_all.R`은 정렬 후보 실험, 10,000회 초점 검증, 논문형 Figure 1–3, Q-Q·재표본·CI·격자도, 반례와 Satterthwaite 검증을 실행한다. 격자도는 탐색용으로 조건당 500회이며 `config.R`에서 10,000회로 높일 수 있다.

두 에이전트의 역할은 `agents/experimenter.md`와 `agents/validator.md`, 전달 규약은 `agents/protocol.md`에 있다. 실제 반복은 `R/08_calibration_loop.R`이 동일 규칙으로 수행한다.

2주차 NHANES 원자료는 `data/raw/nhanes_week2.rds`에 둔다.

