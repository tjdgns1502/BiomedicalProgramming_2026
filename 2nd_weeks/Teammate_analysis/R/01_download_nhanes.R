# =============================================================================
# 01_download_nhanes.R
# 논문: Ye et al. BMC Public Health 2023;23:1689 (PMID 37658310)
#       "Association between the weight-adjusted waist index and stroke"
# 목적: 논문이 사용한 NHANES 2011–2020 자료를 nhanesA 패키지로 내려받아 저장한다.
#
# 논문 Fig.1 의 초기 인원 45,462명은
#   2011-2012 (G)  9,756
#   2013-2014 (H) 10,175
#   2015-2016 (I)  9,971
#   2017-Mar2020 (P) 15,560   (팬데믹 전 통합 파일, 2017-2018 J 와는 다름)
#   ------------------------
#   합계          45,462   과 정확히 일치한다.
# =============================================================================

.libPaths(c("C:/Users/doyun/AppData/Local/R/win-library/4.6", .libPaths()))
suppressPackageStartupMessages(library(nhanesA))

proj_dir <- "C:/Users/doyun/Desktop/2026-2/의생명프로그래밍/2주차"
data_dir <- file.path(proj_dir, "data", "raw")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 내려받을 표 ------------------------------------------------------------
# 표 이름 : 필요한 변수 (논문 Table 1 / Methods 의 공변량)
#  DEMO   : SEQN, RIDAGEYR(나이), RIAGENDR(성별), RIDRETH3(인종), DMDEDUC2(교육),
#           INDFMPIR(PIR), SDMVPSU/SDMVSTRA(복합표본 설계), WTMEC2YR(MEC 가중치)
#  BMX    : BMXWT(체중 kg), BMXWAIST(허리둘레 cm), BMXBMI
#  MCQ    : MCQ160F(뇌졸중), MCQ160C(관상동맥질환), MCQ220(암)
#  DIQ    : DIQ010(당뇨)
#  BPQ    : BPQ020(고혈압)
#  SMQ    : SMQ020(흡연 100개비 이상)
#  ALQ    : ALQ130(음주량, 지난 12개월 하루 평균 잔수)
#  TRIGLY : LBXTR(중성지방), LBDLDL(LDL-C), WTSAF2YR(공복 하위표본 가중치)
#  HDL    : LBDHDD(HDL-C)
#  TCHOL  : LBXTC(총콜레스테롤)
tables <- c("DEMO", "BMX", "MCQ", "DIQ", "BPQ", "SMQ", "ALQ", "TRIGLY", "HDL", "TCHOL")

# 주기별 접미사/접두사 규칙: 2011-2016 은 "_G","_H","_I" 접미사, 2017-2020 은 "P_" 접두사
cycles <- list(
  G = function(t) paste0(t, "_G"),
  H = function(t) paste0(t, "_H"),
  I = function(t) paste0(t, "_I"),
  P = function(t) paste0("P_", t)
)

# ---- 다운로드 ----------------------------------------------------------------
# translated = FALSE : 코드값(1/2/7/9)을 그대로 둔다. 재현성을 위해 원자료 형태로 저장한 뒤
#                      전처리 단계(02_preprocess.R)에서 명시적으로 라벨링한다.
log <- list()
for (cy in names(cycles)) {
  for (tb in tables) {
    nm  <- cycles[[cy]](tb)
    out <- file.path(data_dir, paste0(nm, ".rds"))
    if (file.exists(out)) { message("skip (exists): ", nm); next }
    message("downloading: ", nm)
    df <- tryCatch(nhanes(nm, translated = FALSE), error = function(e) { message("  ERROR: ", conditionMessage(e)); NULL })
    if (is.null(df)) next
    saveRDS(df, out)
    log[[nm]] <- data.frame(table = nm, cycle = cy, n_rows = nrow(df), n_cols = ncol(df))
  }
}

# ---- 다운로드 요약 -----------------------------------------------------------
summary_df <- do.call(rbind, lapply(list.files(data_dir, pattern = "\\.rds$", full.names = TRUE), function(f) {
  d <- readRDS(f); data.frame(file = basename(f), n_rows = nrow(d), n_cols = ncol(d))
}))
print(summary_df, row.names = FALSE)
write.csv(summary_df, file.path(proj_dir, "data", "download_summary.csv"), row.names = FALSE)

demo_n <- sapply(names(cycles), function(cy) nrow(readRDS(file.path(data_dir, paste0(cycles[[cy]]("DEMO"), ".rds")))))
cat("\nDEMO 인원 (주기별):\n"); print(demo_n)
cat("합계 =", sum(demo_n), " (논문 Fig.1 초기 인원 45,462 와 비교)\n")
