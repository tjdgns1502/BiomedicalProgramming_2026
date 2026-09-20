welch_manual <- function(x, y, conf.level = 0.95) {
  nx <- length(x); ny <- length(y)
  vx <- var(x); vy <- var(y)
  se2 <- vx / nx + vy / ny
  df <- se2^2 / ((vx / nx)^2 / (nx - 1) + (vy / ny)^2 / (ny - 1))
  estimate <- mean(x) - mean(y)
  t <- estimate / sqrt(se2)
  p <- 2 * pt(-abs(t), df)
  crit <- qt(1 - (1 - conf.level) / 2, df)
  list(statistic = t, parameter = df, p.value = p,
       conf.int = estimate + c(-1, 1) * crit * sqrt(se2), estimate = estimate)
}

welch_p_fast <- function(x, y) welch_manual(x, y)$p.value

wmw_p_fast <- function(x, y, correct = TRUE) {
  nx <- length(x); ny <- length(y)
  u <- sum(rank(c(x, y))[seq_len(nx)]) - nx * (nx + 1) / 2
  mu <- nx * ny / 2
  sigma <- sqrt(nx * ny * (nx + ny + 1) / 12)
  distance <- abs(u - mu) - if (correct) 0.5 else 0
  2 * pnorm(-max(distance, 0) / sigma)
}

all_tests <- function(x, y) {
  pooled_sd <- sqrt(((length(x) - 1) * var(x) + (length(y) - 1) * var(y)) /
                    (length(x) + length(y) - 2))
  d <- (mean(x) - mean(y)) / pooled_sd
  correction <- 1 - 3 / (4 * (length(x) + length(y)) - 9)
  w <- suppressWarnings(wilcox.test(x, y, exact = FALSE, correct = TRUE))
  c(student_p = t.test(x, y, var.equal = TRUE)$p.value,
    welch_p = t.test(x, y, var.equal = FALSE)$p.value,
    wmw_p = w$p.value, cohen_d = d, hedges_g = correction * d)
}

permutation_p <- function(x, y, B = config$permutation_reps) {
  observed <- abs(mean(x) - mean(y)); z <- c(x, y); nx <- length(x)
  perm <- replicate(B, {
    i <- sample.int(length(z), nx)
    abs(mean(z[i]) - mean(z[-i]))
  })
  (1 + sum(perm >= observed)) / (B + 1)
}

paired_tests <- function(before, after) {
  stopifnot(length(before) == length(after))
  delta <- after - before
  c(paired_t_p = t.test(after, before, paired = TRUE)$p.value,
    signed_rank_p = wilcox.test(after, before, paired = TRUE, exact = FALSE)$p.value,
    dz = mean(delta) / sd(delta))
}
