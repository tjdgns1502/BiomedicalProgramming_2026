# docs/learning/*.md 와 run 표를 묶어 6th_project/최종분석보고서.html 한 파일을 만든다. 통계를 다시 계산하지 않는다.
# 사용법 (작업 디렉터리 = 6th_project/analysis): Rscript src/20_build_report.R
suppressPackageStartupMessages({ library(jsonlite); library(digest); library(commonmark); library(base64enc) })

RUN_MAIN <- "R1-20261025"; RUN_CAND <- "R2-20261025"
DOCS <- file.path("..", "docs", "learning")
OUT <- file.path("..", "최종분석보고서.html")
HIST <- file.path("..", "history")
sha <- function(p) digest(file = p, algo = "sha256")
rd <- function(p) paste(readLines(p, encoding = "UTF-8", warn = FALSE), collapse = "\n")
tbl <- function(run, name) read.csv(file.path("runs", run, "tables", paste0(name, ".csv")), stringsAsFactors = FALSE, encoding = "UTF-8")
esc <- function(x) { x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE); gsub(">", "&gt;", x, fixed = TRUE) }
f2 <- function(x, d = 2) formatC(x, format = "f", digits = d)

man <- fromJSON(file.path("runs", RUN_MAIN, "manifest.json"))
corr <- tbl(RUN_MAIN, "hr02_correlation"); ols <- tbl(RUN_MAIN, "hr03_ols")
err <- tbl(RUN_MAIN, "hr04_error"); cmp <- tbl(RUN_MAIN, "hr06_paper_comparison")
issues <- fromJSON(file.path("memory", "issues.json"))
reg <- fromJSON("stage_registry.json")$stages

FIGS <- list.files(file.path("runs", RUN_MAIN, "figures"), full.names = TRUE)
fig_uri <- setNames(lapply(FIGS, function(p) dataURI(file = p, mime = "image/png")), basename(FIGS))

md_to_html <- function(md) {
  h <- markdown_html(md, extensions = TRUE)
  h <- gsub("<table>", "<div class=\"tw\"><table>", h, fixed = TRUE)
  h <- gsub("</table>", "</table></div>", h, fixed = TRUE)
  for (nm in names(fig_uri))
    h <- gsub(paste0("assets/", RUN_MAIN, "/", nm), fig_uri[[nm]], h, fixed = TRUE)
  h <- gsub("href=\"(HR0[1-7]-(concept|paper))\\.md\"", "href=\"#\\1\"", h)
  h <- gsub("href=\"../../최종분석보고서.html\"", "href=\"#summary\"", h, fixed = TRUE)
  if (grepl("src=\"assets/", h, fixed = TRUE)) stop("내장하지 못한 그림 경로가 남음")
  # 한글 앞뒤 구두점 때문에 CommonMark가 굵게 처리하지 못한 ** 가 남으면 중단
  visible <- gsub("<pre>.*?</pre>|<code>.*?</code>", "", h, perl = TRUE)
  if (grepl("**", visible, fixed = TRUE)) stop("렌더링되지 않은 ** 가 남음: ", regmatches(visible, regexpr(".{0,30}\\*\\*.{0,30}", visible)))
  h
}

md_files <- c("00-학습문서읽기지도", as.vector(t(outer(sprintf("HR%02d", 1:7), c("concept", "paper"), paste, sep = "-"))))
md_raw <- setNames(lapply(md_files, function(id) rd(file.path(DOCS, paste0(id, ".md")))), md_files)
if (any(grepl("</script", md_raw, ignore.case = TRUE))) stop("MD에 </script 가 있어 내장할 수 없음")

md_tools <- function(id) sprintf(
  '<div class="mdtools"><button data-md-save="%s">%s.md 저장</button><details data-md-view="%s"><summary>MD 원문 보기 (docs/learning/%s.md)</summary><pre></pre></details></div>',
  id, id, id, id)

QUESTIONS <- c(
  HR01 = "한 행은 무엇이고, 시계 HR은 어느 ECG 값과 짝인가? 분모는 몇인가?",
  HR02 = "ECG가 높은 사람일수록 시계도 높게 읽는가, 그 직선 관계는 얼마나 강한가?",
  HR03 = "ECG가 1 bpm 오를 때 시계는 평균 몇 bpm 오르는가? y = x에서 어디서 벗어나는가?",
  HR04 = "시계는 ECG와 평균적으로, 그리고 사람마다 얼마나 다른가? 상관이 높아도 어긋날 수 있는가?",
  HR05 = "회귀 가정이 크게 어긋나는가? 한 사람이 결론을 좌우하는가?",
  HR06 = "같은 자료·같은 정의로 원문 Table 1의 HR 값이 나오는가?",
  HR07 = "무엇을 확인했고 못 했으며, 결론은 어디까지인가?")

stages_html <- paste(vapply(seq_len(nrow(reg)), function(i) {
  s <- reg$id[i]
  sprintf('<article class="stage" id="%s"><h3>%s · %s</h3><p class="q">질문: %s</p>
<div class="panel concept" id="%s-concept"><span class="tag">CONCEPT / 일반 통계 개념</span>%s%s</div>
<div class="panel paper" id="%s-paper"><span class="tag">PAPER / 논문·실제 데이터 적용</span>%s%s</div></article>',
    s, s, reg$title[i], QUESTIONS[[s]],
    s, md_to_html(md_raw[[paste0(s, "-concept")]]), md_tools(paste0(s, "-concept")),
    s, md_to_html(md_raw[[paste0(s, "-paper")]]), md_tools(paste0(s, "-paper")))
}, ""), collapse = "\n")

reading_map <- sprintf('<details class="issue"><summary><b>학습 읽기 지도</b> (docs/learning/00-학습문서읽기지도.md)</summary>%s%s</details>',
                       md_to_html(md_raw[["00-학습문서읽기지도"]]), md_tools("00-학습문서읽기지도"))
toc_stages <- paste(sprintf('<li class="sub"><a href="#%s">%s %s</a></li>', reg$id, reg$id, reg$title), collapse = "\n")

md_sources <- paste(sprintf('<script type="text/markdown" id="md-%s">\n%s</script>', md_files, unlist(md_raw)), collapse = "\n")

# 요약
cards <- paste(vapply(seq_len(nrow(err)), function(i) {
  d <- err$device[i]; c <- corr[corr$device == d, ]
  sprintf('<div class="card"><div class="k">%s (n = %d)</div><div class="v">r = %s · bias %s bpm</div><div class="s">고정 95%% LoA %s ~ %s bpm · MAE %s</div></div>',
          d, err$n[i], f2(c$pearson_r, 3), f2(err$bias[i], 1), f2(err$loa_lower[i], 1), f2(err$loa_upper[i], 1), f2(err$mae[i], 1))
}, ""), collapse = "")
sum_rows <- vapply(seq_len(nrow(err)), function(i) {
  d <- err$device[i]; c <- corr[corr$device == d, ]; o <- ols[ols$device == d, ]
  sprintf("<tr><td>%s</td><td>%s [%s, %s]</td><td>%s [%s, %s]</td><td>%s [%s, %s]</td><td>%s ~ %s</td><td>%s</td></tr>",
          d, f2(c$pearson_r, 3), f2(c$pearson_lo, 3), f2(c$pearson_hi, 3),
          f2(o$slope, 3), f2(o$slope_lo, 3), f2(o$slope_hi, 3),
          f2(err$bias[i]), f2(err$bias_lo[i]), f2(err$bias_hi[i]),
          f2(err$loa_lower[i]), f2(err$loa_upper[i]), f2(err$mae[i]))
}, "")
summary_table <- paste0('<div class="tw"><table><thead><tr><th>기기</th><th>Pearson r [95% CI]</th><th>OLS 기울기 [95% CI]</th><th>평균오차 bias [95% CI] (bpm)</th><th>고정 95% LoA (bpm)</th><th>MAE (bpm)</th></tr></thead><tbody>',
                        paste(sum_rows, collapse = ""), "</tbody></table></div>")
summary_fig <- sprintf('<figure><img src="%s" alt="F4 상관과 일치의 병치"><figcaption class="note">F4. 왼쪽: 기기별 Pearson r과 95%% CI. 오른쪽: 굵은 막대 = 평균오차 95%% CI, 점선 = 고정 95%% LoA. 상관 순서와 오차 크기 순서가 같지 않다.</figcaption></figure>',
                       fig_uri[["F4_correlation_vs_agreement.png"]])
headline <- sprintf("네 기기의 약 58분 평균 HR은 ECG와 강하게 상관했지만(Pearson r %s–%s), 모두 평균적으로 낮게 읽었다(bias %s ~ %s bpm). 상관이 높다는 것과 값이 일치한다는 것은 다르다.",
                    f2(min(corr$pearson_r), 2), f2(max(corr$pearson_r), 2), f2(min(err$bias), 1), f2(max(err$bias), 1))

# 문제 목록
st_class <- function(s) if (grepl("^해결", s)) "st-ok" else if (grepl("미해결|상충|식별 불가", s)) "st-bad" else if (grepl("부분|보류", s)) "st-warn" else "st-muted"
issues_html <- paste(vapply(seq_len(nrow(issues)), function(i) {
  x <- issues[i, ]
  sprintf('<details class="issue" id="%s"><summary><b>%s</b> [%s · %s] %s <span class="badge %s">%s</span></summary><dl class="kv"><dt>출처</dt><dd>%s</dd><dt>근거 유형</dt><dd>%s</dd><dt>결과 영향</dt><dd>%s</dd><dt>조치</dt><dd>%s</dd></dl></details>',
          x$id, x$id, x$stage, x$type, esc(x$title), st_class(x$status), esc(x$status), esc(x$source), esc(x$evidence), esc(x$impact), esc(x$action))
}, ""), collapse = "\n")

ev <- stream_in(file(file.path("memory", "events.jsonl"), encoding = "UTF-8"), verbose = FALSE)
run_history <- paste0('<div class="tw"><table><thead><tr><th>시각</th><th>실행</th><th>내용</th><th>결과</th><th>조치</th></tr></thead><tbody>',
  paste(sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", esc(ev$time), esc(ev$run), esc(ev$event), esc(ev$outcome),
                esc(ifelse(is.na(ev$action), "", ev$action))), collapse = ""), "</tbody></table></div>")

audit <- fromJSON(file.path("reviews", "R1_R2_code_audit.json"))
reviews <- sprintf('<dl class="kv"><dt>코드 감사</dt><dd>%s — %s (<code>analysis/reviews/R1_R2_code_audit.json</code>)</dd><dt>독립성</dt><dd>%s</dd><dt>확인하지 않은 범위</dt><dd>%s</dd>',
                   esc(audit$reviewer), esc(audit$verdict), esc(audit$independence), esc(paste(audit$not_checked, collapse = "; ")))
bpath <- file.path("reviews", "browser_review.json")
if (file.exists(bpath)) {
  br <- fromJSON(bpath)
  reviews <- paste0(reviews, sprintf('<dt>브라우저 확인</dt><dd>%s — %s (<code>analysis/reviews/browser_review.json</code>; 확인한 HTML SHA-256 %s…)</dd>',
                                     esc(br$reviewed_at), esc(br$summary), substr(br$html_sha256, 1, 16)))
} else {
  reviews <- paste0(reviews, "<dt>브라우저 확인</dt><dd>아직 하지 않음</dd>")
}
reviews <- paste0(reviews, "</dl>")

pairs_path <- sub("^data/", "analysis/data/", names(man$derived)[1])
raw_sha <- man$inputs[["data/raw/pone.0154420.s001.xlsx"]]
md_hash_rows <- paste(sprintf("<tr><td><code>docs/learning/%s.md</code></td><td><code>%s</code></td></tr>", md_files,
                              vapply(md_files, function(id) substr(sha(file.path(DOCS, paste0(id, ".md"))), 1, 16), "")), collapse = "")
files_html <- paste0(sprintf(paste0(
  '<dl class="kv">',
  '<dt>원자료</dt><dd><code>analysis/data/raw/pone.0154420.s001.xlsx</code> · SHA-256 <code>%s</code></dd>',
  '<dt>분석 자료</dt><dd><code>%s</code> (88쌍)</dd>',
  '<dt>주 실행</dt><dd><code>analysis/runs/%s/</code> (tables, figures, models, logs, env, manifest.json) · %s</dd>',
  '<dt>탐색 실행</dt><dd><code>analysis/runs/%s/</code> (반올림 후보, post-result)</dd>',
  '<dt>계획</dt><dd><code>analysis/config/plan_%s.json</code>, <code>analysis/config/plan_%s.json</code></dd>',
  '<dt>원문 Table 1 전사</dt><dd><code>analysis/config/paper_table1_hr.csv</code></dd>',
  '<dt>코드</dt><dd><code>analysis/src/</code>, 검사 <code>analysis/tests/test_stats.R</code></dd>',
  '<dt>등록부·기록</dt><dd><code>analysis/stage_registry.json</code>, <code>analysis/memory/</code>, <code>analysis/output_coverage.json</code></dd>',
  '<dt>학습 문서</dt><dd><code>docs/learning/</code> (MD 15개, 그림 사본 <code>assets/%s/</code>)</dd>',
  '<dt>실행 프롬프트</dt><dd><code>실행프롬프트-6주차.md</code>, <code>전체실행프롬프트-v2.1.md</code> (사본: <code>analysis/config/</code>)</dd>',
  '<dt>논문·슬라이드</dt><dd><code>paper/</code> PDF (보고서와 별도 보관) · <a href="https://slides.pnucolab.com/9eGiQnmVQB7D">6주차 수정 슬라이드</a></dd>',
  '<dt>이전 HTML</dt><dd><code>history/</code> (확장자 .html.txt로 구분 보존)</dd>',
  '</dl>'),
  raw_sha, pairs_path, RUN_MAIN, esc(man$r_version), RUN_CAND, RUN_MAIN, RUN_CAND, RUN_MAIN),
  '<div class="tw"><table><thead><tr><th>보고서에 담은 MD</th><th>SHA-256 앞 16자리</th></tr></thead><tbody>', md_hash_rows, '</tbody></table></div>')

tok <- list(
  TOC_STAGES = toc_stages, RUN_ID = RUN_MAIN, CAND_RUN_ID = RUN_CAND, DATA_VERSION = man$data_version,
  BUILT_AT = format(Sys.time(), "%Y-%m-%d %H:%M"), HEADLINE = headline, CARDS = cards,
  SUMMARY_TABLE = summary_table, SUMMARY_FIG = summary_fig,
  CMP_MATCH = sum(cmp$verdict == "반올림 일치"), CMP_MISS = sum(cmp$verdict == "불일치"), CMP_NA = sum(cmp$verdict == "비교 불가"),
  RAW_SHA_SHORT = substr(raw_sha, 1, 12), READING_MAP = reading_map, STAGES = stages_html,
  PAIRS_PATH = pairs_path, PAIRS_CSV = rd(file.path("runs", RUN_MAIN, "tables", "hr01_pairs_88.csv")),
  ISSUES = issues_html, RUN_HISTORY = run_history, REVIEWS = reviews, FILES = files_html, MD_SOURCES = md_sources)

# gsub의 치환 문자열은 역슬래시를 해석하므로(MD의 \| 등) 글자 그대로 이어 붙인다
rep_lit <- function(s, pat, val) {
  repeat {
    p <- regexpr(pat, s, fixed = TRUE)
    if (p < 0) return(s)
    s <- paste0(substr(s, 1, p - 1), val, substr(s, p + nchar(pat), nchar(s)))
  }
}
html <- rd(file.path("templates", "report_shell.html"))
for (k in names(tok)) html <- rep_lit(html, paste0("@@", k, "@@"), as.character(tok[[k]]))
if (grepl("@@[A-Z_]+@@", html)) stop("채우지 못한 토큰: ", regmatches(html, regexpr("@@[A-Z_]+@@", html)))
if (grepl("(src|href)=\"(https?:)?//[^\"]*\\.(js|css)", html)) stop("외부 스크립트/스타일 참조가 있음")

if (file.exists(OUT)) {
  dir.create(HIST, showWarnings = FALSE)
  old <- file.path(HIST, paste0("최종분석보고서_", format(file.mtime(OUT), "%Y%m%d-%H%M%S"), ".html.txt"))
  invisible(file.copy(OUT, old))
}
con <- file(OUT, open = "w", encoding = "UTF-8"); writeLines(html, con); close(con)
cat("wrote", OUT, sprintf("(%.0f KB)", file.size(OUT) / 1024), "sha256", sha(OUT), "\n")
