Sys.setlocale('LC_ALL','English_United States.utf8')
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
run_dir <- normalizePath(args[[1]], winslash='/', mustWork=TRUE)
out_dir <- normalizePath(args[[2]], winslash='/', mustWork=TRUE)
root <- normalizePath(file.path(run_dir, '..', '..', '..'), winslash='/', mustWork=TRUE)
.libPaths(c(file.path(root, 'analysis', 'r-library'), .libPaths()))
stopifnot(requireNamespace('haven'), requireNamespace('digest'), requireNamespace('jsonlite'), requireNamespace('survey'))
status <- jsonlite::read_json(file.path(run_dir,'status.json'), simplifyVector=TRUE)
if (!identical(status$status,'success')) stop('Only a completed success run can receive Q-data review.')
checks <- list()
record <- function(id, passed, evidence) {
  checks[[length(checks)+1L]] <<- list(id=id, passed=isTRUE(passed), evidence=evidence)
}
sha <- function(path) digest::digest(file=path,algo='sha256',serialize=FALSE)
manifest <- read.csv(file.path(run_dir,'sources_manifest.csv'),stringsAsFactors=FALSE)
manifest$independent_sha256 <- vapply(manifest$file,sha,character(1))
manifest$hash_passed <- manifest$sha256 == manifest$independent_sha256
record('all_source_hashes',all(manifest$hash_passed),list(n=nrow(manifest), failed=manifest$file[!manifest$hash_passed]))
write.csv(manifest,file.path(out_dir,'source_hash_check.csv'),row.names=FALSE)
raw <- manifest[manifest$kind == 'xpt',]
record('25_unique_raw_files',nrow(raw)==25L && !anyDuplicated(basename(raw$file)),nrow(raw))

chosen <- list(DEMO=c('SEQN','RIDAGEYR','RIAGENDR','RIDRETH1','DMDEDUC2','WTMEC2YR','SDMVPSU','SDMVSTRA'),
               OHQ=c('SEQN','OHQ835','OHQ845'), BPQ=c('SEQN','BPQ020','BPQ040A','BPQ050A'),
               BPX=c('SEQN',paste0('BPXSY',1:4),paste0('BPXDI',1:4)), SMQ=c('SEQN','SMQ020'))
pieces <- list(); code_counts <- list(); component_counts <- list()
for (cycle in unique(raw$cycle)) {
  component_data <- list()
  for (component in names(chosen)) {
    row <- raw[raw$cycle==cycle & raw$component==component,]
    stopifnot(nrow(row)==1L)
    d <- as.data.frame(haven::read_xpt(row$file))
    record(paste('raw_unique',cycle,component,sep='_'),!anyDuplicated(d$SEQN) && !anyNA(d$SEQN),nrow(d))
    for (name in setdiff(chosen[[component]],names(d))) d[[name]] <- NA_real_
    d <- d[,chosen[[component]],drop=FALSE]
    d[] <- lapply(d,as.numeric)
    component_data[[component]] <- d
    component_counts[[length(component_counts)+1L]] <- data.frame(cycle=cycle,component=component,n=nrow(d))
    if(component %in% c('OHQ','BPQ','SMQ')) for(name in setdiff(names(d),'SEQN')) {
      tab <- table(d[[name]],useNA='always')
      code_counts[[length(code_counts)+1L]] <- data.frame(cycle=cycle,variable=name,code=names(tab),n=as.integer(tab))
    }
  }
  d <- component_data$DEMO
  for(component in setdiff(names(chosen),'DEMO')) {
    match_index <- match(d$SEQN,component_data[[component]]$SEQN)
    fields <- setdiff(names(component_data[[component]]),'SEQN')
    for(field in fields) d[[field]] <- component_data[[component]][[field]][match_index]
  }
  d$cycle <- cycle
  pieces[[cycle]] <- d
}
x <- do.call(rbind,pieces)
rownames(x) <- NULL
x$key <- paste(x$cycle,x$SEQN,sep=':')
record('independent_cycle_key_unique',!anyDuplicated(x$key),nrow(x))
write.csv(do.call(rbind,component_counts),file.path(out_dir,'independent_component_counts.csv'),row.names=FALSE)
write.csv(do.call(rbind,code_counts),file.path(out_dir,'independent_raw_code_counts.csv'),row.names=FALSE)

# Independently reconstruct only from raw variables. Do not source run_analysis.R.
num_bp <- function(prefix,zero) {
  m <- as.matrix(x[,paste0(prefix,1:4)])
  m[!is.finite(m) | if(zero) m < 0 else m <= 0] <- NA_real_
  n <- rowSums(!is.na(m)); means <- rowMeans(m,na.rm=TRUE); means[n==0L] <- NA_real_
  list(matrix=m,n=n,mean=means)
}
sbp <- num_bp('BPXSY',FALSE); dbp <- num_bp('BPXDI',TRUE)
complete_bp <- sbp$n>0 & dbp$n>0
measured <- ifelse(complete_bp,as.integer(sbp$mean>=140 | dbp$mean>=90),NA_integer_)
diagnosed <- ifelse(x$BPQ020==1,1L,ifelse(x$BPQ020==2,0L,NA_integer_))
med <- ifelse(x$BPQ050A==1,1L,ifelse(x$BPQ050A==2,0L,NA_integer_))
structural_med_no <- is.na(med) & ((!is.na(x$BPQ020) & x$BPQ020==2) | (!is.na(x$BPQ040A) & x$BPQ040A==2))
med[structural_med_no] <- 0L
any_yes <- (!is.na(measured) & measured==1) | (!is.na(diagnosed) & diagnosed==1) | (!is.na(med) & med==1)
all_no <- !is.na(measured) & measured==0 & !is.na(diagnosed) & diagnosed==0 & !is.na(med) & med==0
htn <- rep(NA_integer_,nrow(x)); htn[all_no] <- 0L; htn[any_yes] <- 1L
pd <- ifelse(x$OHQ835==1,1L,ifelse(x$OHQ835==2,0L,NA_integer_))
smoke <- ifelse(x$SMQ020==1,1L,ifelse(x$SMQ020==2,0L,NA_integer_))
oral_levels <- c('Excellent/Very good','Good','Fair','Poor')
oral <- rep(NA_character_,nrow(x)); oral[x$OHQ845 %in% c(1,2)] <- oral_levels[1]
for(i in 3:5) oral[which(x$OHQ845==i)] <- oral_levels[i-1]
weight <- x$WTMEC2YR/5
eligible <- is.finite(weight) & weight>0 & is.finite(x$SDMVPSU) & is.finite(x$SDMVSTRA)
stage <- list(all_demo=rep(TRUE,nrow(x)))
stage$age30 <- !is.na(x$RIDAGEYR) & x$RIDAGEYR>=30
stage$valid_measured_sbp_dbp <- stage$age30 & complete_bp
stage$observed_periodontal <- stage$valid_measured_sbp_dbp & !is.na(pd)
stage$observed_oral_health <- stage$observed_periodontal & !is.na(oral)
stage$observed_smoking <- stage$observed_oral_health & !is.na(smoke)
stage$observed_hypertension <- stage$observed_smoking & !is.na(htn)
stage$positive_mec_weight_valid_design <- stage$observed_hypertension & eligible
domain <- stage$positive_mec_weight_valid_design
flow <- data.frame(stage=names(stage),n=vapply(stage,sum,integer(1)))
actual_flow <- read.csv(file.path(run_dir,'tables','sample_flow.csv'),stringsAsFactors=FALSE)
record('flow_matches_independent_raw_reconstruction',identical(flow$stage,actual_flow$stage) && identical(as.integer(flow$n),as.integer(actual_flow$n)),flow)
write.csv(flow,file.path(out_dir,'independent_sample_flow.csv'),row.names=FALSE)

master <- readRDS(file.path(run_dir,'derived','master.rds'))
j <- match(x$key,paste(master$cycle,master$SEQN,sep=':'))
record('master_raw_keys',!anyNA(j) && length(j)==nrow(master),list(raw_n=nrow(x),master_n=nrow(master)))
same <- function(a,b) {
  if (length(a) != length(b)) return(FALSE)
  all((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a-b)<1e-10))
}
for(name in c('SEQN','RIDAGEYR','RIAGENDR','RIDRETH1','DMDEDUC2','WTMEC2YR','SDMVPSU','SDMVSTRA','OHQ835','OHQ845','SMQ020','BPQ020','BPQ040A','BPQ050A',paste0('BPXSY',1:4),paste0('BPXDI',1:4))) {
  record(paste0('master_raw_',name),same(x[[name]],as.numeric(master[[name]][j])),name)
}
derived <- list(mean_sbp=sbp$mean,mean_dbp=dbp$mean,n_valid_sbp=sbp$n,n_valid_dbp=dbp$n,
                periodontal_code=pd,smoking_code=smoke,measured_htn=measured,diagnosis_htn=diagnosed,
                medication_htn=med,hypertension_code=htn,mec_weight=weight)
for(name in names(derived)) record(paste0('derived_',name),same(derived[[name]],as.numeric(master[[name]][j])),name)
record('derived_oral',identical(oral,as.character(master$oral_health[j])),oral_levels)
record('derived_analysis_domain',identical(domain,as.logical(master$analysis_domain[j])),sum(domain))
record('derived_structural_med_no',identical(structural_med_no,as.logical(master$medication_structural_no[j])),sum(structural_med_no))

labels <- list(periodontal=ifelse(is.na(pd),NA,ifelse(pd==1,'Yes','No')),oral_health=oral,
               smoking=ifelse(is.na(smoke),NA,ifelse(smoke==1,'Yes','No')),
               sex=ifelse(x$RIAGENDR==1,'Male',ifelse(x$RIAGENDR==2,'Female','Missing')),
               race=ifelse(x$RIDRETH1==1,'Mexican American',ifelse(x$RIDRETH1==2,'Other Hispanic',ifelse(x$RIDRETH1==3,'Non-Hispanic White',ifelse(x$RIDRETH1==4,'Non-Hispanic Black',ifelse(x$RIDRETH1==5,'Other race including multiracial','Missing'))))),
               education=ifelse(x$DMDEDUC2 %in% c(1,2),'Less than high school',ifelse(x$DMDEDUC2==3,'High school',ifelse(x$DMDEDUC2 %in% c(4,5),'More than high school','Missing'))),
               age_group=ifelse(x$RIDAGEYR<45,'30-44','45+'))
labels$education[is.na(labels$education)] <- 'Missing'
table1 <- read.csv(file.path(run_dir,'tables','table1_categorical.csv'),stringsAsFactors=FALSE)
independent <- list()
for(i in seq_len(nrow(table1))) {
  row <- table1[i,]; select <- domain
  if(row$hypertension_group=='No') select <- select & htn==0
  if(row$hypertension_group=='Yes') select <- select & htn==1
  vals <- labels[[row$variable]]; select <- select & !is.na(vals)
  num <- sum(select & vals==row$level,na.rm=TRUE); den <- sum(select)
  wp <- 100*sum(weight[select & vals==row$level],na.rm=TRUE)/sum(weight[select])
  independent[[i]] <- data.frame(variable=row$variable,level=row$level,hypertension_group=row$hypertension_group,
                               raw_n=num,raw_denominator=den,weighted_percent=wp,
                               raw_n_match=num==row$raw_n,denominator_match=den==row$raw_denominator,
                               weighted_percent_match=abs(wp-row$weighted_percent)<1e-9)
}
independent <- do.call(rbind,independent)
record('table1_all_counts_denominators_weighted_points',all(independent$raw_n_match & independent$denominator_match & independent$weighted_percent_match),list(rows=nrow(independent),failed=independent[!(independent$raw_n_match & independent$denominator_match & independent$weighted_percent_match),]))
write.csv(independent,file.path(out_dir,'independent_table1_points.csv'),row.names=FALSE)
report <- jsonlite::read_json(file.path(run_dir,'report.json'),simplifyVector=TRUE)
prevalence <- 100*sum(weight[domain]*htn[domain])/sum(weight[domain])
record('htn_weighted_point',abs(prevalence-report$htn_weighted_percent)<1e-9,prevalence)
record('reported_n_and_outcome_counts',sum(domain)==report$qa$analysis_n && sum(htn[domain])==report$qa$htn_raw_n && sum(htn[domain]==0)==report$qa$no_htn_raw_n,list(n=sum(domain),yes=sum(htn[domain]),no=sum(htn[domain]==0)))

design_data <- x[eligible,]; design_data$independent_domain <- domain[eligible]
design_data$w <- weight[eligible]
options(survey.lonely.psu='fail')
full_design <- survey::svydesign(id=~SDMVPSU,strata=~SDMVSTRA,weights=~w,nest=TRUE,data=design_data)
domain_design <- subset(full_design,independent_domain)
design_info <- list(full_mec_n=nrow(design_data),domain_n=sum(domain),full_df=survey::degf(full_design),
                    domain_df=survey::degf(domain_design),strata_n=length(unique(design_data$SDMVSTRA)),
                    psu_n=nrow(unique(design_data[c('SDMVSTRA','SDMVPSU')])) )
record('survey_design_counts_and_df',design_info$full_mec_n==report$survey_design$full_mec_n && design_info$domain_n==report$survey_design$domain_n && design_info$full_df==report$survey_design$full_design_df && design_info$domain_df==report$survey_design$domain_design_df && design_info$strata_n==report$survey_design$strata_n,design_info)

# BP0 sensitivity is a documented ambiguity, not evidence that a source record 0 is invalid.
positive_dbp <- dbp$matrix; positive_dbp[positive_dbp==0] <- NA_real_
alt_dbp <- rowMeans(positive_dbp,na.rm=TRUE)
all_zero <- dbp$n>0 & rowSums(dbp$matrix>0,na.rm=TRUE)==0
alt_dbp[all_zero] <- 0
alt_dbp[dbp$n==0] <- NA_real_
alt_measured <- ifelse(complete_bp,as.integer(sbp$mean>=140 | alt_dbp>=90),NA_integer_)
alt_htn <- htn; alt_no <- !is.na(alt_measured)&alt_measured==0 & !is.na(diagnosed)&diagnosed==0 & !is.na(med)&med==0
alt_yes <- (!is.na(alt_measured)&alt_measured==1) | (!is.na(diagnosed)&diagnosed==1) | (!is.na(med)&med==1)
alt_htn[] <- NA_integer_; alt_htn[alt_no]<-0L; alt_htn[alt_yes]<-1L
bp_sensitivity <- list(zero_dbp_any_all=sum(rowSums(dbp$matrix==0,na.rm=TRUE)>0),
                       zero_dbp_any_domain=sum(rowSums(dbp$matrix[domain,,drop=FALSE]==0,na.rm=TRUE)>0),
                       excluding_mixed_zero_measured_changes_in_domain=sum(measured[domain]!=alt_measured[domain],na.rm=TRUE),
                       excluding_mixed_zero_composite_changes_in_domain=sum(htn[domain]!=alt_htn[domain],na.rm=TRUE),
                       note='Alternate excludes zero only when positive DBP exists; does not implement first-reading exclusion.')

hashes <- read.csv(file.path(run_dir,'artifact_hashes.csv'),stringsAsFactors=FALSE)
for(file in c('derived/master.rds','report.json','definitions.json','executed_script.R','sources_manifest.csv')) {
  declared <- hashes$sha256[hashes$file==file]
  actual <- sha(file.path(run_dir,file))
  record(paste0('artifact_hash_',file),length(declared)==1L && identical(declared,actual),actual)
}
execution_sha <- sha(file.path(run_dir,'executed_script.R'))
current_source_sha <- sha(file.path(root,'analysis','src','run_analysis.R'))
record('source_matches_executed_snapshot',execution_sha==current_source_sha,list(executed=execution_sha,current=current_source_sha))

result <- list(role='Q-data',review_id='Q-DATA-R2-20261004',run_id='R2-20261004',
               reviewer_exposure=list(source_author=TRUE,published_targets_seen=TRUE,analysis_code_author=FALSE,
                                      statement='Independent agent instance; source author and target exposure disclosed. This is internal independent data QA, not external validation.'),
               exact_version=list(data_version=report$data_version,executed_script_sha256=execution_sha,
                                  current_source_sha256=current_source_sha,master_sha256=sha(file.path(run_dir,'derived','master.rds')),
                                  report_sha256=sha(file.path(run_dir,'report.json')),
                                  reviewer_script_sha256=sha(file.path(out_dir,'q_data_review.R'))),
               status=if(all(vapply(checks,function(c)c$passed,logical(1)))) 'accept' else 'needsrevision',
               scope='Core 5-component raw data reconstruction, source hashes, selected sample, BP/skip definitions, Table1 point values, MEC design IDs and degrees of freedom. Model inference and V checks intentionally not duplicated.',
               checks=checks,bp_sensitivity=bp_sensitivity,
               limitations=list('BP all-readings/mixed-zero averaging is a disclosed analyst choice; not the CDC reported-to-participant averaging rule.',
                                'Paper smoking variable undocumented; SMQ020 candidate must be described as lifetime >=100 cigarettes.',
                                'Original Table1 diabetes mapping has not been verified because DIQ is outside this core raw set.',
                                'Exact published Table1/2 numerical agreement is not required for this transparent candidate reconstruction.'))
jsonlite::write_json(result,file.path(out_dir,'review.json'),pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=16)
print(list(status=result$status,checks_n=length(checks),failed=vapply(checks[!vapply(checks,function(c)c$passed,logical(1))],function(c)c$id,character(1)),flow=flow,design=design_info,bp=bp_sensitivity,version=result$exact_version))
