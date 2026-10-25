## 50_figures.R -----------------------------------------------------------
## Week 5 figures not made by R/40-41:
##   50_mosaic_oral_htn.png        mosaic plot, oral health x hypertension,
##                                 one panel per smoking stratum; tile area =
##                                 count, fill = Pearson residual under
##                                 independence within the stratum
##   50_pearson_residuals.png      Pearson residuals (obs - exp) / sqrt(exp)
##                                 of oral health x HTN, all and each stratum,
##                                 value written in every cell
##   50_forest_paper_vs_ours.png   Tables 2/3 ORs, paper vs ours, Models 1-3;
##                                 the paper's swapped Table 2 Model 1 oral
##                                 cells (R/34) are marked
## Counts are the unweighted counts of our domain (n = 21,399): the mosaic and
## the residuals describe the contingency table itself, not the population.
## Colours: dataviz reference palette - diverging blue <-> red with a grey
## midpoint for residuals (sign is the information), categorical slots 1-2
## for paper vs ours.
##
## Rscript R/50_figures.R
## ------------------------------------------------------------------------

suppressPackageStartupMessages(library(ggplot2))

PROJ <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(file.path(dirname(f), "..")) else normalizePath(".")
}, error = function(e) normalizePath("."))
TAB_DIR <- file.path(PROJ, "output", "tables")
FIG_DIR <- file.path(PROJ, "output", "figures")
source(file.path(PROJ, "R", "model_utils.R"))

COL <- c(blue = "#2a78d6", orange = "#eb6834", red = "#e34948", mid = "#f0efec")
INK <- c(primary = "#0b0b0b", secondary = "#52514e", muted = "#898781",
         grid = "#e1e0d9", axis = "#c3c2b7", surface = "#fcfcfb")
theme_chart <- function() theme_minimal(base_size = 10) + theme(
  plot.background = element_rect(fill = INK[["surface"]], colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = INK[["grid"]], linewidth = 0.3),
  axis.text = element_text(colour = INK[["muted"]]),
  axis.title = element_text(colour = INK[["secondary"]]),
  plot.title = element_text(colour = INK[["primary"]], face = "bold"),
  plot.subtitle = element_text(colour = INK[["secondary"]]),
  legend.text = element_text(colour = INK[["secondary"]]),
  legend.title = element_text(colour = INK[["secondary"]]),
  strip.text = element_text(colour = INK[["primary"]], face = "bold"),
  legend.position = "top")

v <- load_domain(PROJ)$variables
v <- v[v$domain, ]
v$htn_lab <- factor(v$htn, levels = c(0, 1), labels = c("No HTN", "HTN"))
STRATA <- list(All = rep(TRUE, nrow(v)),
               "Non-smoking" = v$smoke == "No", Smoking = v$smoke == "Yes",
               "Age < 45" = v$age < 45, "Age ≥ 45" = v$age >= 45)

## --- contingency cells with Pearson residuals ------------------------------
cells <- do.call(rbind, lapply(names(STRATA), function(s) {
  tb <- table(v$oral4[STRATA[[s]]], v$htn_lab[STRATA[[s]]])
  ct <- suppressWarnings(chisq.test(tb, correct = FALSE))
  d <- as.data.frame(tb, responseName = "n")
  names(d)[1:2] <- c("oral", "htn")
  d$expected <- as.vector(ct$expected)
  d$resid <- as.vector(ct$residuals)
  d$stratum <- s
  ## mosaic geometry: x = oral share of the stratum, y = P(HTN | oral)
  w <- prop.table(rowSums(tb))
  x1 <- cumsum(w); x0 <- x1 - w
  ph <- prop.table(tb, 1)
  d$xmin <- x0[d$oral]; d$xmax <- x1[d$oral]
  d$ymin <- ifelse(d$htn == "No HTN", 0, ph[cbind(as.character(d$oral), "No HTN")])
  d$ymax <- ifelse(d$htn == "No HTN", ph[cbind(as.character(d$oral), "No HTN")], 1)
  d
}))
cells$stratum <- factor(cells$stratum, levels = names(STRATA))
write.csv(cells[, c("stratum", "oral", "htn", "n", "expected", "resid")],
          file.path(TAB_DIR, "50_pearson_residuals.csv"), row.names = FALSE)
lim <- max(abs(cells$resid))
resid_fill <- scale_fill_gradient2(low = COL[["blue"]], mid = COL[["mid"]],
                                   high = COL[["red"]], midpoint = 0,
                                   limits = c(-lim, lim),
                                   name = "Pearson residual")

## --- (1) mosaic, smoking strata ------------------------------------------
GAP <- 0.006   # 2px-like surface gap between tiles
mz <- cells[cells$stratum %in% c("Non-smoking", "Smoking"), ]
lab_x <- unique(mz[, c("stratum", "oral", "xmin", "xmax")])
g1 <- ggplot(mz) +
  geom_rect(aes(xmin = xmin + GAP, xmax = xmax - GAP, ymin = ymin + GAP,
                ymax = ymax - GAP, fill = resid)) +
  resid_fill +
  geom_text(data = lab_x, aes(x = (xmin + xmax) / 2, y = -0.04, label = oral),
            size = 2.8, colour = INK[["secondary"]]) +
  geom_text(data = mz[mz$oral == "Excellent/Very good", ],
            aes(x = -0.02, y = (ymin + ymax) / 2, label = htn), hjust = 1,
            size = 2.8, colour = INK[["secondary"]]) +
  facet_wrap(~ stratum, ncol = 1) +
  scale_x_continuous(limits = c(-0.12, 1), breaks = NULL) +
  scale_y_continuous(limits = c(-0.08, 1), breaks = NULL) +
  labs(x = "Oral health (column width = share of the stratum)",
       y = "Hypertension (height = conditional share)",
       title = "Oral health x hypertension, by smoking",
       subtitle = "Mosaic: tile area = count. Red: more than expected under independence; blue: fewer.") +
  theme_chart() + theme(panel.grid.major = element_blank())
ggsave(file.path(FIG_DIR, "50_mosaic_oral_htn.png"), g1, width = 8, height = 7, dpi = 150)

## --- (2) Pearson residual heatmap ------------------------------------------
g2 <- ggplot(cells, aes(htn, oral, fill = resid)) +
  geom_tile(colour = INK[["surface"]], linewidth = 1) +
  geom_text(aes(label = sprintf("%+.1f", resid)), size = 3, colour = INK[["primary"]]) +
  resid_fill +
  scale_y_discrete(limits = rev) +
  facet_wrap(~ stratum, nrow = 1) +
  labs(x = NULL, y = "Oral health",
       title = "Pearson residuals, oral health x hypertension",
       subtitle = "(observed - expected) / sqrt(expected) under independence within each stratum; |r| > 2 is notable.") +
  theme_chart() + theme(panel.grid.major = element_blank())
ggsave(file.path(FIG_DIR, "50_pearson_residuals.png"), g2, width = 10, height = 3.8, dpi = 150)

## --- (3) forest: paper vs ours ---------------------------------------------
ors <- read.csv(file.path(TAB_DIR, "30_models.csv"))
ors <- ors[!is.na(ors$lo), ]
STR_LAB <- c(all = "All", nonsmoking = "Non-smoking", smoking = "Smoking",
             "age<45" = "Age < 45", "age>=45" = "Age ≥ 45")
LV <- c(Good = "Oral: Good", Fair = "Oral: Fair", Poor = "Oral: Poor", Yes = "Periodontal: Yes")
fp <- rbind(
  data.frame(ors[, c("stratum", "model", "level")], source = "Ours",
             est = ors$or, lo = ors$lo, hi = ors$hi),
  data.frame(ors[, c("stratum", "model", "level")], source = "Paper",
             est = ors$paper_or, lo = ors$paper_lo, hi = ors$paper_hi))
fp$swapped <- fp$source == "Paper" & fp$model == 1 &
              fp$stratum %in% c("nonsmoking", "smoking") & fp$level != "Yes"
fp$stratum <- factor(STR_LAB[fp$stratum], levels = STR_LAB)
fp$contrast <- factor(LV[fp$level], levels = LV)
fp$model <- factor(paste("Model", fp$model))
fp$source <- factor(fp$source, levels = c("Paper", "Ours"))
g3 <- ggplot(fp, aes(est, contrast, colour = source)) +
  geom_vline(xintercept = 1, colour = INK[["axis"]], linewidth = 0.4) +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.2, linewidth = 0.5,
                  position = position_dodge(width = 0.6)) +
  geom_point(data = fp[fp$swapped, ], shape = 4, size = 2.6, stroke = 0.9,
             colour = INK[["primary"]], position = position_nudge(y = 0.15)) +
  scale_colour_manual(values = c(Paper = COL[["blue"]], Ours = COL[["orange"]]), name = NULL) +
  scale_x_log10(breaks = c(1, 1.5, 2, 3)) +
  scale_y_discrete(limits = rev) +
  facet_grid(stratum ~ model, switch = "y") +
  labs(x = "Odds ratio of hypertension (log scale, 95% CI)", y = NULL,
       title = "Tables 2 and 3: paper vs reproduction",
       subtitle = "× = paper's Table 2 Model 1 oral-health cells, printed under the other smoking stratum (R/34).") +
  theme_chart() + theme(strip.placement = "outside",
                        strip.text.y.left = element_text(angle = 0, hjust = 1))
ggsave(file.path(FIG_DIR, "50_forest_paper_vs_ours.png"), g3, width = 9.5, height = 9, dpi = 150)

cat("figures written: 50_mosaic_oral_htn.png, 50_pearson_residuals.png,",
    "50_forest_paper_vs_ours.png\n")
print(within(cells[, c("stratum", "oral", "htn", "n", "resid")], resid <- round(resid, 2)),
      row.names = FALSE)
