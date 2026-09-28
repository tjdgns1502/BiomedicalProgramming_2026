suppressPackageStartupMessages(library(foreign))
spec <- list(
 list(path='2015-2016/DEMO_I.xpt',vars=c('WTMEC2YR','WTINT2YR','SDMVSTRA','SDMVPSU')),
 list(path='2015-2016/CBC_I.xpt',vars=c('LBDLYMNO','LBDMONO','LBDNENO','LBXPLTSI','LBXRDW')),
 list(path='2015-2016/BPX_I.xpt',vars=c('BPXPLS','BPXSY1','BPXSY2','BPXSY3','BPXSY4','BPXDI1','BPXDI2','BPXDI3','BPXDI4')),
 list(path='2015-2016/HUQ_I.xpt',vars=c('HUQ051','HUQ071')),
 list(path='1999-2000/DEMO.xpt',vars=c('WTMEC2YR','WTMEC4YR','SDMVSTRA','SDMVPSU')),
 list(path='2001-2002/L40_B.xpt',vars=c('LBDSLDSI','LBDSAPSI','LBXSBU','LBDSCASI','LBDSUASI'))
)
results <- list()
for (entry in spec) {
 d <- read.xport(file.path('analysis/data/raw', entry$path))
 for (v in entry$vars) results[[length(results)+1L]] <- data.frame(file=entry$path,SEQN=d$SEQN,variable=v,r_value=d[[v]])
}
write.csv(do.call(rbind,results),'analysis/runs/S02-nhanes-data/r_xpt_reference_values.csv',row.names=FALSE,na='')
cat('R foreign version',as.character(packageVersion('foreign')), 'reference values written\n')
