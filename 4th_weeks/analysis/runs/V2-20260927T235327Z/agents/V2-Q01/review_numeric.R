library(jsonlite)
d <- 'analysis/tasks/V2-I01/rev-1/work'
rd <- function(f) read.csv(file.path(d,f))
lg<-rd('log_base_checks.csv');q<-rd('quartile_model1.csv');cut<-rd('quartile_cutpoints_counts.csv');nl<-rd('nonlinearity_tests.csv');a<-rd('age_boundary_counts.csv');cc<-rd('diagnostic_curve_data.csv');rows<-rd('analysis_rows.csv')
tc<-qt(.975,138)
err<-c(logbeta=max(abs(lg$beta_log10-log(10)*lg$beta_ln)),logse=max(abs(lg$se_log10-log(10)*lg$se_ln)),quartile_OR=max(abs(q$OR-exp(q$beta))),quartile_CI=max(abs(c(q$ci_low-exp(q$beta-tc*q$se),q$ci_high-exp(q$beta+tc*q$se)))),quartile_p=max(abs(q$p-2*pt(-abs(q$beta/q$se),q$df))),nonlinear_p=max(abs(nl$p-pf(nl$F,nl$df_num,nl$df_den,lower.tail=FALSE))),bonferroni=max(abs(nl$p_bonferroni-pmin(1,4*nl$p))),BH=max(abs(nl$p_BH-p.adjust(nl$p,'BH',n=4))),curve_OR=max(abs(cc$OR-exp(cc$logOR))),curve_CI=max(abs(c(cc$ci_low-exp(cc$logOR-tc*cc$se),cc$ci_high-exp(cc$logOR+tc*cc$se)))))
stopifnot(all(err<1e-10),nrow(rows)==9786,!anyDuplicated(rows$SEQN),all(a$n_ge50-a$n_gt50==a$n_eq50),all(tapply(cut$n,cut$marker,sum)==9786))
ref<-cc[cc$value==cc$reference,];stopifnot(nrow(ref)==4,all(ref$OR==1),all(ref$se==0),all(ref$ci_low==1),all(ref$ci_high==1))
for(s in unique(a$scope)){aa<-a[a$scope==s,];stopifnot(all(as.numeric(aa[aa$cycle=='ALL',3:6])==colSums(aa[aa$cycle!='ALL',3:6])))}
b<-readRDS(file.path(d,'basis_transformations.rds'));j<-fromJSON(file.path(d,'basis_transformations.json'))
stopifnot(identical(names(b),names(j)))
for(m in names(b)){stopifnot(isTRUE(all.equal(b[[m]],j[[m]],check.attributes=FALSE,tolerance=1e-12)))}
write_json(list(status='pass',scope='Independent arithmetic checks of submitted CSV and stored basis files; no model refit or raw marker provenance validation',maximum_absolute_errors=as.list(err),unique_rows=nrow(rows),quartile_sums=as.list(tapply(cut$n,cut$marker,sum)),reference_rows=nrow(ref),cycle_sum_identity=TRUE,basis_RDS_JSON_agree=TRUE), 'analysis/tasks/V2-Q01/rev-1/work/result_numeric_checks.json',pretty=TRUE,auto_unbox=TRUE,digits=17)
