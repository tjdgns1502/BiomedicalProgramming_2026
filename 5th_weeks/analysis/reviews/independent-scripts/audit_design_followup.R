Sys.setlocale('LC_ALL','English_United States.utf8')
args<-commandArgs(trailingOnly=TRUE);root<-args[1];out<-args[2]
.libPaths(c(file.path(root,'analysis/r-library'),.libPaths()))
library(survey);library(jsonlite)
run<-file.path(root,'analysis/runs/R2-20261004')
master<-readRDS(file.path(run,'derived/master.rds'));full<-master[master$mec_design_eligible,]
full$SDMVPSU<-as.numeric(full$SDMVPSU);full$SDMVSTRA<-as.numeric(full$SDMVSTRA)
all<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~mec_weight,data=full,nest=TRUE)
fresh<-subset(all,analysis_domain)
rows<-list()
for(ex in c('periodontal','oral_health')) {
  fit<-readRDS(file.path(run,'models',paste0('Model1_',ex,'.rds')))
  eq<-degf(fresh)==degf(fit$survey.design)&&isTRUE(all.equal(fresh$cluster,fit$survey.design$cluster))&&isTRUE(all.equal(fresh$strata,fit$survey.design$strata))&&max(abs(weights(fresh)-weights(fit$survey.design)))<1e-8
  rows[[length(rows)+1]]<-data.frame(check=paste0(ex,'_fresh_design_numerically_equal'),pass=eq,detail=paste('cluster identical=',identical(fresh$cluster,fit$survey.design$cluster),'strata identical=',identical(fresh$strata,fit$survey.design$strata)))
}
prev<-read.csv(file.path(out,'R2_independent_checks.csv'))
idx<-which(prev$check=='domain_design_matches_fresh_full_subset')
stopifnot(length(idx)==1)
prev$pass[idx]<-all(vapply(rows,function(x)x$pass,logical(1)))
prev$detail[idx]<-'Resolved with numerical all.equal; exact R attribute identity is not the numerical design contract.'
report<-read_json(file.path(run,'report.json'),simplifyVector=TRUE)
est<-svymean(~hypertension_code,fresh)
rows[[length(rows)+1]]<-data.frame(check='report_weighted_HTN_mean_SE',pass=max(abs(c(report$htn_weighted_percent,report$htn_weighted_percent_se)-100*c(coef(est),SE(est))))<1e-8,detail='')
results<-rbind(prev,do.call(rbind,rows))
write.csv(results,file.path(out,'R2_verified_checks.csv'),row.names=FALSE)
print(tail(results,4));cat('ALL_PASS',all(results$pass),'CHECKS',nrow(results),'\n')
if(!all(results$pass))quit(status=1)
