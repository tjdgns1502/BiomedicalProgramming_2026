# Predeclared alternative coding changes measurement; use the SAME people to isolate that change.
source("analysis/src/group_analysis.R")
a<-commandArgs(trailingOnly=TRUE)
if(length(a)!=2)stop("fi_coding_sensitivity.R candidate_all_age50.csv output_dir")
d<-read.csv(a[1]);out<-a[2];dir.create(out,recursive=TRUE,showWarnings=FALSE)
primary<-d[is.finite(d$FI_candidate36),]
stopifnot(all(is.finite(primary$FI_candidate36_alt)))
gp<-assign_fi_groups(primary)
alt<-primary;alt$FI<-alt$FI_candidate36_alt
res<-analyze_groups(alt,file.path(out,"alternative_same_people"),make_plots=FALSE)
transition<-as.data.frame(table(primary_group=gp$data$FI_group,alternative_group=res$grouped$data$FI_group))
write.csv(transition,file.path(out,"group_transition_same_people.csv"),row.names=FALSE)
write.csv(data.frame(n=nrow(primary),mean_FI=mean(primary$FI),mean_FI_alt=mean(alt$FI),
  frail_primary=sum(primary$FI>.3),frail_alt_same_people=sum(alt$FI>.3),
  changed_binary=sum((primary$FI>.3)!=(alt$FI>.3)),
  changed_quartile=sum(gp$data$FI_group!=res$grouped$data$FI_group)),file.path(out,"same_people_summary.csv"),row.names=FALSE)
retention<-do.call(rbind,lapply(c("age_band","RIAGENDR","RIDRETH1","cycle"),function(v) {
  do.call(rbind,lapply(sort(unique(d[[v]])),function(level) {
    z<-d[!is.na(d[[v]]) & d[[v]]==level,];n<-nrow(z);comp<-is.finite(z$FI)
    data.frame(variable=v,level=level,n_available=n,n_primary=sum(comp),
      retained_percent=100*mean(comp),n_alt=sum(is.finite(z$FI_candidate36_alt)))
  }))
}))
write.csv(retention,file.path(out,"retention_by_demography.csv"),row.names=FALSE)
writeLines(c("Alternative coding was specified before observed outcomes in fi_candidate.json.",
  "Same primary-complete people: health>=3, medicine>=4, visits>=4 versus primary health>=4, medicine>=5, visits>=6.",
  "This changes three rules jointly; cannot attribute the difference to one rule.",
  "Alternative-complete cohort size reported only in retention table, not mixed into same-person effect comparison.",
  "All alternative analyses exploratory, not independent replication or selection of a preferred rule.",capture.output(sessionInfo())),file.path(out,"execution-notes.txt"))
print(read.csv(file.path(out,"same_people_summary.csv")))
