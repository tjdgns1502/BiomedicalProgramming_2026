suppressWarnings(invisible(Sys.setlocale('LC_ALL','English_United States.utf8')))
args <- commandArgs(trailingOnly=TRUE)
if(length(args)<1) stop('Usage: Rscript analyse_heart_rate.R PROJECT_ROOT [NEW_RUN_ID]')
root <- normalizePath(args[1],winslash='/',mustWork=TRUE)
.libPaths(c(file.path(root,'analysis/r-library'),.libPaths()))
for(pkg in c('readxl','jsonlite','digest')) if(!requireNamespace(pkg,quietly=TRUE)) stop('Missing package: ',pkg)
plan_path <- file.path(root,'analysis/config/plan-v1.0.json')
plan <- jsonlite::fromJSON(plan_path,simplifyVector=FALSE)
run_id <- if(length(args)>=2) args[2] else plan$run_id
if(!grepl('^[A-Za-z0-9][A-Za-z0-9_.-]{0,90}$',run_id)) stop('Unsafe run ID')
run <- file.path(root,'analysis/runs',run_id)
if(dir.exists(run)) stop('Existing run is immutable; choose a new run ID')
dir.create(run,recursive=TRUE)
for(d in c('tables','figures','models','logs')) dir.create(file.path(run,d))
started <- Sys.time(); warnings_seen <- character(); checks <- list()
now <- function() format(Sys.time(),'%Y-%m-%dT%H:%M:%SZ',tz='UTC')
sha <- function(p) digest::digest(p,algo='sha256',file=TRUE)
write_json <- function(x,p) jsonlite::write_json(x,p,auto_unbox=TRUE,pretty=TRUE,digits=NA,na='null',null='null')
csv <- function(x,name) write.csv(x,file.path(run,'tables',name),row.names=FALSE,na='',fileEncoding='UTF-8')
check <- function(name,pass,detail='') {checks[[length(checks)+1]] <<- data.frame(check=name,passed=isTRUE(pass),detail=detail);if(!isTRUE(pass)) stop('Validation failed: ',name,' ',detail)}
options(digits=17)
file.copy(plan_path,file.path(run,'plan-v1.0.json'),overwrite=FALSE)
filearg <- grep('^--file=',commandArgs(),value=TRUE)
if(length(filearg)) file.copy(sub('^--file=','',filearg[1]),file.path(run,'executed_script.R'),overwrite=FALSE)

execute <- function(){
 raw_path <- file.path(root,plan$raw_file)
 check('raw_sha256',identical(sha(raw_path),plan$raw_sha256))
 t0 <- Sys.time()
 header_expected <- c('ID','Apple_device','Apple_ECG','Trial_number','Fitbit_device','Fitbit_metamax','Trial_number','Samsung_device','Samsung_ECG','Trial_number','Alpha_device','Alpha_ECG','Trial_number')
 raw <- as.data.frame(readxl::read_excel(raw_path,sheet='Heart_Rate',range='A1:M23',col_names=FALSE,col_types='text',.name_repair='minimal'),stringsAsFactors=FALSE)
 check('header_exact',identical(unname(as.character(unlist(raw[1,]))),header_expected))
 check('raw_shape',nrow(raw)==23 && ncol(raw)==13)
 vals <- raw[-1,,drop=FALSE]
 id <- as.integer(vals[,1]);check('participant_ids_unique',!anyDuplicated(id));check('participant_ids_full',identical(sort(id),1:22))
 key <- as.data.frame(readxl::read_excel(raw_path,sheet='Key',col_names=FALSE,col_types='text',.name_repair='minimal'),stringsAsFactors=FALSE)
 key_start <- which(key[,1]=='Worksheet_4')[1]
 idx <- which(seq_len(nrow(key))>key_start & key[,1]=='Fitbit_metamax')[1]
 check('Fitbit_reference_ECG_key',grepl('electrocardiography',key[idx,2],ignore.case=TRUE))
 devices <- c('Apple Watch','Fitbit Charge HR','Samsung Gear S','Mio Alpha')
 codes <- c('Apple','Fitbit','Samsung','Mio')
 starts <- c(2L,5L,8L,11L)
 records <- vector('list',4)
 for(j in seq_along(devices)){
  c0 <- starts[j]; xlrow <- seq_len(nrow(vals))+1
  records[[j]] <- data.frame(participant_id=id,device=devices[j],device_code=codes[j],trial=as.integer(vals[,c0+2]),reference_bpm=as.numeric(vals[,c0+1]),device_bpm=as.numeric(vals[,c0]),source_sheet='Heart_Rate',source_row=xlrow,device_cell=paste0(LETTERS[c0],xlrow),reference_cell=paste0(LETTERS[c0+1],xlrow),trial_cell=paste0(LETTERS[c0+2],xlrow),raw_reference_header=header_expected[c0+1],stringsAsFactors=FALSE)
 }
 d <- do.call(rbind,records);d$pair_id <- paste(d$participant_id,d$device_code,sep=':')
 valid <- is.finite(d$reference_bpm)&is.finite(d$device_bpm)&d$reference_bpm>0&d$device_bpm>0&d$trial%in%c(1L,2L)
 excluded <- d[!valid,,drop=FALSE];excluded$reason <- rep('missing/invalid numeric pair or trial',nrow(excluded))
 csv(excluded,'excluded_pairs.csv')
 check('all_88_pairs_valid',nrow(d)==88 && all(valid))
 check('unique_pair_ids',!anyDuplicated(d$pair_id))
 check('each_device_n22',all(table(d$device)==22))
 trial_groups <- split(d,paste(d$participant_id,d$trial,sep=':'))
 check('two_devices_per_participant_trial',length(trial_groups)==44 && all(vapply(trial_groups,nrow,integer(1))==2))
 check('same_trial_reference_agrees',all(vapply(trial_groups,function(z)max(z$reference_bpm)-min(z$reference_bpm)<1e-10,logical(1))))
 d$error_bpm <- d$device_bpm-d$reference_bpm
 d$pair_mean_bpm <- (d$device_bpm+d$reference_bpm)/2
 d$relative_error_percent <- 100*d$error_bpm/d$reference_bpm
 d$absolute_error_bpm <- abs(d$error_bpm)
 csv(d,'heart_rate_pairs.csv')
 flow <- data.frame(stage=c('Heart_Rate participant rows','Expected participant-device slots','Finite positive pairs with trial1/2','Final primary pairs'),people=c(22,22,22,22),pairs=c(88,88,88,88),excluded=c(0,0,0,0),meaning=c('Four device/reference blocks per person','Wide to long; no averaging','All original HR pairs valid','No downsampling, outlier deletion or imputation'))
 csv(flow,'data_flow.csv')
 csv(as.data.frame(table(device=d$device,trial=d$trial)),'device_trial_counts.csv')
 metric_list <- list();coeff_list <- list();diag_list <- list();loo_list <- list();pred_list <- list();models <- list()
 for(j in seq_along(devices)){
  z <- d[d$device==devices[j],];x <- z$reference_bpm;y <- z$device_bpm;e <- y-x;n <- length(x)
  fit <- lm(device_bpm~reference_bpm,data=z);models[[devices[j]]] <- fit
  pear <- cor.test(x,y,method='pearson');spear <- cor.test(x,y,method='spearman',exact=FALSE)
  sm <- summary(fit);ci <- confint(fit);bt <- t.test(e,mu=0)
  trend <- lm(error_bpm~pair_mean_bpm,data=z);tr <- summary(trend)
  swerr <- shapiro.test(e);swres <- shapiro.test(residuals(fit))
  coefmat <- coef(sm)
  metric_list[[j]] <- data.frame(device=devices[j],n=n,n_people=length(unique(z$participant_id)),mean_reference=mean(x),sd_reference=sd(x),mean_device=mean(y),sd_device=sd(y),reference_min=min(x),reference_max=max(x),pearson_r=unname(pear$estimate),r_ci_low=pear$conf.int[1],r_ci_high=pear$conf.int[2],pearson_p=pear$p.value,spearman_rho=unname(spear$estimate),spearman_p=spear$p.value,intercept=unname(coef(fit)[1]),intercept_ci_low=ci[1,1],intercept_ci_high=ci[1,2],slope=unname(coef(fit)[2]),slope_ci_low=ci[2,1],slope_ci_high=ci[2,2],slope_se=coefmat[2,2],slope_p=coefmat[2,4],r_squared=sm$r.squared,residual_sigma=sm$sigma,residual_df=df.residual(fit),bias=mean(e),error_sd=sd(e),bias_ci_low=bt$conf.int[1],bias_ci_high=bt$conf.int[2],bias_p=bt$p.value,error_median=median(e),error_q1=unname(quantile(e,.25)),error_q3=unname(quantile(e,.75)),error_min=min(e),error_max=max(e),mae=mean(abs(e)),rmse=sqrt(mean(e^2)),mpe=mean(100*e/x),mape=mean(100*abs(e)/x),classical_loa_low=mean(e)-1.96*sd(e),classical_loa_high=mean(e)+1.96*sd(e),ba_bias_slope=unname(coef(trend)[2]),ba_bias_slope_p=coef(tr)[2,4],shapiro_error_p=swerr$p.value,shapiro_residual_p=swres$p.value,max_abs_error_id=z$participant_id[which.max(abs(e))],max_cooks_id=z$participant_id[which.max(cooks.distance(fit))],max_cooks=max(cooks.distance(fit)),predicted_at_ecg100=unname(predict(fit,newdata=data.frame(reference_bpm=100))),stringsAsFactors=FALSE)
  coeff_list[[j]] <- data.frame(device=devices[j],term=rownames(coefmat),estimate=coefmat[,1],se=coefmat[,2],t=coefmat[,3],p=coefmat[,4],ci_low=ci[,1],ci_high=ci[,2],row.names=NULL)
  diag_list[[j]] <- data.frame(pair_id=z$pair_id,participant_id=z$participant_id,device=devices[j],fitted=fitted(fit),residual=residuals(fit),studentized_residual=rstudent(fit),leverage=hatvalues(fit),cooks_distance=cooks.distance(fit))
  gx <- seq(min(x),max(x),length.out=100);pred <- predict(fit,newdata=data.frame(reference_bpm=gx),interval='confidence')
  pred_list[[j]] <- data.frame(device=devices[j],reference_bpm=gx,fit=pred[,1],mean_response_ci_low=pred[,2],mean_response_ci_high=pred[,3])
  loo_list[[j]] <- do.call(rbind,lapply(seq_len(n),function(k){zz <- z[-k,];ff<-lm(device_bpm~reference_bpm,data=zz);data.frame(device=devices[j],left_out_id=z$participant_id[k],n=nrow(zz),r=cor(zz$reference_bpm,zz$device_bpm),slope=unname(coef(ff)[2]),intercept=unname(coef(ff)[1]),bias=mean(zz$error_bpm),mae=mean(abs(zz$error_bpm)))}))
  check(paste0(codes[j],'_slope_formula'),abs(unname(coef(fit)[2])-cov(x,y)/var(x))<1e-12)
  check(paste0(codes[j],'_r2_identity'),abs(sm$r.squared-cor(x,y)^2)<1e-12)
  check(paste0(codes[j],'_bias_identity'),abs(mean(e)-(mean(y)-mean(x)))<1e-12)
  check(paste0(codes[j],'_rmse_identity'),abs(mean(e^2)-(mean(e)^2+(n-1)/n*var(e)))<1e-10)
 }
 metrics <- do.call(rbind,metric_list);metrics$pearson_p_holm <- p.adjust(metrics$pearson_p,'holm');metrics$bias_p_holm<-p.adjust(metrics$bias_p,'holm')
 coefficients <- do.call(rbind,coeff_list);diagnostics<-do.call(rbind,diag_list);loo<-do.call(rbind,loo_list);predictions<-do.call(rbind,pred_list)
 csv(metrics,'device_summary.csv');csv(coefficients,'regression_coefficients.csv');csv(diagnostics,'observation_diagnostics.csv');csv(loo,'leave_one_participant_out.csv');csv(predictions,'regression_mean_response_ci.csv')
 loo_summary <- do.call(rbind,lapply(devices,function(name){v<-loo[loo$device==name,];data.frame(device=name,loo_r_min=min(v$r),loo_r_max=max(v$r),loo_slope_min=min(v$slope),loo_slope_max=max(v$slope),loo_bias_min=min(v$bias),loo_bias_max=max(v$bias),loo_mae_min=min(v$mae),loo_mae_max=max(v$mae),largest_r_change_id=v$left_out_id[which.max(abs(v$r-metrics$pearson_r[metrics$device==name]))])}))
 csv(loo_summary,'sensitivity_summary.csv')
 timing_compute <- as.numeric(difftime(Sys.time(),t0,units='secs'))
 cols<-c('#28658A','#D08729','#BD4D4D','#26877B');names(cols)<-devices
 openplot<-function(file,w=1800,h=1500){png(file.path(run,'figures',file),width=w,height=h,res=160,type='cairo');par(mfrow=c(2,2),mar=c(4.6,4.7,3.1,1.3),oma=c(1,0,1,0),cex=.92,las=1,bty='l',family='sans')}
 finish<-function(title){mtext(title,outer=TRUE,side=3,line=-.2,cex=.9);dev.off()}
 hr_range<-range(c(d$reference_bpm,d$device_bpm));hr_range<-hr_range+c(-3,3)
 openplot('01_scatter_regression.png')
 for(name in devices){z<-d[d$device==name,];pr<-predictions[predictions$device==name,];m<-metrics[metrics$device==name,];plot(z$reference_bpm,z$device_bpm,type='n',xlim=hr_range,ylim=hr_range,xlab='Concurrent ECG average (bpm)',ylab='Watch average (bpm)',main=paste0(name,'  (n=22)'),asp=1);polygon(c(pr$reference_bpm,rev(pr$reference_bpm)),c(pr$mean_response_ci_low,rev(pr$mean_response_ci_high)),col=adjustcolor(cols[name],alpha.f=.12),border=NA);abline(0,1,lty=2,col='#333333',lwd=1.8);lines(pr$reference_bpm,pr$fit,col=cols[name],lwd=2);points(z$reference_bpm,z$device_bpm,pch=21,bg=adjustcolor(cols[name],alpha.f=.7),col=cols[name],cex=1);legend('topleft',legend=c(sprintf('r = %.3f; R2 = %.3f',m$pearson_r,m$r_squared),sprintf('y = %.2f + %.3f x',m$intercept,m$slope),'Dashed: identity y=x'),bty='n',cex=.8);k<-which.max(abs(z$error_bpm));text(z$reference_bpm[k],z$device_bpm[k],labels=paste0('ID ',z$participant_id[k]),pos=4,cex=.65,col='#333333')}
 finish('All 88 original participant-watch average pairs; shaded band: 95% mean-response CI')
 breaks<-seq(floor(min(d$error_bpm)/5)*5,ceiling(max(d$error_bpm)/5)*5,by=5);if(length(breaks)<3)breaks<-seq(-10,10,5)
 ymax<-max(vapply(devices,function(name)max(hist(d$error_bpm[d$device==name],breaks=breaks,plot=FALSE)$counts),numeric(1)))+1
 openplot('02_error_histograms.png')
 for(name in devices){z<-d[d$device==name,];m<-metrics[metrics$device==name,];hist(z$error_bpm,breaks=breaks,col=adjustcolor(cols[name],alpha.f=.65),border='white',xlim=range(breaks),ylim=c(0,ymax),main=name,xlab='Watch minus ECG (bpm)',ylab='Number of participants');abline(v=0,lty=2,lwd=2);abline(v=m$bias,col=cols[name],lwd=2);legend('topleft',c(sprintf('Mean = %.2f bpm',m$bias),sprintf('MAE = %.2f bpm',m$mae)),bty='n',cex=.8)}
 finish('Shared 5-bpm bins; negative errors are underestimation; no observations removed')
 openplot('03_bland_altman.png')
 erange<-range(c(d$error_bpm,metrics$classical_loa_low,metrics$classical_loa_high));erange<-erange+c(-3,3)
 for(name in devices){z<-d[d$device==name,];m<-metrics[metrics$device==name,];plot(z$pair_mean_bpm,z$error_bpm,pch=21,bg=adjustcolor(cols[name],alpha.f=.65),col=cols[name],xlab='Mean of watch and ECG (bpm)',ylab='Watch minus ECG (bpm)',main=name,ylim=erange);abline(h=0,col='#777777',lty=3);abline(h=m$bias,col=cols[name],lwd=2);abline(h=c(m$classical_loa_low,m$classical_loa_high),col='#AA4444',lty=2,lwd=1.7);abline(lm(error_bpm~pair_mean_bpm,data=z),col=cols[name],lty=3);legend('bottomleft',c(sprintf('Bias %.2f; SD %.2f',m$bias,m$error_sd),sprintf('Classical LoA [%.2f, %.2f]',m$classical_loa_low,m$classical_loa_high)),bty='n',cex=.75)}
 finish('Descriptive classical limits = mean error +/- 1.96 SD; not regression-adjusted paper LoA')
 openplot('04_regression_residuals.png')
 for(name in devices){v<-diagnostics[diagnostics$device==name,];plot(v$fitted,v$residual,pch=21,bg=adjustcolor(cols[name],alpha.f=.65),col=cols[name],xlab='Fitted watch average (bpm)',ylab='OLS residual (bpm)',main=name);abline(h=0,lty=2);k<-which.max(v$cooks_distance);text(v$fitted[k],v$residual[k],labels=paste0('ID ',v$participant_id[k]),pos=3,cex=.7)}
 finish('Residuals and most influential Cook-distance participant; primary sample unchanged')
 openplot('05_residual_qq.png')
 for(name in devices){v<-diagnostics[diagnostics$device==name,];q<-qqnorm(v$residual,plot.it=FALSE);plot(q$x,q$y,pch=21,bg=adjustcolor(cols[name],alpha.f=.65),col=cols[name],main=name,xlab='Theoretical normal quantile',ylab='Ordered OLS residual (bpm)',axes=FALSE);axis(1);axis(2,las=1);box(bty='l');qqline(v$residual,col='#555555',lty=2)}
 finish('Normality diagnostic; n=22 per watch; not a method-selection rule')
 png(file.path(run,'figures/06_leave_one_out.png'),width=1800,height=900,res=160,type='cairo');par(mfrow=c(1,2),mar=c(4.5,10,3,1),las=1,bty='l')
 for(metric in c('r','slope')){low<-loo_summary[[paste0('loo_',metric,'_min')]];high<-loo_summary[[paste0('loo_',metric,'_max')]];full<-if(metric=='r')metrics$pearson_r else metrics$slope;plot(full,4:1,pch=19,col=cols[devices],xlim=range(c(low,high,full))+c(-.025,.025),ylim=c(.5,4.5),yaxt='n',xlab=if(metric=='r')'Pearson r' else 'OLS slope',ylab='',main=if(metric=='r')'Leave-one-participant-out r' else 'Leave-one-participant-out slope');axis(2,at=4:1,labels=devices,las=1);segments(low,4:1,high,4:1,col=cols[devices],lwd=3);points(full,4:1,pch=19,cex=1.3,col='#172D38');if(metric=='slope')abline(v=1,lty=2,col='#999999')};dev.off()
 png(file.path(run,'figures/07_bias_and_mae.png'),width=1800,height=900,res=160,type='cairo');par(mfrow=c(1,2),mar=c(4.5,10,3,1),las=1,bty='l')
 plot(metrics$bias,4:1,pch=19,col=cols[devices],xlim=range(c(metrics$bias_ci_low,metrics$bias_ci_high,0))+c(-1,1),ylim=c(.5,4.5),yaxt='n',xlab='Mean watch - ECG (bpm)',ylab='',main='Signed bias and pointwise 95% t CI');axis(2,at=4:1,labels=devices);segments(metrics$bias_ci_low,4:1,metrics$bias_ci_high,4:1,col=cols[devices],lwd=3);abline(v=0,lty=2,col='#777777')
 plot(metrics$mae,4:1,pch=19,col=cols[devices],xlim=c(0,max(metrics$mae)*1.15),ylim=c(.5,4.5),yaxt='n',xlab='Mean absolute error (bpm)',ylab='',main='Average magnitude of disagreement');axis(2,at=4:1,labels=devices);segments(0,4:1,metrics$mae,4:1,col=cols[devices],lwd=3);dev.off()
 saveRDS(models,file.path(run,'models/per_device_ols.rds'))
 csv(do.call(rbind,checks),'validation_checks.csv')
 csv(data.frame(device=devices,records=22,people=22,excluded=0,unit='participant-device average'),'analysis_counts.csv')
 check('raw_unchanged_after_analysis',identical(sha(raw_path),plan$raw_sha256))
 csv(do.call(rbind,checks),'validation_checks.csv')
 writeLines(capture.output(sessionInfo()),file.path(run,'logs/sessionInfo.txt'),useBytes=TRUE)
 write_json(list(R=R.version.string,library_paths=.libPaths(),readxl=as.character(packageVersion('readxl')),jsonlite=as.character(packageVersion('jsonlite')),digest=as.character(packageVersion('digest')),locale=Sys.getlocale()),file.path(run,'environment.json'))
 result<-list(run_id=run_id,plan_version=plan$plan_version,data_version=plan$data_version,started_utc=format(started,'%Y-%m-%dT%H:%M:%SZ',tz='UTC'),completed_utc=now(),elapsed_seconds=as.numeric(difftime(Sys.time(),started,units='secs')),numeric_analysis_seconds=timing_compute,raw_sha256=sha(raw_path),plan_sha256=sha(plan_path),n_people=22,n_pairs=88,devices=devices,excluded_pairs=nrow(excluded),downsampled=FALSE,imputed=FALSE,outliers_removed=FALSE,source_level='participant-device protocol averages; no per-time/per-activity HR supplied',checks_passed=length(checks),primary_OLS_models=4,leave_one_out_fits=88,warning_count=length(warnings_seen),review_scope='same-agent mathematical identities; separate Python cross-check follows; not independent-agent review',summary=metrics,sensitivity=loo_summary)
 write_json(result,file.path(run,'report.json'))
 write_json(list(status='success',run_id=run_id,completed_utc=now(),raw_sha256=sha(raw_path),data_version=plan$data_version),file.path(run,'status.json'))
 cat(jsonlite::toJSON(list(run_id=run_id,n_people=22,n_pairs=88,excluded=0,checks=length(checks),elapsed_seconds=result$elapsed_seconds,summary=metrics[,c('device','pearson_r','slope','bias','mae','rmse')]),auto_unbox=TRUE,digits=8),'\n')
}
tryCatch(withCallingHandlers(execute(),warning=function(w){warnings_seen<<-c(warnings_seen,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e){write_json(list(status='failed',run_id=run_id,failed_utc=now(),error=conditionMessage(e)),file.path(run,'status.json'));if(length(checks))csv(do.call(rbind,checks),'validation_checks.csv');stop(conditionMessage(e),call.=FALSE)})
write.csv(data.frame(message=warnings_seen),file.path(run,'logs/warnings.csv'),row.names=FALSE,fileEncoding='UTF-8')
files<-list.files(run,recursive=TRUE,full.names=TRUE);files<-files[file.info(files)$isdir==FALSE]
hashes<-data.frame(file=substring(gsub('\\\\','/',files),nchar(gsub('\\\\','/',run))+2),bytes=file.info(files)$size,sha256=vapply(files,sha,character(1)))
write.csv(hashes,file.path(run,'artifact_hashes.csv'),row.names=FALSE,fileEncoding='UTF-8')
