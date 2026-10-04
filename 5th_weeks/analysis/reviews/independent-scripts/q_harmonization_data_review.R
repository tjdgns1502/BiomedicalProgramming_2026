# E2 전용 결과 폴더를 사용하여 E1 검토 기록을 보존한다.
Sys.setlocale('LC_ALL','English_United States.utf8')
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
run_dir <- normalizePath(args[1],winslash='/',mustWork=TRUE)
out_dir <- normalizePath(args[2],winslash='/',mustWork=TRUE)
root <- normalizePath(file.path(run_dir,'..','..','..'),winslash='/',mustWork=TRUE)
.libPaths(c(file.path(root,'analysis','r-library'),.libPaths()))
stopifnot(requireNamespace('jsonlite'),requireNamespace('digest'))
status <- jsonlite::read_json(file.path(run_dir,'status.json'),simplifyVector=TRUE)
if(!identical(status$status,'success')) stop('E2 최종 판정에는 완료된 success 실행이 필요함.')
sha <- function(p) digest::digest(file=p,algo='sha256',serialize=FALSE)
checks <- list()
check <- function(id,pass,evidence=NULL) checks[[length(checks)+1L]] <<- list(id=id,passed=isTRUE(pass),evidence=evidence)
same_num <- function(a,b) length(a)==length(b) && all((is.na(a)&is.na(b))|(!is.na(a)&!is.na(b)&abs(a-b)<1e-10))
report <- jsonlite::read_json(file.path(run_dir,'report.json'),simplifyVector=TRUE)
upstream <- jsonlite::read_json(file.path(run_dir,'upstream_input.json'),simplifyVector=TRUE)
old_dir <- file.path(root,'analysis','runs',upstream$input_extended_run)
old_report <- jsonlite::read_json(file.path(old_dir,'report.json'),simplifyVector=TRUE)
old <- readRDS(file.path(old_dir,'derived','master.rds'))
x <- readRDS(file.path(run_dir,'derived','master.rds'))
check('upstream_E1_master_hash',sha(file.path(old_dir,'derived','master.rds'))==upstream$master_sha256)
check('upstream_E1_report_hash',sha(file.path(old_dir,'report.json'))==upstream$report_sha256)
check('upstream_E1_manifest_hash',sha(file.path(old_dir,'artifact_hashes.csv'))==upstream$artifact_manifest_sha256)
check('same_participant_order',identical(paste(old$cycle,old$SEQN),paste(x$cycle,x$SEQN)))
changed <- c('creatinine','triglycerides_biopro')
allowed <- c('data_version',changed,paste0(changed,'_filled'),paste0(changed,'_missing'))
for(v in setdiff(names(old),allowed)) check(paste0('unaffected_',v),identical(old[[v]],x[[v]]),v)
late <- old$cycle_start==2017
expected <- list(creatinine=as.numeric(old$LBXSCR),triglycerides_biopro=as.numeric(old$LBXSTR))
expected$creatinine[late] <- expected$creatinine[late]*1.051-.06945
expected$triglycerides_biopro[late] <- expected$triglycerides_biopro[late]*.9655-7.020
summaries <- list(); imputations <- list()
for(v in changed) {
  before <- old[[v]]; after <- expected[[v]]
  check(paste0(v,'_equation'),same_num(after,x[[v]]))
  check(paste0(v,'_preJ_unchanged'),identical(before[!late],x[[v]][!late]))
  check(paste0(v,'_assay_raw_preserved'),same_num(before,x[[paste0(v,'_assay_raw')]]))
  check(paste0(v,'_before_harmonization_preserved'),identical(before,x[[paste0(v,'_before_harmonization')]]))
  flag <- late&!is.na(before)
  flag_col <- if(v=='creatinine') 'creatinine_backward_harmonized_J' else 'triglycerides_backward_harmonized_J'
  check(paste0(v,'_J_flag'),identical(flag,x[[flag_col]]))
  missing <- is.na(after); med <- median(after[x$analysis_domain&!missing]); filled <- after; filled[missing]<-med
  check(paste0(v,'_new_median_fill'),same_num(filled,x[[paste0(v,'_filled')]]))
  check(paste0(v,'_missing_flag_preserved'),identical(old[[paste0(v,'_missing')]],x[[paste0(v,'_missing')]]) && identical(as.integer(missing),x[[paste0(v,'_missing')]]))
  check(paste0(v,'_positive_observed'),all(after[!missing]>0),min(after,na.rm=TRUE))
  imputations[[v]] <- data.frame(variable=v,raw_variable=if(v=='creatinine')'LBXSCR'else'LBXSTR',median_value=med,observed_primary_n=sum(x$analysis_domain&!missing),missing_primary_n=sum(x$analysis_domain&missing),E1_median=median(before[x$analysis_domain&!is.na(before)]))
  for(cycle in unique(old$cycle)) {
    keep <- old$cycle==cycle
    summaries[[length(summaries)+1L]] <- data.frame(variable=v,cycle=cycle,all_n=sum(keep),observed_n=sum(keep&!missing),changed_n=sum(keep&before!=after,na.rm=TRUE),primary_changed_n=sum(keep&x$analysis_domain&before!=after,na.rm=TRUE),mean_before=mean(before[keep],na.rm=TRUE),mean_after=mean(after[keep],na.rm=TRUE),median_before=median(before[keep],na.rm=TRUE),median_after=median(after[keep],na.rm=TRUE),min_after=min(after[keep],na.rm=TRUE),max_after=max(after[keep],na.rm=TRUE))
  }
}
summaries <- do.call(rbind,summaries); imputations<-do.call(rbind,imputations); rownames(imputations)<-NULL
write.csv(summaries,file.path(out_dir,'independent_harmonization_counts.csv'),row.names=FALSE)
write.csv(imputations,file.path(out_dir,'independent_median_missing_counts.csv'),row.names=FALSE)
actual_imputations <- read.csv(file.path(run_dir,'tables','continuous_missing_indicators.csv'),stringsAsFactors=FALSE)
for(i in seq_len(nrow(imputations))) {
  r <- imputations[i,]; a <- actual_imputations[actual_imputations$variable==r$variable,]
  check(paste0('imputation_summary_',r$variable),nrow(a)==1L && same_num(r$median_value,a$median_value) && r$observed_primary_n==a$observed_primary_n && r$missing_primary_n==a$missing_primary_n)
}
manifest <- read.csv(file.path(run_dir,'sources_manifest.csv'),stringsAsFactors=FALSE)
manifest$independent_sha256 <- vapply(manifest$file,sha,character(1)); manifest$hash_matches <- manifest$sha256==manifest$independent_sha256
check('all160_immutable_source_hashes',nrow(manifest)==160L && all(manifest$hash_matches),list(n=nrow(manifest),failed=manifest$file[!manifest$hash_matches]))
check('sources_manifest_identical_E1',sha(file.path(run_dir,'sources_manifest.csv'))==sha(file.path(old_dir,'sources_manifest.csv')))
write.csv(manifest,file.path(out_dir,'source_hash_check.csv'),row.names=FALSE)
check('frozen_core_snapshot',sha(file.path(run_dir,'core_script_snapshot.R'))==sha(file.path(old_dir,'core_script_snapshot.R')))
check('frozen_E1_extension_snapshot',sha(file.path(run_dir,'extended_script_snapshot.R'))==sha(file.path(old_dir,'executed_script.R')))
check('copied_plan_hash',sha(file.path(run_dir,'plan-v1.5.json'))==upstream$plan_sha256)
signature <- paste(upstream$master_sha256,old_report$data_version,upstream$plan_sha256,'2017:creatinine=1.051*LBXSCR-0.06945;TG=0.9655*LBXSTR-7.020;before-median',sep='|')
expected_version <- paste0('nhanes-2009-2018-harmonizedJ-',substr(digest::digest(signature,algo='sha256',serialize=FALSE),1,20))
check('new_version_bound_to_E1_plan_equations',expected_version==report$data_version && report$data_version!=old_report$data_version && identical(unique(x$data_version),report$data_version),expected_version)

deps <- read.csv(file.path(run_dir,'artifact_dependencies.csv'),stringsAsFactors=FALSE)
reused <- deps[deps$disposition=='copied_unaffected',]
reuse_checks <- lapply(seq_len(nrow(reused)),function(i) {
  r <- reused[i,]; old_sha<-sha(file.path(old_dir,r$source_file)); new_sha<-sha(file.path(run_dir,r$artifact))
  data.frame(artifact=r$artifact,source_file=r$source_file,source_run=r$source_run,old_sha256=old_sha,new_sha256=new_sha,hash_matches=old_sha==new_sha&&old_sha==r$source_sha256,provenance_matches=r$source_run==upstream$input_extended_run&&r$source_data_version==old_report$data_version&&r$effective_data_version==report$data_version)
})
reuse_checks<-do.call(rbind,reuse_checks)
check('all_copied_unaffected_hash_and_provenance',all(reuse_checks$hash_matches&reuse_checks$provenance_matches),list(n=nrow(reuse_checks)))
check('no_copied_Model3_or_interactions',!any(grepl('_Model3_|_interaction_',reused$artifact)))
write.csv(reuse_checks,file.path(out_dir,'independent_reuse_hashes.csv'),row.names=FALSE)
key <- function(d,vars) do.call(paste,c(d[,vars,drop=FALSE],sep='|'))
for(file in c('all_model_coefficients.csv','model_sample_counts_formulas.csv','oral_trend_tests.csv')) {
  a <- read.csv(file.path(old_dir,'tables',file),stringsAsFactors=FALSE)
  b <- read.csv(file.path(run_dir,'tables',file),stringsAsFactors=FALSE)
  keys <- intersect(c('candidate','family','subgroup','model','exposure','outcome','term'),names(a))
  j <- match(key(b,keys),key(a,keys)); keep <- b$model %in% c('Model1','Model2')
  check(paste0('all_model_keys_',file),nrow(a)==nrow(b)&&!anyNA(j)&&!anyDuplicated(key(b,keys)))
  check(paste0('M1_M2_values_reused_',file),isTRUE(all.equal(b[keep,names(a),drop=FALSE],a[j[keep],,drop=FALSE],check.attributes=FALSE,tolerance=1e-12)))
  provenance_ok <- b$effective_data_version==report$data_version & ifelse(keep,b$provenance_run==upstream$input_extended_run & b$source_data_version==old_report$data_version & b$calculation_status=='reused_unaffected_Model1_or_Model2',b$provenance_run==report$run_id & b$source_data_version==report$data_version & b$calculation_status=='recomputed_harmonized_J')
  check(paste0('every_row_current_provenance_',file),all(provenance_ok))
  if(file=='model_sample_counts_formulas.csv') check('all_model_denominators_formulas_unchanged',isTRUE(all.equal(b[,names(a)],a[j,,drop=FALSE],check.attributes=FALSE,tolerance=1e-12)))
}
lean_files <- list.files(file.path(run_dir,'models'),pattern='_lean\\.rds$',full.names=TRUE)
lean_versions <- lapply(lean_files,function(f) {
  d <- readRDS(f); name<-basename(f); reused <- grepl('_Model[12]_',name)
  data.frame(file=name,expected_source=if(reused)upstream$input_extended_run else report$run_id,data_version=d$data_version,version_matches=d$data_version==if(reused)old_report$data_version else report$data_version)
})
lean_versions<-do.call(rbind,lean_versions)
check('every_lean_model_data_version',all(lean_versions$version_matches),list(n=nrow(lean_versions),failed=lean_versions[!lean_versions$version_matches,]))
write.csv(lean_versions,file.path(out_dir,'independent_lean_model_versions.csv'),row.names=FALSE)
for(file in c('interaction_joint_wald.csv','interaction_coefficients.csv')) {
  t <- read.csv(file.path(run_dir,'tables',file),stringsAsFactors=FALSE)
  check(paste0('all_interactions_new_version_',file),all(t$provenance_run==report$run_id & t$calculation_status=='recomputed_harmonized_J' & t$effective_data_version==report$data_version))
}

points <- list()
for(candidate in c('A','B')) {
  table_file <- paste0(candidate,'_table1_continuous.csv')
  a <- read.csv(file.path(old_dir,'tables',table_file),stringsAsFactors=FALSE)
  b <- read.csv(file.path(run_dir,'tables',table_file),stringsAsFactors=FALSE)
  j <- match(key(b,c('variable','hypertension_group')),key(a,c('variable','hypertension_group')))
  unchanged <- !b$variable %in% changed
  check(paste0(candidate,'_Table1_unchanged_rows'),!anyNA(j)&&isTRUE(all.equal(b[unchanged,names(a),drop=FALSE],a[j[unchanged],,drop=FALSE],check.attributes=FALSE,tolerance=1e-12)))
  for(i in which(!unchanged)) {
    r <- b[i,]; select <- if(candidate=='A') x$analysis_domain else x$dietary_sensitivity_domain
    if(r$hypertension_group!='All') select <- select & x$hypertension_code==as.integer(r$hypertension_group=='Yes')
    vals <- expected[[r$variable]]; select <- select&!is.na(vals)
    w <- if(candidate=='A')x$mec_weight else x$diet_weight
    mu <- sum(w[select]*vals[select])/sum(w[select])
    points[[length(points)+1L]] <- data.frame(candidate=candidate,variable=r$variable,hypertension_group=r$hypertension_group,observed_n=sum(select),raw_mean=mean(vals[select]),weighted_mean=mu,n_matches=sum(select)==r$raw_n,raw_mean_matches=abs(mean(vals[select])-r$raw_mean)<1e-10,weighted_mean_matches=abs(mu-r$weighted_mean)<1e-10)
  }
}
points<-do.call(rbind,points)
check('all_changed_Table1_n_raw_and_weighted_means',all(points$n_matches&points$raw_mean_matches&points$weighted_mean_matches),points)
write.csv(points,file.path(out_dir,'independent_changed_table1_points.csv'),row.names=FALSE)
table1_provenance <- read.csv(file.path(run_dir,'tables','table1_row_provenance.csv'),stringsAsFactors=FALSE)
changed_rows <- table1_provenance$variable %in% changed
check('Table1_every_row_provenance',all(table1_provenance$effective_data_version==report$data_version & ifelse(changed_rows,table1_provenance$calculation_status=='recomputed_harmonized_J' & table1_provenance$source_run==report$run_id,table1_provenance$calculation_status=='reused_unaffected' & table1_provenance$source_run==upstream$input_extended_run)))
for(f in unique(table1_provenance$original_source_file)) check(paste0('Table1_original_source_hash_',f),all(table1_provenance$original_source_sha256[table1_provenance$original_source_file==f]==sha(file.path(old_dir,f))))
artifacts <- read.csv(file.path(run_dir,'artifact_hashes.csv'),stringsAsFactors=FALSE)
for(f in c('derived/master.rds','report.json','definitions.json','executed_script.R','core_script_snapshot.R','extended_script_snapshot.R','sources_manifest.csv','upstream_input.json','artifact_dependencies.csv','plan-v1.5.json','tables/model_row_provenance.csv','tables/table1_row_provenance.csv')) {
  declared<-artifacts$sha256[artifacts$file==f]; actual<-sha(file.path(run_dir,f))
  check(paste0('artifact_hash_',f),length(declared)==1L&&identical(declared,actual),actual)
}
executed<-sha(file.path(run_dir,'executed_script.R')); current<-sha(file.path(root,'analysis','src','repair_harmonization.R'))
check('repair_current_matches_execution_snapshot',executed==current)
result <- list(role='Q-data',review_id='Q-DATA-E2-20261004',run_id=report$run_id,
  status=if(all(vapply(checks,function(c)c$passed,logical(1)))) 'accept' else 'needsrevision',
  reviewer_exposure=list(source_author=TRUE,published_targets_seen=TRUE,analysis_code_author=FALSE,statement='내부 독립 자료 검토. 원시 E1을 별도로 검증한 인스턴스이며, 원문 목표 수치 노출 및 출처 작성 역할을 공개함. 외부 검증을 주장하지 않음.'),
  exact_version=list(data_version=report$data_version,upstream_data_version=old_report$data_version,upstream_master_sha256=upstream$master_sha256,executed_script_sha256=executed,current_source_sha256=current,master_sha256=sha(file.path(run_dir,'derived','master.rds')),report_sha256=sha(file.path(run_dir,'report.json')),reviewer_script_sha256=sha(file.path(out_dir,'q_harmonization_data_review.R'))),
  scope='검증된 E1에서 J 전용 CDC 역방향 변환·원값 보존·변환 뒤 중앙값/flag·상류/domain 불변성·재사용 출처·Model3/추세/상호작용 자료버전·Table1 평균 및 해시를 독립 검산. 모델 재적합/추론 수치 검토는 Q-stat 범위.',
  decision=list(value=if(all(vapply(checks,function(c)c$passed,logical(1)))) 'accept' else 'needsrevision',accepted_scope='명시된 E1 기반 부분 검사 조화 후보의 자료 정의·변환·연계·점추정 검산',excluded_scope='모델 추론 수치, 원 논문의 정확한 복제, 비공복 TG의 참조법 동등성, 모든 편향 해결은 이 자료 판정 범위 밖'),
  checks=checks,independent_imputation=imputations,independent_harmonization=summaries,
  limitations=c('주기 간 BIOPRO 척도 조화는 권고된 부분 보정이며, 비공복 LBXSTR가 참조법 공복 LBXTR가 되는 것은 아님.',
    '저자의 실제 당뇨·음주·흡연·결측·보충표 구현 및 원문 숫자의 정확한 재현은 여전히 미확인.',
    'E1에서 복사한 범주형 검정의 희소 셀 경고가 해결된 것은 아님. E2 warnings_n은 이번 repair에서 발생한 경고 수.',
    '채움 중앙값/결측 지시자는 명시된 분석자 가정이며 선택·교란·측정 편향을 모두 제거하지 않음.'))
jsonlite::write_json(result,file.path(out_dir,'review.json'),pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=16)
print(list(status=result$status,checks_n=length(checks),failed=vapply(checks[!vapply(checks,function(c)c$passed,logical(1))],function(c)c$id,character(1)),imputation=imputations,harmonization=summaries,exact_version=result$exact_version))
