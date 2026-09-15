# Q-Q Plot: WWI(체중-보정 허리둘레지수) 분포 확인
# + Q-Q plot의 "이론분위수(theoretical quantiles)" 산출식을 R 내장함수(ppoints, qqnorm)와 직접 대조

d <- readRDS(file.path("data", "analytic_sample.rds"))
x <- d$WWI[!is.na(d$WWI)]
n <- length(x)
cat(sprintf("N = %d\n", n))

# ------------------------------------------------------------------
# 1) R 내장함수로 그린 Q-Q plot
# ------------------------------------------------------------------
qq_builtin <- qqnorm(x, plot.it = FALSE)  # $x = 이론분위수, $y = 표본값(정렬 전 순서 그대로)

# ------------------------------------------------------------------
# 2) 이론분위수를 직접 계산 (내장함수 없이 수식으로)
#
#    Q-Q plot의 이론분위수는 "제i번째 순서통계량이 위치할 것으로 기대되는
#    누적확률" p_i 를 정규분포 분위함수에 넣어서 얻는다.
#
#    p_i = (i - a) / (n + 1 - 2a),   i = 1, ..., n
#    a = 3/8   (n <= 10)
#    a = 1/2   (n  > 10)              <- Blom(1958)의 근사식을 R이 채택한 값
#
#    theoretical_quantile_i = qnorm(p_i)   (표준정규분포 분위수)
# ------------------------------------------------------------------
a <- if (n > 10) 0.5 else 3 / 8
i <- seq_len(n)
p_manual <- (i - a) / (n + 1 - 2 * a)
theoretical_manual <- qnorm(p_manual)

x_sorted <- sort(x)

# ------------------------------------------------------------------
# 3) 내장함수 ppoints() 와 직접 계산한 p_manual 대조
# ------------------------------------------------------------------
p_builtin <- ppoints(n)
cat("\n[대조 1] 직접 계산한 확률 p_manual vs ppoints(n)\n")
cat("최대 절대오차 :", max(abs(p_manual - p_builtin)), "\n")
cat("완전히 동일한가 (all.equal) :", isTRUE(all.equal(p_manual, p_builtin)), "\n")

# qqnorm() 내부에서 계산한 이론분위수(오름차순 정렬 후)와 직접 계산한 값 비교
theoretical_from_qqnorm <- sort(qq_builtin$x)
cat("\n[대조 2] 직접 계산한 이론분위수 vs qqnorm()$x (정렬 후)\n")
cat("최대 절대오차 :", max(abs(theoretical_manual - theoretical_from_qqnorm)), "\n")
cat("완전히 동일한가 (all.equal) :",
    isTRUE(all.equal(theoretical_manual, theoretical_from_qqnorm)), "\n")

# ------------------------------------------------------------------
# 4) 시각화: 내장함수 결과 vs 직접 계산 결과를 나란히 그려서 육안으로도 확인
# ------------------------------------------------------------------
out_dir <- "output"
if (!dir.exists(out_dir)) dir.create(out_dir)
png(file.path(out_dir, "qqplot_wwi.png"), width = 1400, height = 700, res = 130)
par(mfrow = c(1, 2))

qqnorm(x, main = "(A) 내장함수 qqnorm() + qqline()",
       xlab = "이론분위수 (Theoretical Quantiles)", ylab = "표본분위수 (WWI)")
qqline(x, col = "red", lwd = 2)

plot(theoretical_manual, x_sorted,
     main = "(B) 수식으로 직접 계산 (재현)",
     xlab = "이론분위수 = qnorm((i-a)/(n+1-2a))", ylab = "표본분위수 (WWI, 정렬)",
     pch = 1)
# qqline과 동일한 방식으로 기준선 추가: 1,3사분위수를 잇는 직선
q_probs <- c(0.25, 0.75)
y_q <- quantile(x, q_probs)
x_q <- qnorm(q_probs)
slope <- diff(y_q) / diff(x_q)
intercept <- y_q[1] - slope * x_q[1]
abline(intercept, slope, col = "red", lwd = 2)

dev.off()
message("Saved output/qqplot_wwi.png")
