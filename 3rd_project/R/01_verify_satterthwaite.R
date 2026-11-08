## 01_verify_satterthwaite.R ----------------------------------------------
## Verification task (1): reproduce t.test()'s fractional degrees of
## freedom by hand, match its p-value, and check the four structural
## properties of nu with code rather than prose.
##
## Standalone:  Rscript R/01_verify_satterthwaite.R
## ------------------------------------------------------------------------

HERE <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else normalizePath("R")
})
source(file.path(HERE, "00_utils.R"))

## ------------------------------------------------------------------
## (a) agreement with t.test() on 500 random designs
## ------------------------------------------------------------------
NDES <- 500L
set.seed(101)

chk <- do.call(rbind, lapply(seq_len(NDES), function(i) {
  n1 <- sample(5:120, 1); n2 <- sample(5:120, 1)
  x <- rnorm(n1, 0, runif(1, 0.2, 6))
  y <- rnorm(n2, 0, runif(1, 0.2, 6))
  tt <- t.test(x, y)                         # var.equal = FALSE default
  c(mine_df = welch_df(x, y), R_df = unname(tt$parameter),
    mine_p  = welch_p(x, y),  R_p  = tt$p.value,
    lo = min(n1, n2) - 1, hi = n1 + n2 - 2)
}))

err_df <- max(abs(chk[, "mine_df"] - chk[, "R_df"]))
err_p  <- max(abs(chk[, "mine_p"]  - chk[, "R_p"]))
rel_df <- max(abs(chk[, "mine_df"] - chk[, "R_df"]) / chk[, "R_df"])

## ------------------------------------------------------------------
## (b) property 1: min(n1,n2) - 1  <=  nu  <=  n1 + n2 - 2
## ------------------------------------------------------------------
in_range <- chk[, "mine_df"] >= chk[, "lo"] - 1e-9 &
            chk[, "mine_df"] <= chk[, "hi"] + 1e-9
range_ok <- all(in_range)

## a harder stress test: extreme variance ratios and extreme n imbalance
set.seed(102)
stress <- do.call(rbind, lapply(1:20000, function(i) {
  n1 <- sample(3:200, 1); n2 <- sample(3:200, 1)
  x <- rnorm(n1, 0, 10^runif(1, -4, 4))
  y <- rnorm(n2, 0, 10^runif(1, -4, 4))
  nu <- welch_df(x, y)
  c(nu = nu, lo = min(n1, n2) - 1, hi = n1 + n2 - 2)
}))
stress_ok <- all(stress[, "nu"] >= stress[, "lo"] - 1e-9 &
                 stress[, "nu"] <= stress[, "hi"] + 1e-9)
range_slack <- c(min_over_lo = min(stress[, "nu"] - stress[, "lo"]),
                 min_under_hi = min(stress[, "hi"] - stress[, "nu"]))

## ------------------------------------------------------------------
## (c) property 2: one variance dominating  =>  nu -> (that group's n) - 1
## Population SDs are used here (no sampling noise) so the limit is clean:
## we feed welch_df samples whose sample variances are set exactly.
## ------------------------------------------------------------------
## deterministic version: nu as a function of (s1^2, s2^2, n1, n2)
nu_formula <- function(v1, v2, n1, n2) {
  a <- v1 / n1; b <- v2 / n2
  (a + b)^2 / (a^2 / (n1 - 1) + b^2 / (n2 - 1))
}
n1d <- 12; n2d <- 40
ratios <- 10^seq(0, 8, by = 1)                 # var2 / var1
dom2 <- data.frame(
  var_ratio = ratios,
  nu = vapply(ratios, function(r) nu_formula(1, r, n1d, n2d), numeric(1)),
  limit = n2d - 1                              # group 2 dominates
)
dom1 <- data.frame(
  var_ratio = ratios,
  nu = vapply(ratios, function(r) nu_formula(r, 1, n1d, n2d), numeric(1)),
  limit = n1d - 1                              # group 1 dominates
)
dom_ok <- abs(dom2$nu[length(ratios)] - (n2d - 1)) < 1e-4 &&
          abs(dom1$nu[length(ratios)] - (n1d - 1)) < 1e-4

## ------------------------------------------------------------------
## (d) property 3: n1 == n2 and s1 == s2  =>  nu == n1 + n2 - 2
## Constructed so the two SAMPLE variances are identical by construction
## (y is x shifted), which is what the property is about.
## ------------------------------------------------------------------
set.seed(103)
eq <- do.call(rbind, lapply(1:200, function(i) {
  n <- sample(4:150, 1)
  x <- rnorm(n, 0, runif(1, 0.2, 6))
  y <- x + 5                                   # var(y) == var(x) exactly
  c(nu = welch_df(x, y), target = 2 * n - 2,
    student_df = 2 * n - 2,
    p_welch = welch_p(x, y), p_student = student_p(x, y))
}))
eq_df_err <- max(abs(eq[, "nu"] - eq[, "target"]))
eq_p_err  <- max(abs(eq[, "p_welch"] - eq[, "p_student"]))

## algebraic check with exactly equal variances symbolically:
## a = b  =>  nu = (2a)^2 / (2 a^2/(n-1)) = 2(n-1)
eq_ok <- eq_df_err < 1e-9 && eq_p_err < 1e-12

## ------------------------------------------------------------------
## (e) property 4: nu is a RANDOM VARIABLE
## Same fixed design, 20000 independent samples -> sampling distribution.
## ------------------------------------------------------------------
DESIGN <- list(n1 = 15, n2 = 25, sd1 = 1, sd2 = 3)
set.seed(104)
nu_draws <- replicate(20000, {
  welch_df(rnorm(DESIGN$n1, 0, DESIGN$sd1), rnorm(DESIGN$n2, 0, DESIGN$sd2))
})
nu_summary <- c(
  min = min(nu_draws), q05 = unname(quantile(nu_draws, 0.05)),
  median = median(nu_draws), mean = mean(nu_draws),
  q95 = unname(quantile(nu_draws, 0.95)), max = max(nu_draws),
  sd = sd(nu_draws),
  lower_bound = min(DESIGN$n1, DESIGN$n2) - 1,
  upper_bound = DESIGN$n1 + DESIGN$n2 - 2,
  ## nu evaluated at the POPULATION variances, for reference
  nu_at_truth = nu_formula(DESIGN$sd1^2, DESIGN$sd2^2, DESIGN$n1, DESIGN$n2)
)
frac_noninteger <- mean(abs(nu_draws - round(nu_draws)) > 1e-8)

## ------------------------------------------------------------------
## report
## ------------------------------------------------------------------
cat("\n== Verification task 1: Satterthwaite degrees of freedom ==\n\n")
cat("(a) agreement with t.test() over", NDES, "random designs\n")
cat("    max |nu_mine - nu_R|        : ", format(err_df, digits = 3), "\n", sep = "")
cat("    max relative df error       : ", format(rel_df, digits = 3), "\n", sep = "")
cat("    max |p_mine - p_R|          : ", format(err_p,  digits = 3), "\n\n", sep = "")

cat("(b) range  min(n1,n2)-1 <= nu <= n1+n2-2\n")
cat("    holds on the 500 designs   : ", range_ok, "\n", sep = "")
cat("    holds on 20000 stress cases: ", stress_ok, "\n", sep = "")
cat("    tightest slack (lo, hi)    : ",
    paste(format(range_slack, digits = 3), collapse = ", "), "\n\n", sep = "")

cat("(c) one variance dominating -> nu -> n-1 of that group\n")
print(cbind(`var2/var1` = dom2$var_ratio, nu = round(dom2$nu, 4),
            limit = dom2$limit))
print(cbind(`var1/var2` = dom1$var_ratio, nu = round(dom1$nu, 4),
            limit = dom1$limit))
cat("    converges as expected      : ", dom_ok, "\n\n", sep = "")

cat("(d) n1 = n2 and s1 = s2  =>  nu = n1+n2-2 (and Welch = Student)\n")
cat("    max |nu - (n1+n2-2)|       : ", format(eq_df_err, digits = 3), "\n", sep = "")
cat("    max |p_Welch - p_Student|  : ", format(eq_p_err,  digits = 3), "\n\n", sep = "")

cat("(e) nu is a random variable; design n1=15 (sd 1), n2=25 (sd 3)\n")
print(round(nu_summary, 3))
cat("    fraction of draws non-integer: ", format(frac_noninteger, digits = 4),
    "\n", sep = "")

ok <- (err_df < 1e-10) && (err_p < 1e-12) && range_ok && stress_ok &&
      dom_ok && eq_ok
cat("\nALL CHECKS PASS: ", ok, "\n", sep = "")
if (!ok) stop("01_verify_satterthwaite.R: a check failed.")

saveRDS(list(
  n_designs = NDES,
  max_abs_df_error = err_df, max_rel_df_error = rel_df,
  max_abs_p_error = err_p,
  range_ok = range_ok, stress_ok = stress_ok,
  n_stress = nrow(stress), range_slack = range_slack,
  dominance_group2 = dom2, dominance_group1 = dom1, dom_ok = dom_ok,
  equal_case_df_error = eq_df_err, equal_case_p_error = eq_p_err,
  design = DESIGN, nu_draws = nu_draws, nu_summary = nu_summary,
  frac_noninteger = frac_noninteger,
  all_ok = ok
), file.path(RES_DIR, "01_satterthwaite.rds"))

cat("saved -> results/01_satterthwaite.rds\n")
