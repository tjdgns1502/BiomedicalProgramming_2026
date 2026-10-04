Sys.setlocale('LC_ALL','English_United States.utf8')
args<-commandArgs(trailingOnly=TRUE);root<-args[1];out<-args[2]
.libPaths(c(file.path(root,'analysis/r-library'),.libPaths()))
library(survey);library(jsonlite);library(digest)
run<-file.path(root,'analysis/runs/R2-20261004')
master<-readRDS(file.path(run,'derived/master.rds'))
full<-master[master$mec_design_eligible,]
full$SDMVPSU<-as.numeric(full$SDMVPSU);full$SDMVSTRA<-as.numeric(full$SDMVSTRA)
D<-master[master$analysis_domain,]
checks<-list();details<-list()
near<-function(a,b,tol=1e-8) length(a)==length(b)&&all(is.finite(a))&&all(is.finite(b))&&max(abs(a-b))<=tol
add<-function(name,pass,detail='') checks[[length(checks)+1L]]<<-data.frame(check=name,pass=pass,detail=detail)
psu<-unique(full[,c('SDMVSTRA','SDMVPSU')]);psu$key<-paste(psu$SDMVSTRA,psu$SDMVPSU,sep=':')
cluster_cov<-function(influence,records) {
  cluster_sums<-rowsum(influence,paste(records$SDMVSTRA,records$SDMVPSU,sep=':'),reorder=FALSE)
  all_sums<-matrix(0,nrow(psu),ncol(influence))
  all_sums[match(rownames(cluster_sums),psu$key),]<-cluster_sums
  V<-matrix(0,ncol(influence),ncol(influence))
  for(idx in split(seq_len(nrow(psu)),psu$SDMVSTRA)) {
    z<-all_sums[idx,,drop=FALSE];m<-nrow(z)
    centered<-sweep(z,2,colMeans(z),'-')
    V<-V+m/(m-1)*crossprod(centered)
  }
  V
}
design_df<-nrow(psu)-length(unique(psu$SDMVSTRA))
add('design_df_independent',design_df==78 && all(table(psu$SDMVSTRA)>=2),paste('PSU=',nrow(psu),'strata=',length(unique(psu$SDMVSTRA))))
add('weight_definition',near(full$mec_weight,full$WTMEC2YR/5) && all(full$mec_weight>0))
add('domain_selection_contract',all(D$age>=30) && all(D$n_valid_sbp>=1 & D$n_valid_dbp>=1) && !anyNA(D$periodontal) && !anyNA(D$oral_health) && !anyNA(D$smoking) && !anyNA(D$hypertension_code))
report<-read_json(file.path(run,'report.json'),simplifyVector=TRUE)
saved<-read.csv(file.path(run,'tables/model1_coefficients.csv'))
metadata<-read_json(file.path(run,'models/model_metadata.json'),simplifyVector=TRUE)
design<-NULL
for(exposure in c('periodontal','oral_health')) {
  key<-paste0('Model1_',exposure)
  fit<-readRDS(file.path(run,'models',paste0(key,'.rds')))
  expected_formula<-reformulate(c(exposure,'age','sex','race','education'),response='hypertension_code')
  mf<-model.frame(expected_formula,D,drop.unused.levels=TRUE,na.action=na.fail)
  X<-model.matrix(expected_formula,mf);y<-model.response(mf);w<-D$mec_weight/mean(D$mec_weight)
  beta<-rep(0,ncol(X))
  for(iter in seq_len(40)) {
    mu<-plogis(drop(X%*%beta));A<-crossprod(X,X*as.numeric(w*mu*(1-mu)))
    step<-solve(A,crossprod(X,w*(y-mu)))
    beta<-beta+drop(step)
    if(max(abs(step))<1e-11) break
  }
  mu<-plogis(drop(X%*%beta));A<-crossprod(X,X*as.numeric(w*mu*(1-mu)))
  bread<-solve(A);meat<-cluster_cov(X*as.numeric(w*(y-mu)),D)
  robust<-bread%*%meat%*%bread;se<-sqrt(diag(robust))
  # The saved glm QR uses its final stored IRLS working weights, computed one
  # iteration before the updated coefficient vector. survey::svy.varcoef uses
  # these weights and the stored working residuals. Match that convention using
  # an independently assembled stratum/PSU covariance rather than svyrecvar.
  working_bread<-solve(crossprod(X,X*as.numeric(fit$weights)))
  working_meat<-cluster_cov(X*as.numeric(fit$residuals*fit$weights),D)
  working_robust<-working_bread%*%working_meat%*%working_bread
  z<-saved[saved$exposure==exposure,];z<-z[match(colnames(X),z$term),]
  df<-design_df+1-ncol(X)
  add(paste0(key,'_formula'),identical(all.vars(formula(fit)),all.vars(expected_formula)))
  add(paste0(key,'_fit_converged_finite'),isTRUE(fit$converged)&&all(is.finite(coef(fit)))&&all(is.finite(se)&se>0))
  add(paste0(key,'_independent_beta'),near(beta,coef(fit),1e-7),paste('max error',max(abs(beta-coef(fit)))))
  add(paste0(key,'_independent_sandwich_saved_IRLS'),near(working_robust,vcov(fit),1e-8),paste('max error',max(abs(working_robust-vcov(fit)))))
  add(paste0(key,'_df_contract'),fit$df.residual==df&&metadata[[key]]$residual_df==df&&fit$rank==ncol(X)&&all(z$model_residual_df==df))
  add(paste0(key,'_csv_coefficients'),near(z$log_odds,coef(fit))&&near(z$se,sqrt(diag(vcov(fit)))))
  add(paste0(key,'_t_p_OR_CI'),near(z$t_statistic,z$log_odds/z$se)&&near(z$p_value,2*pt(abs(z$log_odds/z$se),df,lower.tail=FALSE))&&near(z$odds_ratio,exp(z$log_odds))&&near(z$ci_low,exp(z$log_odds-qt(.975,df)*z$se))&&near(z$ci_high,exp(z$log_odds+qt(.975,df)*z$se)))
  add(paste0(key,'_design_ids_weights'),near(as.numeric(weights(fit$survey.design)),D$mec_weight)&&identical(as.numeric(fit$survey.design$variables$SEQN),as.numeric(D$SEQN))&&degf(fit$survey.design)==design_df)
  details[[key]]<-list(beta_max_error=max(abs(beta-coef(fit))),saved_IRLS_cov_max_error=max(abs(working_robust-vcov(fit))),final_mu_cov_max_error=max(abs(robust-vcov(fit))),stored_working_weights_relative_difference=max(abs(fit$weights/(w*mu*(1-mu))-1)),rank=ncol(X),residual_df=df,score_max=max(abs(crossprod(X,w*(y-mu)))))
  design<-fit$survey.design
}
all_design<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~mec_weight,data=full,nest=TRUE)
fresh<-subset(all_design,analysis_domain)
add('domain_design_matches_fresh_full_subset',degf(fresh)==design_df&&isTRUE(all.equal(fresh$cluster,design$cluster))&&isTRUE(all.equal(fresh$strata,design$strata))&&near(as.numeric(weights(fresh)),as.numeric(weights(design))))
weighted_mean<-function(v,records) {
  x<-records[[v]];w<-records$mec_weight;ok<-is.finite(x);x<-x[ok];w<-w[ok];records<-records[ok,]
  m<-sum(w*x)/sum(w)
  se<-sqrt(cluster_cov(matrix(w*(x-m)/sum(w),ncol=1),records)[1,1])
  c(mean=m,se=se)
}
tc<-read.csv(file.path(run,'tables/table1_continuous.csv'))
for(i in seq_len(nrow(tc))) {
  g<-tc$hypertension_group[i];data<-if(g=='All') D else D[D$hypertension==g,]
  est<-weighted_mean(tc$variable[i],data)
  add(paste0('weighted_mean_SE_',tc$variable[i],'_',g),near(c(tc$weighted_mean[i],tc$weighted_mean_se[i]),est))
}
cat_table<-read.csv(file.path(run,'tables/table1_categorical.csv'))
for(variable in unique(cat_table$variable)) {
  z<-cat_table[cat_table$variable==variable,]
  ok<-TRUE
  for(i in seq_len(nrow(z))) {
    g<-z$hypertension_group[i];data<-if(g=='All') D else D[D$hypertension==g,]
    data$.indicator<-as.numeric(data[[variable]]==z$level[i])
    est<-weighted_mean('.indicator',data)*100
    ok<-ok&&near(c(z$weighted_percent[i],z$weighted_percent_se[i]),est)
  }
  add(paste0('weighted_category_percent_SE_',variable),ok)
}
tests<-read.csv(file.path(run,'tables/categorical_tests.csv'))
for(variable in unique(tests$variable)) {
  T<-table(droplevels(D[[variable]]),D$hypertension);T<-T[rowSums(T)>0,colSums(T)>0,drop=FALSE]
  expected<-outer(rowSums(T),colSums(T))/sum(T);chisq<-sum((T-expected)^2/expected);df<-(nrow(T)-1)*(ncol(T)-1)
  z<-tests[tests$variable==variable,]
  p<-z[z$method=='Naive Pearson chi-square',]
  add(paste0('naive_Pearson_',variable),near(p$statistic,chisq)&&near(p$p_value,pchisq(chisq,df,lower.tail=FALSE)))
  d<-fresh;d$variables[[variable]]<-droplevels(d$variables[[variable]])
  rs<-svychisq(reformulate(c(variable,'hypertension')),d,statistic='F');q<-z[z$method=='Survey Rao-Scott adjusted F',]
  add(paste0('Rao_Scott_',variable),near(q$statistic,as.numeric(rs$statistic))&&near(c(q$df1,q$df2),as.numeric(rs$parameter))&&near(q$p_value,pf(q$statistic,q$df1,q$df2,lower.tail=FALSE)))
}
ct<-read.csv(file.path(run,'tables/continuous_tests.csv'))
for(variable in unique(ct$variable)) {
  q<-ct[ct$variable==variable&ct$method=='Survey design t',]
  d<-D;d$.group<-as.numeric(d$hypertension=='Yes')
  no<-d[d$.group==0,];yes<-d[d$.group==1,]
  m0<-sum(no$mec_weight*no[[variable]])/sum(no$mec_weight)
  m1<-sum(yes$mec_weight*yes[[variable]])/sum(yes$mec_weight)
  infl<-ifelse(d$.group==1,d$mec_weight*(d[[variable]]-m1)/sum(yes$mec_weight),-d$mec_weight*(d[[variable]]-m0)/sum(no$mec_weight))
  tt<-(m1-m0)/sqrt(cluster_cov(matrix(infl,ncol=1),d)[1,1])
  add(paste0('survey_t_',variable),near(q$statistic,tt)&&q$df==design_df-1&&near(q$p_value,2*pt(abs(tt),design_df-1,lower.tail=FALSE)))
}
results<-do.call(rbind,checks)
write.csv(results,file.path(out,'R2_independent_checks.csv'),row.names=FALSE)
write_json(details,file.path(out,'R2_model_check_details.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(results);cat('ALL_PASS',all(results$pass),'CHECKS',nrow(results),'\n')
if(!all(results$pass))quit(status=1)
