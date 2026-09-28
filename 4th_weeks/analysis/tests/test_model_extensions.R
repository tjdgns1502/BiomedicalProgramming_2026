# Synthetic fixture verifies domain preservation, design inference and estimand labels.
source("analysis/src/model_extensions.R")
set.seed(639174)
n<-1600
all<-data.frame(SEQN=seq_len(n),RIDAGEYR=sample(40:85,n,TRUE),
  RIAGENDR=sample(1:2,n,TRUE),RIDRETH1=sample(1:5,n,TRUE),
  cycle=sample(c("2009-2010","2011-2012"),n,TRUE),
  SDMVSTRA=rep(1:40,each=40),SDMVPSU=rep(rep(1:2,each=20),40),
  weight_mec_18yr=runif(n,1,3))
d<-all[all$RIDAGEYR>=50,]
def<-matrix(rbinom(nrow(d)*36,1,.23),nrow(d),36)
d$FI<-rowMeans(def);d$deficit_29<-def[,29]
for(m in markers)d[[m]]<-exp(rnorm(nrow(d),.3,.4))
out<-commandArgs(trailingOnly=TRUE)[1]
if(is.na(out))stop("Specify synthetic output directory")
z<-extensions(d,all,out)
stopifnot(nrow(z$models)==32,nrow(z$group_tests)==4,all(z$models$convergence))
counts<-read.csv(file.path(out,"design_counts.csv"))
stopifnot(counts$n_full==1600,counts$n_candidate==nrow(d),counts$design_df==40)
p<-read.csv(file.path(out,"fractional_mean_predictions.csv"))
stopifnot(all(p$adjusted_mean_FI_at_p25>0 & p$adjusted_mean_FI_at_p25<1))
stopifnot(all(is.finite(z$models$se)),all(z$models$se>0))
cat("PASS synthetic only: full design preserved, domain counted, 32 models converged, bounded fractional predictions\n")
