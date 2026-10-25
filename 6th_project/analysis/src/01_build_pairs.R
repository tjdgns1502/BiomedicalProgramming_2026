# HR01: Heart_Rate 시트를 참가자 x 기기 88쌍의 긴 표로 바꾼다.
# 헤더 이름이 아니라 열 위치로 매핑한다 (Trial_number 4회 중복, F열 헤더 'Fitbit_metamax').

DEVICE_MAP <- data.frame(
  device     = c("Apple Watch", "Fitbit Charge HR", "Samsung Gear S", "Mio Alpha"),
  device_key = c("Apple", "Fitbit", "Samsung", "Alpha"),
  col_device = c("B", "E", "H", "K"),
  col_ecg    = c("C", "F", "I", "L"),
  col_trial  = c("D", "G", "J", "M"),
  stringsAsFactors = FALSE
)

col_index <- function(letter) match(letter, LETTERS)

build_pairs <- function(raw_path) {
  hdr <- names(readxl::read_excel(raw_path, sheet = "Heart_Rate", n_max = 0,
                                  .name_repair = "minimal"))
  num <- readxl::read_excel(raw_path, sheet = "Heart_Rate", col_names = FALSE,
                            skip = 1, .name_repair = "minimal")
  txt <- readxl::read_excel(raw_path, sheet = "Heart_Rate", col_names = FALSE,
                            skip = 1, col_types = "text", .name_repair = "minimal")
  stopifnot(identical(hdr[1], "ID"), ncol(num) == 13, nrow(num) == 22)

  excel_row <- seq_len(nrow(num)) + 1L
  ids <- as.integer(num[[1]])
  stopifnot(identical(ids, 1:22))

  rows <- lapply(seq_len(nrow(DEVICE_MAP)), function(k) {
    m <- DEVICE_MAP[k, ]
    jd <- col_index(m$col_device); je <- col_index(m$col_ecg); jt <- col_index(m$col_trial)
    data.frame(
      pair_id        = sprintf("P%02d-%s", ids, m$device_key),
      id             = ids,
      device         = m$device,
      device_key     = m$device_key,
      trial          = as.integer(num[[jt]]),
      device_hr      = as.numeric(num[[jd]]),
      ecg_hr         = as.numeric(num[[je]]),
      excel_row      = excel_row,
      cell_device    = paste0(m$col_device, excel_row),
      cell_ecg       = paste0(m$col_ecg, excel_row),
      cell_trial     = paste0(m$col_trial, excel_row),
      header_device  = hdr[jd],
      header_ecg     = hdr[je],
      header_trial   = hdr[jt],
      xml_text_device = txt[[jd]],
      xml_text_ecg   = txt[[je]],
      stringsAsFactors = FALSE
    )
  })
  pairs <- do.call(rbind, rows)
  pairs$error <- pairs$device_hr - pairs$ecg_hr
  pairs$mean_device_ecg <- (pairs$device_hr + pairs$ecg_hr) / 2
  pairs$device <- factor(pairs$device, levels = DEVICE_MAP$device)
  pairs
}

# 셀 값이 소수 둘째 자리 이하인지 (xlsx double 표현 오차만 있는지) 확인
two_dp <- function(x) abs(x * 100 - round(x * 100)) < 1e-6

qa_pairs <- function(pairs) {
  checks <- data.frame(
    check = c("rows == 88", "22 per device", "no missing values",
              "trial in {1,2}", "device_hr <= 2 decimals", "ecg_hr <= 2 decimals"),
    pass = c(
      nrow(pairs) == 88,
      all(table(pairs$device) == 22),
      !anyNA(pairs[, c("device_hr", "ecg_hr", "trial")]),
      all(pairs$trial %in% 1:2),
      all(two_dp(pairs$device_hr)),
      all(two_dp(pairs$ecg_hr))
    ),
    stringsAsFactors = FALSE
  )

  # 같은 참가자·같은 trial에서 착용한 두 기기는 같은 ECG 기록을 공유해야 한다.
  key <- split(pairs, list(pairs$id, pairs$trial), drop = TRUE)
  trial_qa <- do.call(rbind, lapply(key, function(d) data.frame(
    id = d$id[1], trial = d$trial[1],
    devices = paste(as.character(d$device), collapse = " + "),
    n_devices = nrow(d),
    ecg_values = paste(sprintf("%.2f", unique(d$ecg_hr)), collapse = " / "),
    n_distinct_ecg = length(unique(d$ecg_hr)),
    consistent = nrow(d) == 2 && length(unique(d$ecg_hr)) == 1,
    stringsAsFactors = FALSE
  )))
  trial_qa <- trial_qa[order(trial_qa$id, trial_qa$trial), ]
  rownames(trial_qa) <- NULL

  checks <- rbind(checks, data.frame(
    check = c("each id x trial has 2 devices", "devices in same trial share one ECG value"),
    pass = c(all(trial_qa$n_devices == 2), all(trial_qa$n_distinct_ecg == 1)),
    stringsAsFactors = FALSE
  ))
  list(checks = checks, trial_qa = trial_qa)
}
