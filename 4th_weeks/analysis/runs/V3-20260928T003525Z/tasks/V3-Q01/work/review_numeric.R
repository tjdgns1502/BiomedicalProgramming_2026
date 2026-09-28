suppressPackageStartupMessages(library(jsonlite))
iout<-'analysis/tasks/V3-I01/rev-1/work';qout<-'analysis/tasks/V3-Q01/rev-1/work'
d<-read.csv(file.path(iout,'derived_analysis_inputs.csv'));e<-read.csv(file.path(qout,'expected_pfqqa_rows.csv'));j<-match(e$SEQN,d$SEQN);stopifnot(!anyNA(j),!anyDuplicated(d$SEQN));d<-d[j,]
eq<-function(x,y) isTRUE(all.equal(as.numeric(x),as.numeric(y),tolerance=1e-11,check.attributes=FALSE))
stopifnot(eq(d$FI_route,e$route_FI),eq(d$FI_candidate36,e$strict_FI),all(d$route_confirmed==(e$route_eligible=='True')),all(rowSums(d[grep('route_zero_',names(d))])==e$modified_cells))
a<-readRDS(file.path(iout,'prepared.rds'));b<-a$base;orig<-read.csv('analysis/data/derived/candidate_all_age50.csv');cols<-grep('^def_',names(orig),value=TRUE);cols<-cols[!grepl('_alt$',cols)];stopifnot(length(cols)==36);nobs<-rowSums(!is.na(orig[cols]));FI30<-ifelse(nobs>=30,rowSums(orig[cols],na.rm=TRUE)/nobs,NA);stopifnot(eq(d$FI30,FI30[match(d$SEQN,orig$SEQN)]))
rows<-readRDS(file.path(iout,'model_row_ids.rds'));matches<-list();for(m in a$markers){for(prefix in c('', '_quartile','_trend')){x<-rows[[paste0('M1_matched',prefix,'_',m)]];y<-rows[[paste0('M2',prefix,'_',m)]];stopifnot(identical(x,y));matches[[paste(m,prefix)]]<-length(x)};stopifnot(identical(rows[[paste0('Diet_day1_matched_',m)]],rows[[paste0('Diet_mean2_matched_',m)]]),identical(rows[[paste0('M2_supp_matched_',m)]],rows[[paste0('M2_plus16_',m)]]))}
checks<-list();for(nm in c('continuous_models','quartile_models','trend_models','omnibus_tests','spline_tests','interactions')){z<-read.csv(file.path(iout,paste0(nm,'.csv')));valid<-is.finite(z$p);if('beta'%in%names(z)){v<-z$status=='estimable';stopifnot(eq(z$OR[v],exp(z$beta[v])),eq(z$low[v],exp(z$beta[v]-qt(.975,z$df[v])*z$se[v])),eq(z$high[v],exp(z$beta[v]+qt(.975,z$df[v])*z$se[v])),eq(z$p[v],2*pt(-abs(z$beta[v]/z$se[v]),z$df[v])))};fam<-if(nm=='interactions')rep('all',nrow(z))else z$model;N<-switch(nm,quartile_models=12,interactions=24,4);for(f in unique(fam)){ix<-which(fam==f);stopifnot(eq(z$p_holm[ix],p.adjust(z$p[ix],'holm',n=N)),eq(z$p_BH[ix],p.adjust(z$p[ix],'BH',n=N)))};checks[[nm]]<-list(rows=nrow(z),finite_p=sum(valid),planned_family_N=N)}
stopifnot(nrow(read.csv(file.path(iout,'interactions.csv')))==24)
energycounts<-aggregate(!is.na(d$energy),list(cycle=d$cycle),sum)
summary<-list(status='corrected_numeric_checks_pass',pfq_rows_compared=nrow(d),PFQ_exact_match=TRUE,FI30_exact_match=TRUE,matched_model_IDs=matches,numeric=checks,energy_by_cycle=energycounts,resolved_implementation_findings=c('1999 reliable dietary status must be DRDDRSTS; DRDDRSTZ is2001 field. Corrected raw1999 extraction now verified.','Drop unused factor levels within domains before design-matrix rank check; zero dummy columns from absent cycles are not genuine nonestimable targets.'),table_plot_review='separate_review')
write_json(summary,file.path(qout,'corrected_numeric_review.json'),pretty=TRUE,auto_unbox=TRUE,na='null');cat('CORRECTED QA PASS\n')




