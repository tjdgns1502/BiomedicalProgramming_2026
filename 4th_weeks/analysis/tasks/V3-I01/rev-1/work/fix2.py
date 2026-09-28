p='analysis/tasks/V3-I01/rev-1/work/models.R'
s=open(p,encoding='utf-8-sig').read()
s=s.replace("omit<-terms[vapply", "absent<-unlist(lapply(names(d$variables),function(v)if(is.factor(d$variables[[v]])){miss<-setdiff(levels(d$variables[[v]]),unique(as.character(d$variables[[v]])));if(length(miss))paste0(v,':',paste(miss,collapse='|'))}));d$variables<-droplevels(d$variables);omit<-terms[vapply")
s=s.replace("constant_factors_omitted=paste(omit,collapse='|'),weight_sum", "constant_factors_omitted=paste(omit,collapse='|'),absent_levels_removed=paste(absent,collapse=';'),weight_sum")
# Prediction model matrices must use fitted xlevels after domain droplevels.
s=s.replace("model.matrix(tt,new,contrasts.arg=f$contrasts)","model.matrix(tt,new,contrasts.arg=f$contrasts,xlev=f$xlevels)").replace("model.matrix(tt,rn,contrasts.arg=f$contrasts)","model.matrix(tt,rn,contrasts.arg=f$contrasts,xlev=f$xlevels)").replace("model.matrix(tt,nn,contrasts.arg=f$contrasts)","model.matrix(tt,nn,contrasts.arg=f$contrasts,xlev=f$xlevels)")
open(p,'w',encoding='utf-8').write(s)
