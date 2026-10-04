Sys.setlocale("LC_ALL", "English_United States.utf8")
args <- commandArgs(trailingOnly=TRUE)
run <- args[1]
out <- args[2]
dir.create(out, recursive=TRUE, showWarnings=FALSE)
checks <- list()
add <- function(name, ok, detail="") checks[[length(checks)+1L]] <<- data.frame(check=name, pass=ok, detail=detail)
near <- function(x,y,tol=1e-11) all(is.finite(x)) && all(is.finite(y)) && max(abs(x-y)) <= tol
two_sided_fisher <- function(x,y,n) {
  s <- x+y
  possible <- max(0,s-n):min(n,s)
  mass <- choose(s,possible)*choose(2*n-s,n-possible)/choose(2*n,n)
  observed <- choose(s,x)*choose(2*n-s,n-x)/choose(2*n,n)
  min(1,sum(mass[mass <= observed*(1+1e-7)]))
}
two_tests <- function(x,y,n) {
  s <- x+y
  if(s==0 || s==2*n) return(c(Fisher=1,Pearson=1,Yates=1))
  c(Fisher=two_sided_fisher(x,y,n),
    Pearson=pchisq(2*n*(x-y)^2/(s*(2*n-s)),1,lower.tail=FALSE),
    Yates=pchisq(2*n*max(abs(x-y)-1,0)^2/(s*(2*n-s)),1,lower.tail=FALSE))
}
binomial_mass <- function(x,n,p) choose(n,x)*p^x*(1-p)^(n-x)
wilson_independent <- function(k,N) {
  z2 <- qnorm(.975)^2
  center <- (k+z2/2)/(N+z2)
  radius <- sqrt(z2)*(sqrt(k*(1-k/N)+z2/4))/(N+z2)
  c(center-radius,center+radius)
}
size <- read.csv(file.path(run,"typeI_error.csv"))
power <- read.csv(file.path(run,"power.csv"))
set.seed(20261004)
for(n in c(5,10,20,50)) {
  e <- read.csv(file.path(run,paste0("enumeration_n",n,".csv")))
  expected <- t(vapply(seq_len(nrow(e)),function(i) two_tests(e$x1[i],e$x0[i],n),numeric(3)))
  add(paste0("complete_states_n",n),nrow(e)==(n+1)^2 && !anyDuplicated(e[,c("x1","x0")]) && all(e$x1 %in% 0:n) && all(e$x0 %in% 0:n))
  add(paste0("p_values_independent_n",n),near(as.matrix(e[,c("Fisher","Pearson","Yates")]),expected),paste("max error",max(abs(as.matrix(e[,c("Fisher","Pearson","Yates")])-expected))))
  for(p in c(.05,.2,.5)) {
    mass <- binomial_mass(e$x1,n,p)*binomial_mass(e$x0,n,p)
    add(paste0("null_mass_n",n,"_p",p),near(sum(mass),1))
    xs <- rbinom(10000,n,p); ys <- rbinom(10000,n,p)
    ids <- match(paste(xs,ys),paste(e$x1,e$x0))
    z <- size[size$n_per_group==n & size$null_p==p,]
    for(test in c("Fisher","Pearson","Yates")) {
      row <- z[z$test==test,]
      exact <- sum(mass[expected[,test]<.05])
      k <- sum(expected[ids,test]<.05)
      ci <- wilson_independent(k,10000)
      add(paste0("size_",test,"_n",n,"_p",p),near(row$exact_typeI,exact) && row$rejections==k && near(row$MC_typeI,k/10000) && near(c(row$MC_low,row$MC_high),ci) && near(row$MCSE,sqrt(k/10000*(1-k/10000)/10000)))
    }
  }
  mass <- binomial_mass(e$x1,n,.35)*binomial_mass(e$x0,n,.2)
  add(paste0("alternative_mass_n",n),near(sum(mass),1))
  xs <- rbinom(10000,n,.35); ys <- rbinom(10000,n,.2)
  ids <- match(paste(xs,ys),paste(e$x1,e$x0))
  z <- power[power$n_per_group==n,]
  for(test in c("Fisher","Pearson","Yates")) {
    row <- z[z$test==test,]
    exact <- sum(mass[expected[,test]<.05]); k <- sum(expected[ids,test]<.05)
    add(paste0("power_",test,"_n",n),near(row$exact_power,exact) && near(row$MC_power,k/10000) && near(c(row$MC_low,row$MC_high),wilson_independent(k,10000)) && near(row$MCSE,sqrt(k/10000*(1-k/10000)/10000)))
  }
}
conditional <- read.csv(file.path(run,"conditional_fisher.csv"))
mass <- choose(10,0:10)*choose(10,10:0)/choose(20,10)
pv <- vapply(0:10,function(x) two_sided_fisher(x,10-x,10),numeric(1))
add("conditional_mass",near(sum(conditional$probability),1) && near(conditional$probability,mass))
add("conditional_probability_ordering",near(conditional$p_value,pv) && identical(conditional$reject,pv<.05))
examples <- read.csv(file.path(run,"course_examples.csv"))
paired_exact <- 2*sum(choose(30,0:5)*.5^30)
add("paired_exact",near(examples$p_value[3],paired_exact))
add("paired_Yates",near(examples$statistic[4],(abs(25-5)-1)^2/(25+5)) && near(examples$p_value[4],pchisq((20-1)^2/30,1,lower.tail=FALSE)))
add("course_fisher",near(examples$p_value[1],two_sided_fisher(8,2,10)))
add("course_pearson",near(examples$statistic[2],100/3) && near(examples$p_value[2],pchisq(100/3,2,lower.tail=FALSE)))
effect <- read.csv(file.path(run,"published_OR_PR.csv"))
a<-2178;b<-1905;c<-8839;d<-8878
p1<-a/(a+b);p0<-c/(c+d);OR<-(p1/(1-p1))/(p0/(1-p0));PR<-p1/p0
add("OR_PR_formula",near(effect$crude_OR,OR) && near(effect$crude_PR,PR) && near(OR/PR,(1-p0)/(1-p1)))
add("effect_CI",near(c(effect$OR_low,effect$OR_high),exp(log(OR)+c(-1,1)*qnorm(.975)*sqrt(1/a+1/b+1/c+1/d))) && near(c(effect$PR_low,effect$PR_high),exp(log(PR)+c(-1,1)*qnorm(.975)*sqrt((1-p1)/a+(1-p0)/c))))
curve <- read.csv(file.path(run,"baseline_OR_PR_curve.csv"))
add("curve_domain_and_formula",all(curve$p0>0 & curve$p0<1 & curve$p1>0 & curve$p1<1) && near(curve$p1,curve$p0*curve$PR) && near(curve$OR,(curve$p1/(1-curve$p1))/(curve$p0/(1-curve$p0)),1e-9) && near(curve$relative_overstatement_pct,100*(curve$OR/curve$PR-1),1e-9))
result <- do.call(rbind,checks)
write.csv(result,file.path(out,"V1_independent_checks.csv"),row.names=FALSE)
print(result)
cat("ALL_PASS",all(result$pass),"CHECKS",nrow(result),"CONDITIONAL_ERROR",format(sum(mass[pv<.05]),digits=16),"\n")
if(!all(result$pass)) quit(status=1)
