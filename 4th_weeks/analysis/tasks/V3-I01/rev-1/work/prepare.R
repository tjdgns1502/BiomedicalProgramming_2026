suppressPackageStartupMessages({library(survey);library(splines);library(jsonlite);library(foreign)})
out <- 'analysis/tasks/V3-I01/rev-1/work'
options(survey.lonely.psu='fail',contrasts=c('contr.treatment','contr.poly'))
writeout<-function(x,n) write.csv(x,file.path(out,paste0(n,'.csv')),row.names=FALSE)
dat<-read.csv('analysis/data/derived/candidate_all_age50.csv'); parent<-read.csv('analysis/data/derived/nhanes_design_all.csv')
stopifnot(!anyDuplicated(dat$SEQN),!anyDuplicated(parent$SEQN))
markers<-c('NLR','MLR','SIRI','SII'); cycles<-sort(unique(dat$cycle)); rawdir<-'analysis/data/raw'
rawread<-function(cy,prefix) {f<-list.files(file.path(rawdir,cy),pattern=paste0('^',prefix,'(_[B-I])?\\.xpt$'),full.names=TRUE,ignore.case=TRUE);stopifnot(length(f)==1);z<-read.xport(f);stopifnot(!anyDuplicated(z$SEQN));z}
b<-rawread('2001-2002','ALQ');dat$ALD100<-b$ALD100[match(dat$SEQN,b$SEQN)]
yn<-function(x) factor(ifelse(x==1,'Yes',ifelse(x==2,'No',NA)),levels=c('No','Yes'))
dat$age<-dat$RIDAGEYR;dat$sex<-factor(dat$RIAGENDR);dat$race<-factor(dat$RIDRETH1);dat$cycle_adjust<-factor(dat$cycle)
dat$education<-factor(ifelse(dat$DMDEDUC2%in%1:2,'belowHS',ifelse(dat$DMDEDUC2==3,'HS',ifelse(dat$DMDEDUC2%in%4:5,'aboveHS',NA))),levels=c('belowHS','HS','aboveHS'))
dat$pir<-cut(ifelse(is.finite(dat$INDFMPIR)&dat$INDFMPIR>=0,dat$INDFMPIR,NA),c(-Inf,1,3,Inf),labels=c('LE1','GT1_LE3','GT3'))
dat$bmi<-cut(ifelse(is.finite(dat$BMXBMI)&dat$BMXBMI>0,dat$BMXBMI,NA),c(-Inf,25,30,Inf),right=FALSE,labels=c('LT25','25_LT30','GE30'))
dat$smoking<-yn(dat$SMQ020);dat$diabetes<-yn(dat$DIQ010);dat$hypertension<-yn(dat$BPQ020)
dat$alcohol<-yn(ifelse(dat$cycle_start==1999,dat$ALQ100,ifelse(dat$cycle_start==2001,dat$ALD100,dat$ALQ101)))
vig<-ifelse(dat$cycle_start<=2005,dat$PAD200,dat$PAQ650);mod<-ifelse(dat$cycle_start<=2005,dat$PAD320,dat$PAQ665)
dat$activity<-factor(ifelse(vig==1,'Vigorous',ifelse(vig==2&mod==1,'Moderate',ifelse(vig==2&mod==2,'Low',NA))),levels=c('Low','Moderate','Vigorous'))
dr99<-rawread('1999-2000','DRXTOT');dat$DRDDRSTS<-dr99$DRDDRSTS[match(dat$SEQN,dr99$SEQN)]
kcal<-ifelse(dat$cycle_start<2003,dat$DRXTKCAL,dat$DR1TKCAL);status<-ifelse(dat$cycle_start==1999,dat$DRDDRSTS,ifelse(dat$cycle_start==2001,dat$DRDDRSTZ,dat$DR1DRSTZ))
dat$energy<-ifelse(status==1&is.finite(kcal)&kcal>=0,kcal,NA)
dat$energy2<-ifelse(dat$DR1DRSTZ==1&dat$DR2DRSTZ==1&is.finite(dat$DR1TKCAL)&dat$DR1TKCAL>=0&is.finite(dat$DR2TKCAL)&dat$DR2TKCAL>=0,(dat$DR1TKCAL+dat$DR2TKCAL)/2,NA)
items<-c('angina','heart_attack','coronary_heart_disease','stroke','thyroid','cancer','arthritis','hypertension','diabetes','kidney','confusion','managing_money','stooping','lifting','walking_rooms','chair_rise','bed','dressing','grasping','social_event','self_rated_health','healthcare_use','health_last_year','hospital_stay','medications','pulse','sbp','pulse_pressure','platelets','bun','bicarbonate','rdw','ldh','alp','uric_acid','calcium')
orig<-as.matrix(dat[paste0('def_',items)]);stopifnot(all(orig%in%c(0,1,NA)),all(rowSums(!is.na(orig))==dat$candidate36_observed_items))
route<-ifelse(dat$cycle_start<2003,dat$PFQ048==2&dat$PFQ056==2&dat$PFQ059==2&!(dat$PFQ050%in%1)&!(dat$PFQ055%in%1),dat$PFQ049==2&dat$PFQ057==2&dat$PFQ059==2&dat$PFQ051==2&dat$PFQ054==2)
route<-!is.na(route)&route&dat$age>=50&dat$age<60; revised<-orig;flags<-list()
for(j in seq_along(c('A','D','E','H','I','J','L','P','R'))) {s<-c('A','D','E','H','I','J','L','P','R')[j];raw<-ifelse(dat$cycle_start<2003,dat[[paste0('PFQ060',s)]],dat[[paste0('PFQ061',s)]]);col<-match(c('managing_money','stooping','lifting','walking_rooms','chair_rise','bed','dressing','grasping','social_event')[j],items);take<-route&is.na(raw)&is.na(orig[,col]);revised[take,col]<-0;dat[[paste0('route_zero_',s)]]<-take;flags[[s]]<-data.frame(item=s,cycle=cycles,n=vapply(cycles,function(cy)sum(take&dat$cycle==cy),integer(1)))}
dat$route_confirmed<-route;dat$route_observed<-rowSums(!is.na(revised));dat$FI_route<-ifelse(dat$route_observed==36,rowSums(revised),NA)/36;dat$FI30<-ifelse(rowSums(!is.na(orig))>=30,rowSums(orig,na.rm=TRUE)/rowSums(!is.na(orig)),NA);dat$frail<-as.integer(dat$FI_route>.3)
stopifnot(all(abs(dat$FI_route[!is.na(dat$FI_candidate36)]-dat$FI_candidate36[!is.na(dat$FI_candidate36)])<1e-12),all(abs(dat$FI30[!is.na(dat$FI_candidate36)]-dat$FI_candidate36[!is.na(dat$FI_candidate36)])<1e-12))
alias<-function(cols) {z<-rep(NA_real_,nrow(dat));for(v in cols) {k<-is.na(z);z[k]<-dat[[v]][k]};z}
for(n in c('angina','MI','CHD','stroke','cancer','arthritis','kidney','thyroid')) {cols<-switch(n,angina='MCQ160D',MI='MCQ160E',CHD='MCQ160C',stroke='MCQ160F',cancer='MCQ220',arthritis='MCQ160A',kidney=c('KIQ022','KIQ020'),thyroid=c('MCQ160M','MCD160M','MCQ160I'));dat[[paste0('extra_',n)]]<-yn(alias(cols))}
for(n in c('BPXPLS','candidate_pulse_pressure_mean','LBXPLTSI','LBXSBU','LBXSC3SI','LBXRDW','LBDSUASI')) dat[[paste0('extra_',n)]]<-dat[[n]]
dat$extra_LDH<-ifelse(dat$cycle_start==2001,dat$LBDSLDSI,dat$LBXSLDSI)
m1<-c('age','sex','race','cycle_adjust');added<-c('education','pir','bmi','smoking','alcohol','activity','energy','diabetes','hypertension');m2<-c(m1,added);extra<-grep('^extra_',names(dat),value=TRUE);stopifnot(length(extra)==16)
ix<-match(dat$SEQN,parent$SEQN);stopifnot(!anyNA(ix));for(v in intersect(names(parent),names(dat)))stopifnot(isTRUE(all.equal(dat[[v]],parent[[v]][ix],check.attributes=FALSE)))
base<-parent;for(v in setdiff(names(dat),names(base)))base[[v]]<-dat[[v]][match(base$SEQN,dat$SEQN)]
base$reference<-complete.cases(base[,c('FI_route',markers,m1)])&is.finite(base$weight_mec_18yr)&base$weight_mec_18yr>0
for(m in markers)base$reference<-base$reference&is.finite(base[[m]])&base[[m]]>0
base$model2_domain<-base$reference&complete.cases(base[,m2]);base$supp_domain<-base$model2_domain&complete.cases(base[,extra]);base$age_group<-factor(ifelse(base$RIDAGEYR<65,'LT65','GE65'),levels=c('LT65','GE65'))
cuts<-list();for(m in markers) {r<-base[[m]][base$reference];q<-quantile(r,c(.25,.5,.75),type=7);stopifnot(length(unique(q))==3);g<-cut(base[[m]],c(-Inf,q,Inf),labels=paste0('Q',1:4));med<-tapply(r,g[base$reference],median);base[[paste0('quart_',m)]]<-g;base[[paste0('trend_',m)]]<-unname(med[as.character(g)]);cuts[[m]]<-data.frame(marker=m,group=names(med),median=med,lower=c(-Inf,q),upper=c(q,Inf))}
wt<-list();for(cy in cycles[3:9]) {z<-rawread(cy,'DR2TOT');stopifnot('WTDR2D'%in%names(z));wt[[cy]]<-data.frame(SEQN=z$SEQN,cycle=cy,WTDR2D=z$WTDR2D)};wt<-do.call(rbind,wt);stopifnot(!anyDuplicated(wt$SEQN));base$weight_diet14<-wt$WTDR2D[match(base$SEQN,wt$SEQN)]/7;base$diet_domain<-base$model2_domain&is.finite(base$energy2)&base$cycle%in%cycles[3:9]&is.finite(base$weight_diet14)&base$weight_diet14>0
writeout(do.call(rbind,flags),'route_flags_counts');writeout(do.call(rbind,cuts),'frozen_quartiles');writeout(base[base$SEQN%in%dat$SEQN,c('SEQN','cycle','FI_candidate36','FI_candidate36_alt','FI_route','FI30','route_observed','route_confirmed',grep('route_zero_',names(base),value=TRUE),m2,extra,'energy2','weight_diet14','reference','model2_domain','supp_domain','diet_domain')],'derived_analysis_inputs')
dictionary<-do.call(rbind,lapply(cycles,function(cy)do.call(rbind,lapply(c(m2,extra,'energy2'),function(v)data.frame(cycle=cy,variable=v,usable=sum(!is.na(dat[[v]][dat$cycle==cy])),missing=sum(is.na(dat[[v]][dat$cycle==cy])),levels=if(is.factor(dat[[v]]))paste(levels(dat[[v]]),collapse='|')else'continuous')))));writeout(dictionary,'covariate_availability_dictionary')
writeout(do.call(rbind,lapply(cycles,function(cy)data.frame(cycle=cy,item=items,missing=colSums(is.na(orig[dat$cycle==cy,,drop=FALSE])),route_missing=colSums(is.na(revised[dat$cycle==cy,,drop=FALSE]))))),'item_missingness')
writeout(do.call(rbind,lapply(c('FI_candidate36','FI_candidate36_alt','FI_route','FI30'),function(v){x<-dat[[v]];data.frame(candidate=v,n=sum(!is.na(x)),min=min(x,na.rm=TRUE),max=max(x,na.rm=TRUE),zeros=sum(x==0,na.rm=TRUE),ones=sum(x==1,na.rm=TRUE),distinct=length(unique(na.omit(x))))})),'endpoint_audit')
writeout(data.frame(stage=c('all_age_parent','age50_input','strict36','route36','reference','model2','supplement','diet'),n=c(nrow(parent),nrow(dat),sum(!is.na(dat$FI_candidate36)),sum(!is.na(dat$FI_route)),sum(base$reference),sum(base$model2_domain),sum(base$supp_domain),sum(base$diet_domain))),'flow_counts')
saveRDS(list(base=base,m1=m1,m2=m2,extra=extra,markers=markers),file.path(out,'prepared.rds'))
write_json(list(status='PASS',duplicate_ids=FALSE,strict_route_shared_identical=TRUE,strict_FI30_shared_identical=TRUE,all_design_columns_match=TRUE,fitting_run=FALSE),file.path(out,'prefit_qa.json'),pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'));cat('PREPARED ONLY; no fitting\n')
