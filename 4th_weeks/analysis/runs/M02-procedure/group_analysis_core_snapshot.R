# Educational FI-quartile comparisons. Functions are also used by procedure tests.
# This is unweighted analysis; survey extensions must be reported separately.

markers <- c("NLR", "MLR", "SIRI", "SII")
hc3 <- function(fit) {
  X <- model.matrix(fit)
  if (qr(X)$rank < ncol(X)) stop("Rank-deficient trend design")
  h <- hatvalues(fit)
  if (any(h >= 1 - 1e-10)) stop("Unit leverage invalidates HC3")
  bread <- solve(crossprod(X))
  u <- residuals(fit) / (1 - h)
  bread %*% crossprod(X * as.vector(u)) %*% bread
}

assign_fi_groups <- function(dat) {
  if (!"FI" %in% names(dat) || !is.numeric(dat$FI)) stop("Numeric FI column required")
  if (any(is.finite(dat$FI) & (dat$FI < 0 | dat$FI > 1))) stop("FI outside [0,1]")
  dat <- dat[is.finite(dat$FI), , drop=FALSE]
  cuts <- unname(quantile(dat$FI, c(.25,.5,.75), type=7))
  if (anyDuplicated(cuts)) stop("Duplicate FI quartile boundaries: no arbitrary tie split")
  dat$FI_group <- cut(dat$FI, breaks=c(-Inf,cuts,Inf), labels=paste0("Q",1:4), right=TRUE)
  if (any(table(dat$FI_group) < 2)) stop("Fewer than two participants in an FI group")
  med <- tapply(dat$FI, dat$FI_group, median)
  dat$FI_score <- as.numeric(med[as.character(dat$FI_group)])
  list(data=dat, cuts=cuts, group_medians=med)
}

comparison_core <- function(d, marker) {
  if (any(table(d$group)<2)) stop(paste(marker,"has insufficient group observations"))
  fit <- aov(y ~ group, d)
  omnibus <- data.frame(marker=marker, method=c("ANOVA","Welch","Kruskal-Wallis"),
    n=nrow(d), p=c(summary(fit)[[1]][1,"Pr(>F)"],
      oneway.test(y~group,d,var.equal=FALSE)$p.value,kruskal.test(y~group,d)$p.value))
  pairs <- combn(levels(d$group),2,simplify=FALSE)
  pairwise <- do.call(rbind,lapply(pairs,function(g) {
    # higher FI group minus lower FI group; CI is pointwise, not multiplicity adjusted.
    x <- d$y[d$group==g[2]];y <- d$y[d$group==g[1]]
    z <- t.test(x,y,var.equal=FALSE)
    data.frame(marker=marker,contrast=paste(g[2],g[1],sep="-"),
      estimate=mean(x)-mean(y),ci_low=z$conf.int[1],ci_high=z$conf.int[2],
      df=unname(z$parameter),p=z$p.value,n_high=length(x),n_low=length(y))
  }))
  list(fit=fit,omnibus=omnibus,pairwise=pairwise)
}

compare_marker <- function(dat, marker) {
  d <- data.frame(y=dat[[marker]], group=dat$FI_group, score=dat$FI_score)
  d <- d[is.finite(d$y), , drop=FALSE]
  if (any(d$y < 0)) stop(paste(marker,"contains negative values"))
  core <- comparison_core(d,marker)
  fit <- core$fit;omnibus <- core$omnibus;pairwise <- core$pairwise
  summaries <- do.call(rbind,lapply(levels(d$group),function(g) {
    y <- d$y[d$group==g]
    data.frame(marker=marker,group=g,n=length(y),mean=mean(y),sd=sd(y),
      median=median(y),p25=unname(quantile(y,.25)),p75=unname(quantile(y,.75)))
  }))
  tu <- TukeyHSD(fit,"group")$group
  tukey <- data.frame(marker=marker,contrast=rownames(tu),estimate=tu[,"diff"],
    ci_low=tu[,"lwr"],ci_high=tu[,"upr"],p_tukey_within_marker=tu[,"p adj"],row.names=NULL)
  tf <- lm(y~score,d);V <- hc3(tf);b <- coef(tf)["score"];se <- sqrt(V["score","score"])
  df <- df.residual(tf);q <- qt(.975,df)
  trend <- data.frame(marker=marker,n=nrow(d),slope_per_FI_unit=unname(b),
    se_HC3=se,df=df,ci_low=b-q*se,ci_high=b+q*se,p=2*pt(-abs(b/se),df))
  list(summary=summaries,omnibus=omnibus,pairwise=pairwise,tukey=tukey,trend=trend,fit=fit,data=d)
}

analyze_groups <- function(dat, out=NULL, make_plots=TRUE) {
  if (!all(markers %in% names(dat))) stop("Need NLR, MLR, SIRI, SII columns")
  if (!all(vapply(dat[markers],is.numeric,logical(1)))) stop("Markers must be numeric")
  grouped <- assign_fi_groups(dat)
  result <- setNames(lapply(markers,function(m) compare_marker(grouped$data,m)),markers)
  bind <- function(k) do.call(rbind,lapply(result,`[[`,k))
  tables <- lapply(c("summary","omnibus","pairwise","tukey","trend"),bind)
  names(tables) <- c("summary","omnibus","pairwise","tukey","trend")
  primary <- tables$omnibus[tables$omnibus$method=="Welch",]
  adjust <- function(z,family) {
    z$family_id <- family;z$p_bonferroni <- p.adjust(z$p,"bonferroni");z$p_BH <- p.adjust(z$p,"BH");z
  }
  tables$primary <- adjust(primary,"F_omnibus_4")
  tables$pairwise <- adjust(tables$pairwise,"F_pairs_24")
  tables$trend <- adjust(tables$trend,"F_trend_4")
  if (!is.null(out)) {
    dir.create(out,recursive=TRUE,showWarnings=FALSE)
    for (k in names(tables)) write.csv(tables[[k]],file.path(out,paste0(k,".csv")),row.names=FALSE)
    write.csv(data.frame(prob=c(.25,.5,.75),FI=grouped$cuts),file.path(out,"quartile_boundaries.csv"),row.names=FALSE)
    write.csv(data.frame(group=names(grouped$group_medians),median_FI=as.numeric(grouped$group_medians),
      n=as.numeric(table(grouped$data$FI_group))),file.path(out,"group_membership_summary.csv"),row.names=FALSE)
    if (make_plots) {
      png(file.path(out,"boxplots.png"),width=1500,height=1100,res=150)
      par(mfrow=c(2,2),mar=c(4,4,3,1))
      for (m in markers) boxplot(grouped$data[[m]]~grouped$data$FI_group,
        xlab="FI quartile group",ylab=m,main=paste(m,"by FI quartile"),col="#b5dcd9")
      dev.off()
      for (m in markers) {
        png(file.path(out,paste0("diagnostics_",m,".png")),width=1500,height=1100,res=150)
        par(mfrow=c(2,2));plot(result[[m]]$fit,which=c(1,2,3,5));dev.off()
      }
      png(file.path(out,"means_with_pointwise_CI.png"),width=1500,height=1100,res=150)
      par(mfrow=c(2,2),mar=c(4,4,3,1))
      for (m in markers) {
        z <- subset(tables$summary,marker==m);e <- qt(.975,z$n-1)*z$sd/sqrt(z$n)
        plot(1:4,z$mean,ylim=range(z$mean-e,z$mean+e),xaxt="n",xlab="FI group",ylab=m,main="Mean and pointwise 95% CI",pch=19)
        axis(1,1:4,paste0("Q",1:4));arrows(1:4,z$mean-e,1:4,z$mean+e,angle=90,code=3,length=.05)
      };dev.off()
    }
  }
  list(tables=tables,grouped=grouped,marker_results=result)
}

if (sys.nframe()==0L) {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args)!=2L) stop("Usage: Rscript group_analysis.R input.csv output_dir")
  dat <- read.csv(args[1],check.names=FALSE)
  result <- analyze_groups(dat,args[2])
  saveRDS(result,file.path(args[2],"analysis.rds"))
  writeLines(c("Educational unweighted sample analysis. Not automatic population inference.",
    "FI boundaries: type 7, tied scores kept together; higher minus lower contrast.",
    "Pairwise Welch CIs pointwise; Tukey intervals simultaneous within each marker only.",
    "Three separate families do not control a single global claim across all families.",
    capture.output(sessionInfo())),file.path(args[2],"execution-notes.txt"))
  print(result$tables$primary);print(result$tables$trend)
}
