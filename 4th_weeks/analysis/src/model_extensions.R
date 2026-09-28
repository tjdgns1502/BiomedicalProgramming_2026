# Candidate-FI sensitivity analyses. These do not reconstruct the unpublished author code.
suppressPackageStartupMessages(library(survey))
source("analysis/src/group_analysis.R")

extensions <- function(dat, design_all, out) {
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  stopifnot(!anyDuplicated(dat$SEQN), !anyDuplicated(design_all$SEQN))
  grouped <- assign_fi_groups(dat); dat <- grouped$data
  dat$age <- dat$RIDAGEYR;dat$sex <- factor(dat$RIAGENDR)
  dat$race <- factor(dat$RIDRETH1);dat$cycle_adjust <- factor(dat$cycle)
  dat$frail <- as.integer(dat$FI > .3)
  stopifnot(all(dat$age >= 50),all(dat$FI >= 0 & dat$FI <= 1))
  keep <- is.finite(design_all$weight_mec_18yr) & design_all$weight_mec_18yr>0
  base <- design_all[keep,]
  ix <- match(dat$SEQN,base$SEQN)
  if(anyNA(ix))stop("Candidate participant missing from positive-weight design; reconcile populations explicitly")
  for(v in intersect(names(dat),names(base))) {
    if(!isTRUE(all.equal(dat[[v]],base[[v]][ix],check.attributes=FALSE)))
      stop(paste("Candidate/design common column mismatch:",v))
  }
  # Preserve ALL sampled ages in the design; complete FI cohort is a subpopulation.
  cols <- setdiff(names(dat),names(base));cols <- unique(c("SEQN",cols))
  base <- merge(base,dat[,cols,drop=FALSE],by="SEQN",all.x=TRUE,sort=FALSE)
  base$eligible_candidate <- base$SEQN %in% dat$SEQN
  if (anyNA(base[,c("SDMVPSU","SDMVSTRA","weight_mec_18yr")])) stop("Incomplete survey design")
  options(survey.lonely.psu="fail")
  full <- svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~weight_mec_18yr,nest=TRUE,data=base)
  des <- subset(full,eligible_candidate)
  write.csv(data.frame(n_full=nrow(base),n_candidate=nrow(dat),design_df=degf(full),domain_df=degf(des)),
    file.path(out,"design_counts.csv"),row.names=FALSE)
  # Table 1-style description: observed N versus weighted percentages are different quantities.
  descriptions <- do.call(rbind,lapply(c("RIAGENDR","RIDRETH1","cycle","FI_group","frail"),function(v) {
    val <- dat[[v]]; w <- dat$weight_mec_18yr
    do.call(rbind,lapply(sort(unique(as.character(val))),function(level) {
      take <- as.character(val)==level
      data.frame(variable=v,level=level,n=sum(take),sample_percent=100*mean(take),
        weighted_percent=100*sum(w[take])/sum(w))
    }))
  }))
  write.csv(descriptions,file.path(out,"sample_vs_weighted_percent.csv"),row.names=FALSE)
  complete <- complete.cases(dat[,markers]) & apply(dat[,markers],1,function(x)all(is.finite(x)&x>0))
  corr <- cor(log(as.matrix(dat[complete,markers])),method="spearman")
  write.csv(corr,file.path(out,"marker_spearman.csv"))
  png(file.path(out,"marker_correlations.png"),1100,950,res=140)
  par(mar=c(4,4,3,1));image(1:4,1:4,corr,zlim=c(-1,1),col=hcl.colors(100,"Blue-Red 3"),axes=FALSE,xlab="",ylab="",main="Spearman: four CBC-derived markers")
  axis(1,1:4,markers);axis(2,1:4,markers,las=1)
  for(i in 1:4) for(j in 1:4) text(i,j,sprintf("%.2f",corr[i,j]));dev.off()
  # 29th deficit is platelets. Same participants; denominator changes to 35.
  if (!"deficit_29" %in% names(dat)) stop("Need deficit_29 for overlap sensitivity")
  dat$FI_no_platelet <- (dat$FI*36-dat$deficit_29)/35
  stopifnot(all(dat$FI_no_platelet >= -1e-10 & dat$FI_no_platelet<=1+1e-10))
  des <- update(des,FI_no_platelet=(FI*36-deficit_29)/35)
  results <- list();wald <- list();means <- list();fractional_predictions <- list();idx<-0L
  for(m in markers) {
    # Domain-specific complete cases; keep the full design for variance estimation.
    des$variables$marker_value <- des$variables[[m]]
    d_mean <- subset(des,is.finite(marker_value) & marker_value>=0)
    gm <- svyby(as.formula(paste0("~",m)),~FI_group,d_mean,svymean,na.rm=TRUE,vartype="se")
    means[[m]] <- data.frame(marker=m,group=gm$FI_group,mean=gm[[m]],se=SE(gm))
    gfit <- svyglm(as.formula(paste0(m," ~ FI_group")),d_mean)
    wt <- regTermTest(gfit,~FI_group,method="Wald")
    wald[[m]] <- data.frame(marker=m,n=nrow(d_mean$variables),p=wt$p,design_df=degf(d_mean),method="Survey Wald group means")
    des$variables$logx <- ifelse(des$variables$marker_value>0,log(des$variables$marker_value),NA_real_)
    d <- subset(des,is.finite(logx) & complete.cases(age,sex,race,cycle_adjust))
    raw <- d$variables
    run <- function(label, response, weighted=TRUE, age60=FALSE) {
      dd <- d; dd$variables$response <- response
      if(age60) dd <- subset(dd,age>=60)
      formula <- response ~ logx + age + sex + race + cycle_adjust
      fit <- if(weighted) svyglm(formula,dd,family=quasibinomial()) else glm(formula,dd$variables,family=binomial())
      b <- coef(fit)["logx"];s <- sqrt(vcov(fit)["logx","logx"])
      df <- if(weighted) fit$df.residual else Inf
      q <- qt(.975,df);p <- 2*pt(-abs(b/s),df)
      idx <<- idx+1L
      results[[idx]] <<- data.frame(marker=m,analysis=label,n=nrow(dd$variables),
        beta_logx=b,se=s,ci_low=b-q*s,ci_high=b+q*s,exp_beta=exp(b),
        exp_ci_low=exp(b-q*s),exp_ci_high=exp(b+q*s),p=p,df=df,
        convergence=fit$converged)
      if(label=="weighted_fractional_FI") {
        # Average predictions over this observed covariate distribution at two fixed exposures.
        xq <- unname(quantile(raw$logx,c(.25,.75),type=7))
        preds <- vapply(xq,function(x) {new<-raw;new$logx<-x;weighted.mean(predict(fit,newdata=new,type="response"),weights(dd))},numeric(1))
        fractional_predictions[[m]] <<- data.frame(marker=m,logx_p25=xq[1],logx_p75=xq[2],
          adjusted_mean_FI_at_p25=preds[1],adjusted_mean_FI_at_p75=preds[2],difference=diff(preds),
          uncertainty="Point estimates only; not causal and no CI computed")
      }
      invisible(fit)
    }
    run("unweighted_binary_FI_gt_0.30_model1",as.integer(raw$FI>.3),FALSE)
    for(t in c(.2,.25,.3,.35)) run(sprintf("weighted_binary_FI_gt_%.2f_model1",t),as.integer(raw$FI>t))
    run("weighted_binary_FI_gt_0.30_age60",as.integer(raw$FI>.3),TRUE,TRUE)
    run("weighted_fractional_FI",raw$FI)
    run("weighted_fractional_FI_without_platelets",raw$FI_no_platelet)
  }
  rr <- do.call(rbind,results);rr$p_BH_exploratory_all <- p.adjust(rr$p,"BH")
  write.csv(rr,file.path(out,"model_sensitivities.csv"),row.names=FALSE)
  ww <- do.call(rbind,wald);ww$p_bonferroni<-p.adjust(ww$p,"bonferroni");ww$p_BH<-p.adjust(ww$p,"BH")
  write.csv(ww,file.path(out,"survey_group_tests.csv"),row.names=FALSE)
  write.csv(do.call(rbind,means),file.path(out,"survey_group_means.csv"),row.names=FALSE)
  write.csv(do.call(rbind,fractional_predictions),file.path(out,"fractional_mean_predictions.csv"),row.names=FALSE)
  png(file.path(out,"threshold_sensitivity.png"),1500,1100,res=150)
  par(mfrow=c(2,2),mar=c(4,4,3,1))
  for(m in markers) {
    z<-rr[rr$marker==m & grepl("^weighted_binary.*model1$",rr$analysis),]
    x<-c(.2,.25,.3,.35)
    plot(x,z$exp_beta,ylim=range(z$exp_ci_low,z$exp_ci_high,1),pch=19,type="b",xlab="FI threshold (strict >)",ylab="OR per 1 log-unit marker",main=m)
    arrows(x,z$exp_ci_low,x,z$exp_ci_high,angle=90,code=3,length=.04);abline(h=1,lty=2)
  };dev.off()
  writeLines(c("All analyses use analyst-defined complete-36-item candidate FI, NOT the author FI.",
    "Survey weights correct design probabilities, not nonresponse from complete-FI selection.",
    "Weighted percentage descriptions are point estimates; no percentage CIs computed.",
    "Age and race public-use coding retained; age is topcoded; model1 only.",
    "Fractional logit targets conditional mean FI: exp(beta) is NOT odds of binary frailty.",
    "Pointwise confidence intervals; exploratory BH across 32 sensitivity coefficients shown separately.",
    "Platelet removal changes the outcome definition; it cannot prove removal of all shared-component bias.",
    "Threshold and age analyses are sensitivity, not threshold validation or evidence of optimal age cutoff.",
    "Model2, beta regression and spline replication are not asserted: unresolved definitions remain.",capture.output(sessionInfo())),file.path(out,"execution-notes.txt"))
  print(ww);print(rr)
  invisible(list(models=rr,group_tests=ww))
}
if(sys.nframe()==0L) {
  a<-commandArgs(trailingOnly=TRUE)
  if(length(a)!=3)stop("model_extensions.R candidate.csv all_design.csv output_dir")
  extensions(read.csv(a[1]),read.csv(a[2]),a[3])
}
