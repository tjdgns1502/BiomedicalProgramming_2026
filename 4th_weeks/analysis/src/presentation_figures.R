# Visualization only. Fit and test results are unchanged.
a<-commandArgs(trailingOnly=TRUE)
if(length(a)!=2)stop("presentation_figures.R analysis.rds output_dir")
r<-readRDS(a[1]);out<-a[2]
png(file.path(out,"boxplots_log_axis.png"),width=1500,height=1100,res=150)
par(mfrow=c(2,2),mar=c(4,4,3,1))
for(m in names(r$marker_results)) {
  d<-r$marker_results[[m]]$data
  stopifnot(all(d$y>0))
  boxplot(y~group,d,log="y",xlab="Candidate FI group",ylab=paste(m,"(log axis)"),
    main=paste(m,"- same observed values"),col="#b5dcd9")
};dev.off()
cat("Added log-axis display; no values removed and no statistical model changed.\n")
