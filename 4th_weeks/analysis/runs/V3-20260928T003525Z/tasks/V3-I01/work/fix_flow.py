p='analysis/tasks/V3-I01/rev-1/work/descriptions.R'
s=open(p,encoding='utf-8').read()
a=s.index("flow<-read.csv");b=s.index("if(file.exists(file.path(out,'curve_data.csv')))")
s=s[:a]+'''flow<-read.csv(file.path(out,'flow_counts.csv'));png(file.path(out,'Figure1_flow.png'),1500,1100,res=150);par(mar=c(1,1,3,1));plot.new();plot.window(xlim=c(0,1),ylim=c(0,1));title('Candidate cohort flow (not author-identical)');coords<-data.frame(stage=c('all_age_parent','age50_input','route36','reference','model2','supplement','diet','strict36'),x=c(.5,.5,.5,.5,.5,.25,.75,.16),y=c(.92,.80,.65,.51,.37,.20,.20,.65));for(j in seq_len(nrow(coords))){cx<-coords$x[j];cy<-coords$y[j];n<-flow$n[match(coords$stage[j],flow$stage)];rect(cx-.16,cy-.035,cx+.16,cy+.035,col='#E5F0F6',border='#204864');text(cx,cy,paste(coords$stage[j],format(n,big.mark=','),sep=': '),cex=.85)};for(j in 1:4)arrows(.5,coords$y[j]-.04,.5,coords$y[j+1]+.04,length=.06);arrows(.5,.33,.25,.24,length=.06);arrows(.5,.33,.75,.24,length=.06);arrows(.34,.78,.16,.69,length=.06);text(.16,.58,'Original strict sensitivity',cex=.8);text(.75,.11,'Separate WTDR2D/7 parent',cex=.8);dev.off()
''' +s[b:]
open(p,'w',encoding='utf-8').write(s)
