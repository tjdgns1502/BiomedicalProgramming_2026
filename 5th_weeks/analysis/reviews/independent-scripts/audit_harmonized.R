Sys.setlocale('LC_ALL','English_United States.utf8')
args<-commandArgs(trailingOnly=TRUE);root<-args[1];out<-args[2]
.libPaths(c(file.path(root,'analysis/r-library'),.libPaths()))
library(survey);library(jsonlite);library(digest)
run<-file.path(root,'analysis/runs/E2-20261004')
master<-readRDS(file.path(run,'derived/master.rds'))
checks<-list();diagnostics<-list()
near<-function(a,b,tol=1e-8)length(a)==length(b)&&identical(unname(is.na(a)),unname(is.na(b)))&&all(is.finite(a[!is.na(a)]))&&all(is.finite(b[!is.na(b)]))&&(!length(a[!is.na(a)])||max(abs(a-b),na.rm=TRUE)<=tol)
add<-function(name,pass,detail='')checks[[length(checks)+1]]<<-data.frame(check=name,pass=isTRUE(pass),detail=detail)
csv<-read.csv(file.path(run,'tables/all_model_coefficients.csv'))
trend<-read.csv(file.path(run,'tables/oral_trend_tests.csv'))
interaction<-read.csv(file.path(run,'tables/interaction_coefficients.csv'))
joint<-read.csv(file.path(run,'tables/interaction_joint_wald.csv'))
counts<-read.csv(file.path(run,'tables/model_sample_counts_formulas.csv'))
designs<-list();PSUs<-list()
for(cand in c('A','B')) {
  full<-master[if(cand=='A')master$mec_design_eligible else master$diet_design_eligible,]
  full$.weight<-if(cand=='A')full$mec_weight else full$diet_weight
  full$SDMVPSU<-as.numeric(full$SDMVPSU);full$SDMVSTRA<-as.numeric(full$SDMVSTRA)
  d<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~.weight,data=full,nest=TRUE)
  flag<-if(cand=='A')full$analysis_domain else full$dietary_sensitivity_domain
  designs[[cand]]<-d[flag,]
  p<-unique(full[,c('SDMVSTRA','SDMVPSU')]);p$key<-paste(p$SDMVSTRA,p$SDMVPSU,sep=':');PSUs[[cand]]<-p
  add(paste0(cand,'_full_design_domain'),degf(d)==78&&degf(designs[[cand]])==78&&nrow(designs[[cand]]$variables)==if(cand=='A')21458 else 19925)
}
get_data<-function(m) {
  d<-designs[[m$candidate]]
  if(m$family=='supplement_measured')d<-d[!is.na(d$variables$diagnosed_or_treated_htn)&d$variables$diagnosed_or_treated_htn==0,]
  if(m$family=='supplement_diagnosed_treated')d<-d[(!is.na(d$variables$diagnosed_or_treated_htn)&d$variables$diagnosed_or_treated_htn==1)|d$variables$hypertension_code==0,]
  if(m$subgroup!='Overall') {
    flag<-if(m$family=='table3')d$variables$age_group==m$subgroup else d$variables$smoking==m$subgroup
    d<-d[!is.na(flag)&flag,]
  }
  d[!is.na(d$variables[[m$outcome]]),]
}
base<-c('age','sex','race','education');add2<-c('bmi_category','sleep_category','alcohol_category','activity_category')
labs<-unlist(lapply(c('total_cholesterol','creatinine','triglycerides_biopro','hba1c','hdl'),function(x)paste0(x,c('_filled','_missing'))))
expected_vars<-function(m) {
  x<-if(m$family=='table3')setdiff(base,'age') else base
  if(m$model!='Model1') {
    x<-c(x,add2)
    if(m$family=='table3')x<-c(x,'smoking')
    if(m$family=='table2')x<-c(x,'cvd_category','diabetes_category','sodium_filled','sodium_missing','fat_filled','fat_missing')
  }
  if(m$model=='Model3')x<-c(x,labs)
  c(m$outcome,m$exposure,x)
}
matrix_cov<-function(influence,D,cand) {
  p<-PSUs[[cand]];z<-rowsum(influence,paste(D$SDMVSTRA,D$SDMVPSU,sep=':'),reorder=FALSE)
  full<-matrix(0,nrow(p),ncol(influence));full[match(rownames(z),p$key),]<-z
  V<-matrix(0,ncol(influence),ncol(influence))
  for(idx in split(seq_len(nrow(p)),p$SDMVSTRA)) {
    a<-full[idx,,drop=FALSE];n<-nrow(a);a<-sweep(a,2,colMeans(a),'-');V<-V+n/(n-1)*crossprod(a)
  };V
}
selected<-c('A_table2_Overall_Model3_oral_health_hypertension_code','B_table2_Overall_Model3_periodontal_hypertension_code',
 'A_table3_30-44_Model3_periodontal_hypertension_code','A_supplement_measured_Overall_Model3_periodontal_measured_htn','A_interaction_oral_health_smoking')
files<-list.files(file.path(run,'models'),pattern='_lean.rds$',full.names=TRUE)
reused<-files[grepl('_Model[12]_',basename(files))]
oldrun<-file.path(root,'analysis/runs/E1-20261004')
for(path in reused)add(paste0(basename(path),'_reused_exact_bytes'),identical(digest(file=path,algo='sha256',serialize=FALSE),digest(file=file.path(oldrun,'models',basename(path)),algo='sha256',serialize=FALSE)))
files<-files[grepl('_Model3_|_interaction_',basename(files))]
for(path in files) {
  label<-sub('_lean.rds$','',basename(path));f<-readRDS(path);b<-f$coefficients;V<-f$vcov
  add(paste0(label,'_current_data_version'),identical(f$data_version,unique(master$data_version)))
  if(match(path,files)%%12==0)cat('AUDIT PROGRESS',match(path,files),'of',length(files),'\n')
  add(paste0(label,'_finite_covariance'),f$converged&&all(is.finite(b))&&all(is.finite(V))&&all(diag(V)>0)&&near(V,t(V),1e-9))
  is_int<-grepl('_interaction_',label,fixed=TRUE)
  if(is_int) {
    parts<-strsplit(label,'_',fixed=TRUE)[[1]];cand<-parts[1];modifier<-if(grepl('age_group$',label))'age_group'else'smoking'
    exposure<-if(grepl('oral_health',label,fixed=TRUE))'oral_health'else'periodontal'
    d<-designs[[cand]];formula<-as.formula(f$formula)
    expected<-c('hypertension_code',exposure,modifier,if(modifier=='smoking')c(base,add2,'cvd_category','diabetes_category','sodium_filled','sodium_missing','fat_filled','fat_missing',labs)else c(setdiff(base,'age'),add2,'smoking',labs))
    add(paste0(label,'_formula'),setequal(all.vars(formula),expected)&&grepl(paste0(exposure,' * ',modifier),f$formula,fixed=TRUE))
    z<-interaction[interaction$candidate==cand&interaction$exposure==exposure&interaction$modifier==modifier,]
    q<-joint[joint$candidate==cand&joint$exposure==exposure&joint$modifier==modifier,]
    ix<-grep(':',names(b),fixed=TRUE);Fval<-drop(t(b[ix])%*%solve(V[ix,ix,drop=FALSE],b[ix]))/length(ix)
    add(paste0(label,'_joint_Wald_F'),near(q$statistic_F,Fval)&&q$numerator_df==length(ix)&&q$denominator_df==f$residual_df&&near(q$p_value,pf(Fval,length(ix),f$residual_df,lower.tail=FALSE)))
  } else {
    m<-f$metadata;cand<-m$candidate;d<-get_data(m);formula<-as.formula(f$formula)
    add(paste0(label,'_formula'),setequal(all.vars(formula),expected_vars(m)))
    if(m$exposure=='oral_score')z<-trend[trend$candidate==cand&trend$family==m$family&trend$subgroup==m$subgroup&trend$model==m$model,]
    else z<-csv[csv$candidate==cand&csv$family==m$family&csv$subgroup==m$subgroup&csv$model==m$model&csv$exposure==m$exposure,]
    if(m$exposure!='oral_score') {
      q<-counts[counts$candidate==cand&counts$family==m$family&counts$subgroup==m$subgroup&counts$model==m$model&counts$exposure==m$exposure,]
      add(paste0(label,'_sample_cases_controls'),q$n==nrow(d$variables)&&q$cases_n==sum(d$variables[[m$outcome]]==1)&&q$controls_n==sum(d$variables[[m$outcome]]==0))
    }
  }
  mf<-model.frame(formula,d$variables,drop.unused.levels=TRUE,na.action=na.fail,xlev=f$xlevels)
  X<-model.matrix(formula,mf,contrasts.arg=f$contrasts);X<-X[,names(b),drop=FALSE]
  add(paste0(label,'_sample_rank_df'),nrow(mf)==f$n&&qr(X)$rank==f$rank&&f$rank==length(b)&&degf(d)==f$design_df&&f$residual_df==degf(d)+1-f$rank)
  if(!is_int&&f$metadata$exposure=='oral_score') {
    ix<-which(names(b)=='oral_score');z<-z[match('oral_score',z$term),];bb<-b[ix];ss<-sqrt(diag(V))[ix]
  } else {z<-z[match(names(b),z$term),];bb<-b;ss<-sqrt(diag(V))}
  add(paste0(label,'_CSV_beta_SE'),near(z$log_odds,as.numeric(bb))&&near(z$se,as.numeric(ss)))
  add(paste0(label,'_t_p_OR_CI'),near(z$odds_ratio,exp(as.numeric(bb)))&&near(z$ci_low,exp(as.numeric(bb)-qt(.975,f$residual_df)*ss))&&near(z$ci_high,exp(as.numeric(bb)+qt(.975,f$residual_df)*ss))&&near(z$p_value,2*pt(abs(bb/ss),f$residual_df,lower.tail=FALSE)))
  if(!is_int)add(paste0(label,'_z_comparator'),near(z$z_ci_low,exp(bb-qnorm(.975)*ss))&&near(z$z_ci_high,exp(bb+qnorm(.975)*ss))&&near(z$z_p_value,2*pnorm(abs(bb/ss),lower.tail=FALSE)))
  if(label%in%selected) {
    D<-d$variables;y<-model.response(mf);w<-weights(d)/mean(weights(d))
    # Independent ordinary GLM score solution, followed by independently
    # assembled stratum/PSU sandwich. No survey model fitting call is used.
    scale<-sqrt(colMeans(X^2));scale[scale==0]<-1;Xs<-sweep(X,2,scale,'/')
    g<-glm.fit(Xs,y,weights=w,family=quasibinomial())
    bet<-g$coefficients/scale
    A<-crossprod(Xs,Xs*as.numeric(g$weights));bread<-solve(A)
    meat<-matrix_cov(Xs*as.numeric(g$residuals*g$weights),D,cand)
    robust<-bread%*%meat%*%bread;robust<-robust/outer(scale,scale)
    diagnostics[[label]]<-list(beta_max_abs_error=max(abs(bet-b)),cov_max_abs_error=max(abs(robust-V)),n=nrow(D))
    add(paste0(label,'_independent_GLM_score'),near(as.numeric(bet),as.numeric(b),1e-6),paste('max error',max(abs(bet-b))))
    add(paste0(label,'_independent_PSU_sandwich'),near(as.numeric(robust),as.numeric(V),1e-6),paste('max error',max(abs(robust-V))))
  }
}
add('sleep_zero_observed_none',sum(master$sleep_hours==0,na.rm=TRUE)==0)
add('oral_score_fixed_definition',near(master$oral_score[master$analysis_domain],as.numeric(master$oral_health[master$analysis_domain])-1))
impute<-read.csv(file.path(run,'tables/continuous_missing_indicators.csv'))
for(i in seq_len(nrow(impute))) {
  v<-impute$variable[i];raw<-master[[v]];missing<-is.na(raw);filled<-master[[paste0(v,'_filled')]]
  med<-median(raw[master$analysis_domain],na.rm=TRUE)
  add(paste0(v,'_fixed_imputation_indicator'),near(impute$median_value[i],med)&&all(filled[missing]==med)&&near(filled[!missing],raw[!missing])&&all(master[[paste0(v,'_missing')]]==as.integer(missing)))
}
for(cand in c('A','B')) {
  d<-designs[[cand]];D<-d$variables;w<-weights(d)
  table<-read.csv(file.path(run,'tables',paste0(cand,'_table1_continuous.csv')))
  table<-table[table$variable%in%c('creatinine','triglycerides_biopro'),]
  for(i in seq_len(nrow(table))) {
    keep<-if(table$hypertension_group[i]=='All')rep(TRUE,nrow(D)) else D$hypertension==table$hypertension_group[i]
    x<-D[[table$variable[i]]];keep<-keep&!is.na(x);wt<-w[keep];x<-x[keep]
    mean<-sum(wt*x)/sum(wt);se<-sqrt(matrix_cov(matrix(wt*(x-mean)/sum(wt),ncol=1),D[keep,],cand)[1,1])
    add(paste0(cand,'_mean_SE_',table$variable[i],'_',table$hypertension_group[i]),near(c(table$weighted_mean[i],table$weighted_mean_se[i]),c(mean,se)))
  }
}
for(name in c('all_model_coefficients.csv','model_sample_counts_formulas.csv','oral_trend_tests.csv')) {
  old<-read.csv(file.path(oldrun,'tables',name));new<-read.csv(file.path(run,'tables',name))
  old<-old[old$model%in%c('Model1','Model2'),];new<-new[new$model%in%c('Model1','Model2'),names(old),drop=FALSE]
  add(paste0(name,'_M1_M2_numeric_reuse'),isTRUE(all.equal(old,new,check.attributes=FALSE,tolerance=1e-14)))
}
provenance<-read.csv(file.path(run,'tables/coefficient_row_provenance.csv'))
add('M3_provenance_current_run',all(provenance$provenance_run[provenance$model=='Model3']=='E2-20261004'))
add('M1_M2_provenance_E1',all(provenance$provenance_run[provenance$model%in%c('Model1','Model2')]=='E1-20261004'))
add('exact_required_new_fit_count',length(files)==36)
results<-do.call(rbind,checks);write.csv(results,file.path(out,'E2_independent_checks.csv'),row.names=FALSE)
write_json(diagnostics,file.path(out,'E2_model_check_details.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
cat('MODELS',length(files),' CHECKS',nrow(results),' PASSED',sum(results$pass),'\n');print(results[!results$pass,])
if(!all(results$pass))quit(status=1)
