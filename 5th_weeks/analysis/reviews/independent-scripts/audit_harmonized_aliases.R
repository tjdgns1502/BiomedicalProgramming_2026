Sys.setlocale('LC_ALL','English_United States.utf8')
args<-commandArgs(trailingOnly=TRUE);root<-args[1];out<-args[2]
run<-file.path(root,'analysis/runs/E2-20261004')
master<-readRDS(file.path(run,'derived/master.rds'))
rows<-list();allok<-TRUE
for(path in list.files(file.path(run,'models'),pattern='_lean.rds$',full.names=TRUE)) {
  label<-sub('_lean.rds$','',basename(path));f<-readRDS(path)
  cand<-substr(label,1,1);D<-master[if(cand=='A')master$analysis_domain else master$dietary_sensitivity_domain,]
  if(!is.null(f$metadata)) {
    m<-f$metadata
    if(m$family=='supplement_measured')D<-D[!is.na(D$diagnosed_or_treated_htn)&D$diagnosed_or_treated_htn==0,]
    if(m$family=='supplement_diagnosed_treated')D<-D[(!is.na(D$diagnosed_or_treated_htn)&D$diagnosed_or_treated_htn==1)|D$hypertension_code==0,]
    if(m$subgroup!='Overall')D<-D[if(m$family=='table3')D$age_group==m$subgroup else D$smoking==m$subgroup,]
  }
  mf<-model.frame(as.formula(f$formula),D,xlev=f$xlevels,drop.unused.levels=TRUE,na.action=na.fail)
  X<-model.matrix(as.formula(f$formula),mf,contrasts.arg=f$contrasts)
  kept<-X[,names(f$coefficients),drop=FALSE]
  omitted<-setdiff(colnames(X),names(f$coefficients))
  for(column in omitted) {
    a<-X[,column];zero<-all(abs(a)<1e-12)
    error<-if(zero)0 else max(abs(qr.resid(qr(kept),a)))/max(1,max(abs(a)))
    ok<-error<1e-7;allok<-allok&&ok
    rows[[length(rows)+1]]<-data.frame(model=label,omitted_column=column,
      reason=if(zero)'constant zero in this domain'else'linear dependence on retained model-matrix columns',
      relative_residual=error,documented_in_lean_alias_fields=column%in%c(f$aliased_coefficients,f$metadata$aliased_terms),nonestimability_verified=ok)
  }
}
result<-do.call(rbind,rows)
write.csv(result,file.path(out,'E2_omitted_model_matrix_columns.csv'),row.names=FALSE)
cat('OMITTED_COLUMNS',nrow(result),'MODELS',length(unique(result$model)),'ALL_NONESTIMABLE',allok,'\n')
print(table(result$omitted_column,result$reason))
if(!allok)quit(status=1)
