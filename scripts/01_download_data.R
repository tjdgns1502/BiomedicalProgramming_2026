# Download NHANES 2011-2020 files needed to reproduce Table 1
# Cycles: 2011-2012 (G), 2013-2014 (H), 2015-2016 (I), 2017-March 2020 pre-pandemic (P)

options(timeout = 300)

data_dir <- "data"
if (!dir.exists(data_dir)) dir.create(data_dir)

base_url <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public"

cycles <- list(
  G = list(year = 2011, prefix = ""),
  H = list(year = 2013, prefix = ""),
  I = list(year = 2015, prefix = ""),
  P = list(year = 2017, prefix = "")
)

components <- c("DEMO", "BMX", "SMQ", "DIQ", "BPQ", "MCQ", "ALQ", "TCHOL", "HDL", "TRIGLY")

file_name <- function(cycle, comp) {
  if (cycle == "P") paste0("P_", comp) else paste0(comp, "_", cycle)
}

download_one <- function(cycle, comp) {
  year <- cycles[[cycle]]$year
  fname <- file_name(cycle, comp)
  url <- sprintf("%s/%s/DataFiles/%s.xpt", base_url, year, fname)
  dest <- file.path(data_dir, paste0(fname, ".XPT"))
  if (file.exists(dest) && file.info(dest)$size > 0) {
    return(invisible(TRUE))
  }
  ok <- tryCatch({
    download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) {
    message(sprintf("FAILED: %s (%s)", fname, conditionMessage(e)))
    FALSE
  })
  if (ok) message(sprintf("Downloaded %s (%.2f MB)", fname, file.info(dest)$size / 1e6))
  invisible(ok)
}

for (cycle in names(cycles)) {
  for (comp in components) {
    download_one(cycle, comp)
  }
}

message("Download complete.")
