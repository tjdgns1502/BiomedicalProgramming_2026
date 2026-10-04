Sys.setlocale('LC_ALL','English_United States.utf8')
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
run_dir <- normalizePath(args[1],winslash='/',mustWork=TRUE)
out_dir <- normalizePath(args[2],winslash='/',mustWork=TRUE)
root <- normalizePath(file.path(run_dir,'..','..','..'),winslash='/',mustWork=TRUE)
.libPaths(c(file.path(root,'analysis','r-library'),.libPaths()))
stopifnot(requireNamespace('haven'),requireNamespace('jsonlite'),requireNamespace('digest'),requireNamespace('survey'))
status <- jsonlite::read_json(file.path(run_dir,'status.json'),simplifyVector=TRUE)
if(!identical(status$status,'success')) stop('Final Q-data decision requires a completed success run.')
sha <- function(p) digest::digest(file=p,algo='sha256',serialize=FALSE)
checks <- list()
check <- function(id,pass,evidence=NULL) checks[[length(checks)+1L]] <<- list(id=id,passed=isTRUE(pass),evidence=evidence)
same_num <- function(a,b) length(a)==length(b) && all((is.na(a)&is.na(b)) | (!is.na(a)&!is.na(b)&abs(a-b)<1e-10))
same_text <- function(a,b) identical(as.character(a),as.character(b))
report <- jsonlite::read_json(file.path(run_dir,'report.json'),simplifyVector=TRUE)
upstream <- jsonlite::read_json(file.path(run_dir,'upstream_input.json'),simplifyVector=TRUE)
core_dir <- file.path(root,'analysis','runs',upstream$run_id)
core <- readRDS(file.path(core_dir,'derived','master.rds'))
master <- readRDS(file.path(run_dir,'derived','master.rds'))
check('upstream_master_hash',sha(file.path(core_dir,'derived','master.rds'))==upstream$master_sha256)
check('upstream_report_hash',sha(file.path(core_dir,'report.json'))==upstream$report_sha256)
check('upstream_manifest_hash',sha(file.path(core_dir,'artifact_hashes.csv'))==upstream$artifact_manifest_sha256)
check('record_order_and_keys',identical(paste(core$cycle,core$SEQN),paste(master$cycle,master$SEQN)),nrow(core))
for(v in setdiff(names(core),'data_version')) check(paste0('unchanged_core_',v),identical(core[[v]],master[[v]]),v)
special_med_reclassified <- core$BPQ050A %in% c(7,9) & core$medication_structural_no
check('no_refused_unknown_medication_reclassified_as_structural_no',sum(special_med_reclassified)==0L,list(all_n=sum(special_med_reclassified),domain_n=sum(special_med_reclassified&core$analysis_domain),future_guard='구조적 건너뛰기는 raw BPQ050A가 실제 NA인 경우로 제한하면 미래 입력의 7/9 충돌에 강건함.'))
manifest <- read.csv(file.path(run_dir,'sources_manifest.csv'),stringsAsFactors=FALSE)
manifest$independent_sha256 <- vapply(manifest$file,sha,character(1))
manifest$hash_matches <- manifest$sha256==manifest$independent_sha256
check('all160_source_hashes',nrow(manifest)==160L && all(manifest$hash_matches),list(n=nrow(manifest),failed=manifest$file[!manifest$hash_matches]))
write.csv(manifest,file.path(out_dir,'source_hash_check.csv'),row.names=FALSE)
raw <- manifest[manifest$kind=='xpt',]
check('80_total_raw55_addon',nrow(raw)==80L && sum(!raw$component %in% c('DEMO','OHQ','BPX','BPQ','SMQ'))==55L,nrow(raw))
chosen <- list(BMX='BMXBMI',SLQ=c('SLD010H','SLD012'),
  ALQ=c('ALQ101','ALQ110','ALQ120Q','ALQ120U','ALQ111','ALQ121','ALQ130'),
  PAQ=c('PAQ605','PAQ620','PAQ635','PAQ650','PAQ665'),
  MCQ=c('MCQ160B','MCQ160C','MCQ160D','MCQ160E','MCQ160F'),DIQ='DIQ010',
  DR1TOT=c('WTDRD1','DR1DRSTZ','DR1TSODI','DR1TTFAT'),TCHOL='LBXTC',HDL='LBDHDD',GHB='LBXGH',BIOPRO=c('LBXSCR','LBXSTR'))
ind <- core[,c('cycle','cycle_start','SEQN','analysis_domain','hypertension_code','diagnosis_htn','medication_htn','SDMVSTRA','SDMVPSU','mec_weight','mec_design_eligible','smoking','age_group')]
for(v in unique(unlist(chosen))) ind[[v]] <- NA_real_
component_counts <- list(); raw_codes <- list(); diabetes_proxy <- list()
for(cycle in unique(ind$cycle)) for(component in names(chosen)) {
  f <- raw[raw$cycle==cycle & raw$component==component,]
  stopifnot(nrow(f)==1L)
  d <- as.data.frame(haven::read_xpt(f$file))
  check(paste0('addon_key_unique_',cycle,'_',component),!anyNA(d$SEQN)&&!anyDuplicated(d$SEQN),nrow(d))
  keep <- which(ind$cycle==cycle); m <- match(ind$SEQN[keep],as.numeric(d$SEQN))
  for(v in intersect(chosen[[component]],names(d))) ind[[v]][keep] <- as.numeric(d[[v]][m])
  component_counts[[length(component_counts)+1L]] <- data.frame(cycle=cycle,component=component,source_n=nrow(d),demo_n=length(keep),demo_matched_n=sum(!is.na(m)),absent_fields=paste(setdiff(chosen[[component]],names(d)),collapse='|'))
  if(component=='DIQ') for(v in intersect(c('DIQ010','DIQ050','DIQ070'),names(d))) for(group in c('All','No','Yes')) {
    select <- ind$analysis_domain[keep]
    if(group!='All') select <- select & ind$hypertension_code[keep]==as.integer(group=='Yes')
    vals <- as.numeric(d[[v]][m]); tab <- table(vals[select],useNA='always')
    diabetes_proxy[[length(diabetes_proxy)+1L]] <- data.frame(cycle=cycle,variable=v,hypertension_group=group,raw_code=names(tab),n=as.integer(tab))
  }
}
component_counts <- do.call(rbind,component_counts)
actual_counts <- read.csv(file.path(run_dir,'tables','addon_component_counts.csv'),stringsAsFactors=FALSE)
check('all55_component_counts_match',isTRUE(all.equal(component_counts,actual_counts,check.attributes=FALSE)),component_counts)
write.csv(component_counts,file.path(out_dir,'independent_component_counts.csv'),row.names=FALSE)
write.csv(do.call(rbind,diabetes_proxy),file.path(out_dir,'optional_diabetes_proxy_counts.csv'),row.names=FALSE)
for(v in unique(unlist(chosen))) check(paste0('addon_raw_',v),same_num(ind[[v]],as.numeric(master[[v]])),v)

# No implementation functions are sourced; derive independently from the joined raw values.
cat_missing <- function(x) { x[is.na(x)] <- 'Missing'; x }
bmi_cat <- cut(ind$BMXBMI,c(-Inf,18.5,25,30,Inf),right=FALSE,labels=c('<18.5','18.5-24.9','25-29.9','>=30'))
check('bmi_raw',same_num(ind$BMXBMI,master$bmi))
check('bmi_categories',same_text(cat_missing(as.character(bmi_cat)),master$bmi_category))
sleep <- ind$SLD010H; sleep[ind$cycle_start>=2015] <- ind$SLD012[ind$cycle_start>=2015]
sleep[!is.finite(sleep)|sleep<0|sleep>24] <- NA_real_
sleep_cat <- rep('Missing',nrow(ind)); sleep_cat[which(sleep<7)] <- '<7 hours'; sleep_cat[which(sleep>=7&sleep<=9)] <- '7-9 hours'; sleep_cat[which(sleep>9)] <- '>9 hours'
check('sleep_hours_fractional',same_num(sleep,master$sleep_hours))
check('sleep_category',same_text(sleep_cat,master$sleep_category))
fractional <- is.finite(sleep)&abs(sleep-round(sleep))>1e-12
sleep_summary <- do.call(rbind,lapply(unique(ind$cycle),function(c) data.frame(cycle=c,all_n=sum(ind$cycle==c),observed_n=sum(ind$cycle==c&!is.na(sleep)),fractional_n=sum(ind$cycle==c&fractional),primary_fractional_n=sum(ind$cycle==c&fractional&ind$analysis_domain))))
write.csv(sleep_summary,file.path(out_dir,'independent_sleep_counts.csv'),row.names=FALSE)

freq <- rep(NA_real_,nrow(ind)); early <- ind$cycle_start<2017; late <- !early
q <- ind$ALQ120Q; u <- ind$ALQ120U; amount <- ind$ALQ130
valid_q <- is.finite(q)&q>=0&q<=366
annual <- rep(NA_real_,nrow(ind)); annual[which(early&valid_q&u==1)] <- q[which(early&valid_q&u==1)]*365/7
annual[which(early&valid_q&u==2)] <- q[which(early&valid_q&u==2)]*12
annual[which(early&valid_q&u==3)] <- q[which(early&valid_q&u==3)]
map <- c(365,260,182,104,52,30,12,9,4.5,1.5)
for(i in 1:10) annual[which(late&ind$ALQ121==i)] <- map[i]
freq <- annual/(365/7)
amount[!is.finite(amount)|amount<1|(ind$cycle_start<=2013&amount>95)|(ind$cycle_start>=2015&amount>15)] <- NA_real_
none <- (early&valid_q&q==0)|(early&ind$ALQ101==2&ind$ALQ110==2)|(late&ind$ALQ121==0)|(late&ind$ALQ111==2)
none[is.na(none)] <- FALSE
weekly <- freq*amount; weekly[none] <- 0
alcohol_cat <- rep('Missing',nrow(ind)); alcohol_cat[which(weekly==0)] <- 'No drinks'; alcohol_cat[which(weekly>0&weekly<=1)] <- '<=1 drink/week'; alcohol_cat[which(weekly>1)] <- '>1 drink/week'
proxy <- early&ind$ALQ101==2&ind$ALQ110==2
check('alcohol_weekly_frequency',same_num(freq,master$alcohol_weekly_frequency))
check('alcohol_weekly_drinks',same_num(weekly,master$alcohol_weekly_drinks))
check('alcohol_category',same_text(alcohol_cat,master$alcohol_category))
check('alcohol_proxy_flag',identical(proxy,master$alcohol_lifetime_lt12_proxy))
group_binary <- function(vars,yes_label,no_label) {
  m <- as.matrix(ind[,vars]); y <- rowSums(m==1,na.rm=TRUE)>0; n <- rowSums(m==2,na.rm=TRUE)==length(vars)
  z <- rep('Missing',nrow(ind)); z[n] <- no_label; z[y] <- yes_label; z
}
activity <- group_binary(chosen$PAQ,'Active','Inactive'); cvd <- group_binary(chosen$MCQ,'Yes','No')
diabetes <- rep('Missing',nrow(ind)); diabetes[which(ind$DIQ010==1)] <- 'Yes'; diabetes[which(ind$DIQ010==2)] <- 'No'
check('activity_category',same_text(activity,master$activity_category))
check('cvd_category',same_text(cvd,master$cvd_category))
check('diabetes_category',same_text(diabetes,master$diabetes_category))
diabetes_status <- rep('Other',nrow(ind)); diabetes_status[is.na(ind$DIQ010)] <- 'Absent'
for(code in c(1,2,3,7,9)) diabetes_status[which(ind$DIQ010==code)] <- c('Yes','No','Borderline3','Refused7','Unknown9')[match(code,c(1,2,3,7,9))]
diabetes_summary <- do.call(rbind,lapply(c('All DEMO','Primary A'),function(p) {
  keep <- if(p=='All DEMO') rep(TRUE,nrow(ind)) else ind$analysis_domain
  lev <- c('Yes','No','Borderline3','Refused7','Unknown9','Absent','Other')
  data.frame(population=p,status=lev,n=as.integer(table(factor(diabetes_status[keep],levels=lev))))
}))
actual_diabetes <- read.csv(file.path(run_dir,'tables','diabetes_borderline_refused_unknown_counts.csv'),stringsAsFactors=FALSE)
check('diabetes_status_counts',isTRUE(all.equal(diabetes_summary,actual_diabetes,check.attributes=FALSE)),diabetes_summary)
write.csv(diabetes_summary,file.path(out_dir,'independent_diabetes_counts.csv'),row.names=FALSE)

continuous <- c(sodium='DR1TSODI',fat='DR1TTFAT',total_cholesterol='LBXTC',creatinine='LBXSCR',triglycerides_biopro='LBXSTR',hba1c='LBXGH',hdl='LBDHDD')
imputations <- list()
for(v in names(continuous)) {
  z <- ind[[continuous[[v]]]]; z[!is.finite(z)] <- NA_real_
  med <- median(z[ind$analysis_domain&!is.na(z)]); missing <- is.na(z); filled <- z; filled[missing] <- med
  check(paste0(v,'_raw'),same_num(z,master[[v]]))
  check(paste0(v,'_filled'),same_num(filled,master[[paste0(v,'_filled')]]))
  check(paste0(v,'_missing_flag'),identical(as.integer(missing),master[[paste0(v,'_missing')]]))
  imputations[[v]] <- data.frame(variable=v,raw_variable=continuous[[v]],median_value=med,observed_primary_n=sum(ind$analysis_domain&!missing),missing_primary_n=sum(ind$analysis_domain&missing))
}
imputations <- do.call(rbind,imputations); rownames(imputations)<-NULL
actual_imputations <- read.csv(file.path(run_dir,'tables','continuous_missing_indicators.csv'),stringsAsFactors=FALSE)
check('median_missing_summary',isTRUE(all.equal(imputations,actual_imputations[,names(imputations)],check.attributes=FALSE,tolerance=1e-12)),imputations)
write.csv(imputations,file.path(out_dir,'independent_median_missing_counts.csv'),row.names=FALSE)
weightB <- ind$WTDRD1/5; eligibleB <- is.finite(weightB)&weightB>0&is.finite(ind$SDMVSTRA)&is.finite(ind$SDMVPSU)
domainB <- ind$analysis_domain & !is.na(ind$DR1DRSTZ)&ind$DR1DRSTZ==1 & !is.na(ind$DR1TSODI)&!is.na(ind$DR1TTFAT)&eligibleB
check('diet_weight',same_num(weightB,master$diet_weight))
check('diet_eligible',identical(eligibleB,master$diet_design_eligible))
check('diet_domain',identical(domainB,master$dietary_sensitivity_domain))
options(survey.lonely.psu='fail')
design_summary <- list()
for(candidate in c('A','B')) {
  eligible <- if(candidate=='A') ind$mec_design_eligible else eligibleB
  domain <- if(candidate=='A') ind$analysis_domain else domainB
  d <- ind[eligible,]; d$w <- if(candidate=='A') d$mec_weight else weightB[eligible]; d$domain <- domain[eligible]
  full <- survey::svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~w,data=d,nest=TRUE); sub <- subset(full,domain)
  s <- list(full_n=nrow(d),domain_n=sum(domain),full_df=survey::degf(full),domain_df=survey::degf(sub),strata_n=length(unique(d$SDMVSTRA)),psu_n=nrow(unique(d[,c('SDMVSTRA','SDMVPSU')])))
  design_summary[[candidate]] <- s
  r <- report$candidates[[candidate]]
  check(paste0(candidate,'_design_n_df'),s$full_n==r$full_n && s$domain_n==r$domain_n && s$full_df==r$full_df && s$domain_df==r$domain_df,s)
}

# Independently check model row domains and covariate sets, without fitting models.
dx <- ind$diagnosis_htn; tx <- ind$medication_htn
dx_tx <- rep(NA_integer_,nrow(ind)); dx_tx[which(dx==0&tx==0)] <- 0L; dx_tx[which(dx==1|tx==1)] <- 1L
check('diagnosed_or_treated_outcome',same_num(dx_tx,master$diagnosed_or_treated_htn))
base <- c('age','sex','race','education'); four <- c('bmi_category','sleep_category','alcohol_category','activity_category')
labs <- unlist(lapply(c('total_cholesterol','creatinine','triglycerides_biopro','hba1c','hdl'),function(v) paste0(v,c('_filled','_missing'))))
rows <- read.csv(file.path(run_dir,'tables','model_sample_counts_formulas.csv'),stringsAsFactors=FALSE)
row_qa <- list()
for(i in seq_len(nrow(rows))) {
  r <- rows[i,]; domain <- if(r$candidate=='A') ind$analysis_domain else domainB
  outcome <- ind$hypertension_code
  if(r$family=='supplement_measured') { domain <- domain & !is.na(dx_tx)&dx_tx==0; outcome <- core$measured_htn }
  if(r$family=='supplement_diagnosed_treated') { domain <- domain & ((!is.na(dx_tx)&dx_tx==1)|ind$hypertension_code==0); outcome <- dx_tx }
  if(r$subgroup!='Overall') {
    group <- if(r$family=='table3') as.character(ind$age_group) else as.character(ind$smoking)
    domain <- domain & !is.na(group)&group==r$subgroup
  }
  domain <- domain & !is.na(outcome)
  cov <- if(r$family=='table3') setdiff(base,'age') else base
  if(r$model!='Model1') {
    cov <- c(cov,four)
    if(r$family=='table3') cov <- c(cov,'smoking')
    if(r$family=='table2') cov <- c(cov,'cvd_category','diabetes_category','sodium_filled','sodium_missing','fat_filled','fat_missing')
  }
  if(r$model=='Model3') cov <- c(cov,labs)
  formula_vars <- all.vars(as.formula(r$formula)); expected <- c(r$outcome,r$exposure,cov)
  n <- sum(domain); cases <- sum(outcome[domain]==1); controls <- sum(outcome[domain]==0)
  row_qa[[i]] <- data.frame(candidate=r$candidate,family=r$family,subgroup=r$subgroup,model=r$model,exposure=r$exposure,n=n,cases_n=cases,controls_n=controls,n_matches=n==r$n,cases_match=cases==r$cases_n,controls_match=controls==r$controls_n,covariates_match=setequal(formula_vars,expected))
}
row_qa <- do.call(rbind,row_qa)
check('all_model_domains_covariates',all(row_qa$n_matches&row_qa$cases_match&row_qa$controls_match&row_qa$covariates_match),list(rows=nrow(row_qa),failed=row_qa[!(row_qa$n_matches&row_qa$cases_match&row_qa$controls_match&row_qa$covariates_match),]))
write.csv(row_qa,file.path(out_dir,'independent_model_domains_covariates.csv'),row.names=FALSE)
supplement_summary <- unique(row_qa[row_qa$family %in% c('supplement_measured','supplement_diagnosed_treated'),c('candidate','family','subgroup','n','cases_n','controls_n')])
check('supplements_common_controls',length(unique(supplement_summary$controls_n))==1L && all(supplement_summary$controls_n==sum(ind$analysis_domain&ind$hypertension_code==0)),supplement_summary)
write.csv(supplement_summary,file.path(out_dir,'independent_supplement_domains.csv'),row.names=FALSE)

labels <- list(bmi_category=cat_missing(as.character(bmi_cat)),sleep_category=sleep_cat,alcohol_category=alcohol_cat,activity_category=activity,cvd_category=cvd,diabetes_category=diabetes)
point_rows <- list()
for(candidate in c('A','B')) {
  tab <- read.csv(file.path(run_dir,'tables',paste0(candidate,'_table1_categorical.csv')),stringsAsFactors=FALSE)
  tab <- tab[tab$variable %in% names(labels),]
  domain <- if(candidate=='A') ind$analysis_domain else domainB; weight <- if(candidate=='A') ind$mec_weight else weightB
  for(i in seq_len(nrow(tab))) {
    r <- tab[i,]; select <- domain
    if(r$hypertension_group!='All') select <- select & ind$hypertension_code==as.integer(r$hypertension_group=='Yes')
    v <- labels[[r$variable]]; den <- sum(select); num <- sum(select&v==r$level)
    wp <- 100*sum(weight[select&v==r$level])/sum(weight[select])
    point_rows[[length(point_rows)+1L]] <- data.frame(candidate=candidate,variable=r$variable,level=r$level,hypertension_group=r$hypertension_group,n=num,denominator=den,weighted_percent=wp,n_matches=num==r$raw_n,denominator_matches=den==r$raw_denominator,weighted_percent_matches=abs(wp-r$weighted_percent)<1e-9)
  }
}
point_rows <- do.call(rbind,point_rows)
check('addon_table1_count_denominator_weighted_point',all(point_rows$n_matches&point_rows$denominator_matches&point_rows$weighted_percent_matches),list(rows=nrow(point_rows),failed=point_rows[!(point_rows$n_matches&point_rows$denominator_matches&point_rows$weighted_percent_matches),]))
write.csv(point_rows,file.path(out_dir,'independent_addon_table1_points.csv'),row.names=FALSE)

artifacts <- read.csv(file.path(run_dir,'artifact_hashes.csv'),stringsAsFactors=FALSE)
for(f in c('definitions.json','derived/master.rds','report.json','executed_script.R','core_script_snapshot.R','sources_manifest.csv','upstream_input.json','tables/model_sample_counts_formulas.csv')) {
  declared <- artifacts$sha256[artifacts$file==f]; actual <- sha(file.path(run_dir,f))
  check(paste0('artifact_hash_',f),length(declared)==1L&&identical(declared,actual),actual)
}
executed <- sha(file.path(run_dir,'executed_script.R')); current <- sha(file.path(root,'analysis','src','extend_models.R'))
check('extension_current_matches_snapshot',executed==current)
check('core_snapshot_matches_R2',sha(file.path(run_dir,'core_script_snapshot.R'))==sha(file.path(core_dir,'executed_script.R')))
result <- list(role='Q-data',review_id='Q-DATA-E1-20261004',run_id='E1-20261004',
  status=if(all(vapply(checks,function(x)x$passed,logical(1)))) 'accept' else 'needsrevision',
  reviewer_exposure=list(source_author=TRUE,published_targets_seen=TRUE,analysis_code_author=FALSE,statement='내부 독립 자료 QA. 논문 출처 확보 및 목표 수치 노출을 공개하며 외부 검증을 주장하지 않음.'),
  exact_version=list(data_version=report$data_version,input_run=upstream$run_id,executed_script_sha256=executed,current_source_sha256=current,core_script_sha256=sha(file.path(run_dir,'core_script_snapshot.R')),master_sha256=sha(file.path(run_dir,'derived','master.rds')),report_sha256=sha(file.path(run_dir,'report.json')),reviewer_script_sha256=sha(file.path(out_dir,'q_extension_data_review.R'))),
  scope='55개 추가 원시 구성요소의 정의·단위·결측·선정·A/B 설계·Table1 점추정·모델별 공변량/분모·상류 불변성 및 해시 검산. 재적합 및 모델 수치 검토는 Q-stat 범위.',
  checks=checks,designs=design_summary,supplement_domains=supplement_summary,
  limitations=c('BIOPRO LBXSTR는 권고 참조법 LBXTR와 다르며 공복 제한 없는 후보임.',
    'BIOPRO_J의 이전 주기 통합 권고 보정식을 LBXSCR/LBXSTR에 적용하지 않은 원시값 후보임.',
    'ALQ_J 범주 대표값과 F-I 평생12잔미만을 No drinks로 간주하는 것은 명시된 분석자 가정임.',
    'SLD010H와 SLD012의 질문·산출 방식이 달라 통합 sleep을 완전히 동일한 측정으로 해석할 수 없음.',
    '중앙값+결측 지시자는 저자 구현 미상인 분석자 가정이며 편향 해결을 보장하지 않음.',
    '원 논문 Table1 diabetes 대규모 Missing의 변수 정의는 미확인. DIQ050/070 대조 요약은 탐색적 출처 단서이며 매핑 증명이 아님.',
    '보충표 domain은 발표된 수에서 추론한 후보 규칙. 저자 구현을 입증하지 않음.',
    'B WTDRD1 민감도는 일일 영양자료에 적합한 가중치를 사용하지만 모든 선택/측정/교란 편향을 해결하지 않음.'))
jsonlite::write_json(result,file.path(out_dir,'review.json'),pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=16)
print(list(status=result$status,checks_n=length(checks),failed=vapply(checks[!vapply(checks,function(x)x$passed,logical(1))],function(x)x$id,character(1)),designs=design_summary,sleep=sleep_summary,diabetes=diabetes_summary,imputation=imputations,supplement=supplement_summary,exact_version=result$exact_version))
