library(survey)
library(splines)
library(jsonlite)
out <- 'analysis/tasks/V2-I01/rev-1/work'
options(survey.lonely.psu='fail', contrasts=c('contr.treatment','contr.poly'))
tol <- 1e-10
write_json(list(rank_tolerance=tol, CI='pointwise 95% t, df=degf(domain)', age='>=50 operational; parent-reported conflicting source wording', spline='ln; type7 1/3,2/3; observed boundaries; median reference; display raw-marker type7 5%-95%', interpretation='analyst candidate FI; conditional diagnostic only'),file.path(out,'frozen_spec.json'),pretty=TRUE,auto_unbox=TRUE)
near <- function(a,b) all(abs(a-b)<=1e-8+1e-7*abs(b))
basis <- function(x) {
  k<-unname(quantile(x,c(1/3,2/3),type=7));bd<-range(x)
  stopifnot(length(unique(c(bd,k)))==4)
  B<-ns(x,knots=k,Boundary.knots=bd,intercept=FALSE); L<-cbind(1,x)
  A<-qr.coef(qr(L,tol=tol),B); R<-B-L%*%A; q<-qr(R,tol=tol)
  stopifnot(q$rank==2);sel<-q$pivot[1:2]; scale<-sqrt(colSums(R[,sel,drop=FALSE]^2))
  Z<-sweep(R[,sel,drop=FALSE],2,scale,'/')
  N<-cbind(L,Z);O<-cbind(1,B)
  e1<-norm(qr.resid(qr(N,tol=tol),O),'F')/norm(O,'F')
  e2<-norm(qr.resid(qr(O,tol=tol),N),'F')/norm(N,'F')
  stopifnot(max(e1,e2)<=1e-10)
  list(Z=Z,knots=k,boundary=bd,A=A,selected=sel,scale=scale,span_error=max(e1,e2))
}
evalbasis<-function(x,b) sweep((ns(x,knots=b$knots,Boundary.knots=b$boundary,intercept=FALSE)-cbind(1,x)%*%b$A)[,b$selected,drop=FALSE],2,b$scale,'/')
# Independent synthetic checks before reading outcomes.
set.seed(905);x<-seq(-2,3,length.out=301);bb<-basis(x)
stopifnot(max(abs(bb$Z-evalbasis(x,bb)))<1e-12)
y<-rbinom(length(x),1,plogis(-.2+.5*x));z<-rnorm(length(x))
g1<-glm(y~x+z,family=binomial());x10<-x/log(10);g2<-glm(y~x10+z,family=binomial())
T<-diag(c(1,log(10),1));stopifnot(near(coef(g2),T%*%coef(g1)),near(vcov(g2),T%*%vcov(g1)%*%T),max(abs(fitted(g1)-fitted(g2)))<1e-8)
a<-c(49,50,50,51,NA);stopifnot(sum(a>=50,na.rm=TRUE)-sum(a>50,na.rm=TRUE)==sum(a==50,na.rm=TRUE))
write_json(list(status='pass',basis_span_error=bb$span_error,toy_logbase=TRUE,count_identity=TRUE),file.path(out,'synthetic_tests.json'),pretty=TRUE,auto_unbox=TRUE)
dat<-read.csv('analysis/data/derived/candidate_complete36.csv');all<-read.csv('analysis/data/derived/nhanes_design_all.csv')
markers<-c('NLR','MLR','SIRI','SII');stopifnot(!anyDuplicated(dat$SEQN),!anyDuplicated(all$SEQN))
# Marker values are frozen from the approved derived input. No source formula
# reconstruction is made here: absolute CBC fields can be missing in some cycles.
ix<-match(dat$SEQN,all$SEQN);stopifnot(!anyNA(ix))
for(v in intersect(names(dat),names(all))) stopifnot(isTRUE(all.equal(dat[[v]],all[[v]][ix],check.attributes=FALSE)))
stopifnot(all(dat$candidate36_observed_items==36),all(dat$FI==dat$FI_candidate36),all(dat$frail_candidate36==as.integer(dat$FI>.3)))
valid<-complete.cases(dat[,c(markers,'RIDAGEYR','RIAGENDR','RIDRETH1','cycle','SDMVPSU','SDMVSTRA','weight_mec_18yr','FI')]) & is.finite(dat$FI) & dat$FI>=0 & dat$FI<=1 & dat$weight_mec_18yr>0 & is.finite(dat$weight_mec_18yr)
for(m in markers) valid<-valid & is.finite(dat[[m]]) & dat[[m]]>0
dat<-dat[valid & dat$RIDAGEYR>=50,]; stopifnot(nrow(dat)>0)
countage<-function(d,scope) do.call(rbind,lapply(c('ALL',sort(unique(d$cycle))),function(cy) {a<-if(cy=='ALL') d$RIDAGEYR else d$RIDAGEYR[d$cycle==cy];data.frame(scope=scope,cycle=cy,n_ge50=sum(a>=50,na.rm=TRUE),n_gt50=sum(a>50,na.rm=TRUE),n_eq50=sum(a==50,na.rm=TRUE),n_age_missing=sum(is.na(a)))}))
ac<-rbind(countage(all,'original_DEMO_full'),countage(dat,'common_candidate_other_criteria'));stopifnot(all(ac$n_ge50-ac$n_gt50==ac$n_eq50));write.csv(ac,file.path(out,'age_boundary_counts.csv'),row.names=FALSE)
base<-all[is.finite(all$weight_mec_18yr)&all$weight_mec_18yr>0,];stopifnot(all(complete.cases(base[,c('SDMVPSU','SDMVSTRA')])) )
for(v in c(markers,'FI')) base[[v]]<-dat[[v]][match(base$SEQN,dat$SEQN)]
base$eligible<-base$SEQN%in%dat$SEQN;base$age<-base$RIDAGEYR;base$sex<-factor(base$RIAGENDR);base$race<-factor(base$RIDRETH1);base$cycle_adjust<-factor(base$cycle);base$frail<-as.integer(base$FI>.3)
full<-svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~weight_mec_18yr,nest=TRUE,data=base);des<-subset(full,eligible);df<-degf(des);stopifnot(df>0);crit<-qt(.975,df)
write.csv(data.frame(SEQN=des$variables$SEQN),file.path(out,'analysis_rows.csv'),row.names=FALSE)
write_json(list(n=nrow(des$variables),outcomes=sum(des$variables$frail),parent_n=nrow(base),design_df=df,parent_design_df=degf(full),strata=length(unique(des$strata[,1])),PSU=length(unique(des$cluster[,1])),cycles=as.list(table(des$variables$cycle)),references=list(sex=levels(base$sex)[1],race=levels(base$race)[1],cycle=levels(base$cycle_adjust)[1]),limitation='Existing operational FI and frozen pooled weights reused; not independent source rederivation. Candidate input already age>=50; adequate for boundary comparison, not younger-age eligibility.'),file.path(out,'sample_audit.json'),pretty=TRUE,auto_unbox=TRUE)
checkfit<-function(f) {M<-model.matrix(f);stopifnot(f$converged,all(is.finite(coef(f))),all(is.finite(vcov(f))),qr(M,tol=tol)$rank==ncol(M));invisible(TRUE)}
fit<-function(form,d) {f<-svyglm(form,d,family=quasibinomial());checkfit(f);f}
logs<-quarts<-nls<-cuts<-curves<-list();bs<-list()
for(m in markers) {
  d<-des;raw<-d$variables[[m]];d$variables$x<-log(raw);d$variables$x10<-log10(raw)
  f<-fit(frail~x+age+sex+race+cycle_adjust,d);g<-fit(frail~x10+age+sex+race+cycle_adjust,d)
  b<-coef(f);v<-vcov(f);b10<-coef(g);v10<-vcov(g);j<-which(names(b)=='x');T<-diag(length(b));T[j,j]<-log(10)
  expb<-drop(T%*%b);expv<-T%*%v%*%T;s<-sqrt(diag(v));s10<-sqrt(diag(v10));p<-2*pt(-abs(b[j]/s[j]),df);p10<-2*pt(-abs(b10[j]/s10[j]),df)
  le<-max(abs(f$linear.predictors-g$linear.predictors));pe<-max(abs(fitted(f)-fitted(g)))
  stopifnot(near(b10,expb),near(v10,expv),near(s10,diag(T)*s),near(b10[j]+c(-1,1)*crit*s10[j],log(10)*(b[j]+c(-1,1)*crit*s[j])),near(p,p10),near(b[j]/s[j],b10[j]/s10[j]),le<=1e-7,pe<=1e-8)
  logs[[m]]<-data.frame(marker=m,OR_ln=exp(b[j]),OR_log10=exp(b10[j]),beta_ln=b[j],se_ln=s[j],beta_log10=b10[j],se_log10=s10[j],ci_low_ln=exp(b[j]-crit*s[j]),ci_high_ln=exp(b[j]+crit*s[j]),ci_low_log10=exp(b10[j]-crit*s10[j]),ci_high_log10=exp(b10[j]+crit*s10[j]),p=p,df=df,coef_error=max(abs(b10-expb)),cov_error=max(abs(v10-expv)),se_error=max(abs(s10-diag(T)*s)),linear_predictor_error=le,probability_error=pe,p_error=abs(p-p10),wald_error=abs(b[j]/s[j]-b10[j]/s10[j]),identity_pass=TRUE)
  cq<-unname(quantile(raw,c(.25,.5,.75),type=7));stopifnot(length(unique(cq))==3);d$variables$q<-cut(raw,c(-Inf,cq,Inf),labels=paste0('Q',1:4),right=TRUE);nt<-table(d$variables$q);stopifnot(all(nt>0),sum(nt)==nrow(d$variables))
  fq<-fit(frail~q+age+sex+race+cycle_adjust,d);jj<-match(paste0('qQ',2:4),names(coef(fq)));qb<-coef(fq)[jj];qs<-sqrt(diag(vcov(fq)))[jj]
  quarts[[m]]<-data.frame(marker=m,contrast=paste0('Q',2:4,'/Q1'),OR=exp(qb),ci_low=exp(qb-crit*qs),ci_high=exp(qb+crit*qs),p=2*pt(-abs(qb/qs),df),n=nrow(d$variables),beta=qb,se=qs,df=df)
  cuts[[m]]<-data.frame(marker=m,category=names(nt),n=as.integer(nt),lower=c(-Inf,cq),upper=c(cq,Inf))
  result<-tryCatch({
    bas<-basis(log(raw));d$variables$nl1<-bas$Z[,1];d$variables$nl2<-bas$Z[,2];fs<-fit(frail~x+nl1+nl2+age+sex+race+cycle_adjust,d)
    ids<-match(c('nl1','nl2'),names(coef(fs)));vv<-vcov(fs)[ids,ids];chol(vv);W<-drop(t(coef(fs)[ids])%*%solve(vv,coef(fs)[ids]));Fv<-W/2
    ref<-unname(median(raw));xr<-log(ref);rangeplot<-unname(quantile(raw,c(.05,.95),type=7));grid<-sort(unique(c(exp(seq(log(rangeplot[1]),log(rangeplot[2]),length.out=201)),ref)));gx<-log(grid);gz<-evalbasis(gx,bas);rz<-evalbasis(xr,bas)
    new<-d$variables[rep(1,length(grid)),];new$x<-gx;new$nl1<-gz[,1];new$nl2<-gz[,2];rnew<-new;rnew$x<-xr;rnew$nl1<-rz[1,1];rnew$nl2<-rz[1,2]
    tt<-delete.response(terms(fs));D<-model.matrix(tt,new,contrasts.arg=fs$contrasts)-model.matrix(tt,rnew,contrasts.arg=fs$contrasts);D<-D[,names(coef(fs)),drop=FALSE]
    eta<-drop(D%*%coef(fs));se<-sqrt(pmax(0,rowSums((D%*%vcov(fs))*D)));stopifnot(all(D[grid==ref,]==0),eta[grid==ref]==0,se[grid==ref]==0)
    curves[[m]]<-data.frame(marker=m,value=grid,reference=ref,OR=exp(eta),ci_low=exp(eta-crit*se),ci_high=exp(eta+crit*se),logOR=eta,se=se)
    bas$Z<-NULL;bs[[m]]<-bas
    data.frame(marker=m,p=pf(Fv,2,df,lower.tail=FALSE),F=Fv,df_num=2,df_den=df,status='estimable',reason='',span_error=bas$span_error)
  },error=function(e) data.frame(marker=m,p=NA_real_,F=NA_real_,df_num=2,df_den=df,status='non-estimable',reason=conditionMessage(e),span_error=NA_real_))
  nls[[m]]<-result
}
write.csv(do.call(rbind,logs),file.path(out,'log_base_checks.csv'),row.names=FALSE);write.csv(do.call(rbind,quarts),file.path(out,'quartile_model1.csv'),row.names=FALSE);write.csv(do.call(rbind,cuts),file.path(out,'quartile_cutpoints_counts.csv'),row.names=FALSE)
nl<-do.call(rbind,nls);nl$p_bonferroni<-p.adjust(nl$p,'bonferroni',n=4);nl$p_BH<-p.adjust(nl$p,'BH',n=4);write.csv(nl,file.path(out,'nonlinearity_tests.csv'),row.names=FALSE)
write_json(bs,file.path(out,'basis_transformations.json'),pretty=TRUE,auto_unbox=TRUE,digits=17);saveRDS(bs,file.path(out,'basis_transformations.rds'));write.csv(do.call(rbind,curves),file.path(out,'diagnostic_curve_data.csv'),row.names=FALSE)
png(file.path(out,'diagnostic_curves.png'),width=1600,height=1200,res=160);par(mfrow=c(2,2),mar=c(5,4,3,1),oma=c(0,0,3,0))
for(m in markers) {cc<-curves[[m]];if(is.null(cc)){plot.new();title(m);text(.5,.5,'Non-estimable')}else{plot(cc$value,cc$OR,type='n',log='x',ylim=range(cc$ci_low,cc$ci_high,1),xlab=paste(m,'(log axis; 5th-95th percentile)'),ylab='OR vs marker median',main=m);polygon(c(cc$value,rev(cc$value)),c(cc$ci_low,rev(cc$ci_high)),border=NA,col='#B7D8EB');lines(cc$value,cc$OR,lwd=2,col='#184C70');abline(h=1,lty=2);abline(v=cc$reference[1],lty=3)}}
mtext('Analyst diagnostic: candidate FI; pointwise 95% t CIs',outer=TRUE,cex=1);dev.off()
writeLines(capture.output(sessionInfo()),file.path(out,'sessionInfo.txt'))
cat('Bounded checks completed; n=',nrow(des$variables),' design df=',df,'\n')
