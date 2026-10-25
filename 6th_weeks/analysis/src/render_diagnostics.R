suppressWarnings(invisible(Sys.setlocale('LC_ALL','English_United States.utf8')))
args<-commandArgs(TRUE);root<-normalizePath(args[1],winslash='/',mustWork=TRUE);rid<-args[2]
.libPaths(c(file.path(root,'analysis/r-library'),.libPaths()))
source_file<-file.path(root,'analysis/runs',rid,'tables/observation_diagnostics.csv')
d<-read.csv(source_file,stringsAsFactors=FALSE)
out<-file.path(root,'analysis/renderings/STYLE1-20261024');if(dir.exists(out))stop('Style revision already exists');dir.create(out,recursive=TRUE)
devices<-c('Apple Watch','Fitbit Charge HR','Samsung Gear S','Mio Alpha');cols<-c('#28658A','#D08729','#BD4D4D','#26877B');names(cols)<-devices
setup<-function(name){png(file.path(out,name),width=1800,height=1500,res=160,type='cairo');par(mfrow=c(2,2),mar=c(4.8,4.9,3.4,1.5),oma=c(1,0,1.2,0),las=1,bty='l',family='sans',cex=.92)}
setup('04_regression_residuals.png')
for(name in devices){z<-d[d$device==name,];pad<-max(diff(range(z$residual))*.14,1);plot(z$fitted,z$residual,pch=21,bg=adjustcolor(cols[name],alpha.f=.65),col=cols[name],xlab='Fitted watch average (bpm)',ylab='OLS residual (bpm)',main=name,ylim=range(z$residual)+c(-pad,pad));abline(h=0,lty=2);k<-which.max(z$cooks_distance);text(z$fitted[k],z$residual[k],labels=paste0('ID ',z$participant_id[k]),pos=3,cex=.75)}
mtext('Same saved residuals; label placement revised without refitting',outer=TRUE,side=3,line=0,cex=.9);dev.off()
setup('05_residual_qq.png')
for(name in devices){z<-d[d$device==name,];q<-qqnorm(z$residual,plot.it=FALSE);plot(q$x,q$y,pch=21,bg=adjustcolor(cols[name],alpha.f=.65),col=cols[name],xlab='Theoretical normal quantile',ylab='Ordered OLS residual (bpm)',main=name,axes=FALSE);axis(1);axis(2,las=1);box(bty='l');qqline(z$residual,col='#555555',lty=2)}
mtext('Same saved residuals; explicit device titles and numeric axes',outer=TRUE,side=3,line=0,cex=.9);dev.off()
manifest<-list(style_revision='STYLE1-20261024',run_id=rid,source='tables/observation_diagnostics.csv',source_sha256=digest::digest(source_file,algo='sha256',file=TRUE),scope='Presentation only: restore QQ device labels and numeric y-axis; avoid clipping residual ID labels; no statistical refit or data change',overrides=list('04_regression_residuals.png'='analysis/renderings/STYLE1-20261024/04_regression_residuals.png','05_residual_qq.png'='analysis/renderings/STYLE1-20261024/05_residual_qq.png'))
jsonlite::write_json(manifest,file.path(out,'manifest.json'),auto_unbox=TRUE,pretty=TRUE)
cat('STYLE1: 2 plots, no statistical refits\n')
