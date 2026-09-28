library(jsonlite)
d<-read.csv('analysis/data/derived/candidate_complete36.csv');ids<-read.csv('analysis/tasks/V2-I01/rev-1/work/analysis_rows.csv')$SEQN
calc<-list(NLR=d$LBDNENO/d$LBDLYMNO,MLR=d$LBDMONO/d$LBDLYMNO,SIRI=d$LBDNENO*d$LBDMONO/d$LBDLYMNO,SII=d$LBXPLTSI*d$LBDNENO/d$LBDLYMNO)
near<-function(a,b) all(abs(a-b)<=1e-8+1e-7*abs(b))
out<-list()
for(m in names(calc)) {
 a<-d[[m]];b<-calc[[m]]; ok<-is.finite(a)&is.finite(b);common<-d$SEQN%in%ids;diff<-abs(a-b);threshold<-1e-8+1e-7*abs(b)
 out[[m]]<-list(full_n=nrow(d),na_unsafe_near=as.character(near(a,b)),joint_nonfinite=sum(!ok),finite_pair_n=sum(ok),finite_mismatch=sum(diff[ok]>threshold[ok]),max_finite_difference=max(diff[ok]),common_n=sum(common),common_nonfinite=sum(!ok[common]),common_mismatch=sum(diff[ok&common]>threshold[ok&common]),common_max_difference=max(diff[ok&common]))
}
stopifnot(all(vapply(out,function(z) z$finite_mismatch==0&&z$common_nonfinite==0&&z$common_mismatch==0,logical(1))))
write_json(list(scope='Limited NA-aware arithmetic reconciliation of supplied derived columns against direct absolute CBC formulas; no raw XPT/unit/merge provenance certification',results=out),'analysis/tasks/V2-Q01/rev-1/work/marker_assertion_reconciliation.json',pretty=TRUE,auto_unbox=TRUE,digits=17)
