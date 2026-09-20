if (!exists("config")) source("config.R")

ln_sigma_from_skew <- function(skewness) {
  f <- function(s) (exp(s^2) + 2) * sqrt(exp(s^2) - 1) - skewness
  uniroot(f, c(1e-8, 3))$root
}

base_spec <- function(family, skewness) {
  if (family == "gamma") {
    shape <- 4 / skewness^2
    scale <- 1 / sqrt(shape)
    list(
      r = function(n) rgamma(n, shape = shape, scale = scale),
      d = function(x) dgamma(x, shape = shape, scale = scale),
      p = function(x) pgamma(x, shape = shape, scale = scale),
      mean = sqrt(shape), median = qgamma(0.5, shape, scale = scale), sd = 1
    )
  } else if (family == "lognormal") {
    sigma <- ln_sigma_from_skew(skewness)
    raw_sd <- sqrt(exp(sigma^2) - 1)
    list(
      r = function(n) rlnorm(n, meanlog = -sigma^2 / 2, sdlog = sigma) / raw_sd,
      d = function(x) dlnorm(x * raw_sd, meanlog = -sigma^2 / 2, sdlog = sigma) * raw_sd,
      p = function(x) plnorm(x * raw_sd, meanlog = -sigma^2 / 2, sdlog = sigma),
      mean = 1 / raw_sd, median = exp(-sigma^2 / 2) / raw_sd, sd = 1
    )
  } else stop("Unknown family: ", family)
}

alignment_shift <- function(spec, sd_ratio, alignment) {
  center <- if (alignment == "mean") spec$mean else spec$median
  center * (1 - sd_ratio)
}

draw_pair <- function(n, family, skewness, sd_ratio, alignment) {
  spec <- base_spec(family, skewness)
  shift <- alignment_shift(spec, sd_ratio, alignment)
  list(x = sd_ratio * spec$r(n) + shift, y = spec$r(n))
}

population_diagnostics <- function(family, skewness, sd_ratio, alignment) {
  spec <- base_spec(family, skewness)
  shift <- alignment_shift(spec, sd_ratio, alignment)
  pr <- integrate(
    function(y) spec$p((y - shift) / sd_ratio) * spec$d(y),
    lower = 0, upper = Inf, subdivisions = 1000L, rel.tol = 1e-9
  )$value
  data.frame(
    family, skewness, sd_ratio, alignment,
    mean_x = sd_ratio * spec$mean + shift, mean_y = spec$mean,
    median_x = sd_ratio * spec$median + shift, median_y = spec$median,
    sd_x = sd_ratio, sd_y = 1, pr_x_lt_y = pr
  )
}

