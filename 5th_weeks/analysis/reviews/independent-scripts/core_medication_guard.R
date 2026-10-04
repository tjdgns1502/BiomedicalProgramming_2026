Sys.setlocale('LC_ALL','English_United States.utf8')
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L)
x <- readRDS(args[1])
special <- x$BPQ050A %in% c(7,9)
conflict <- special & x$medication_structural_no
print(list(raw7_or9_all=sum(special),raw7_or9_domain=sum(special&x$analysis_domain),
           reclassified_as_structural_no_all=sum(conflict),
           reclassified_as_structural_no_domain=sum(conflict&x$analysis_domain)))
