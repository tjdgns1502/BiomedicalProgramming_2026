# Verified source correction before revised execution

1999–2000 DRXTOT.htm uses **DRDDRSTS**, not DRDDRSTZ, for recall reliability. Code1 is reliable and meets minimum criteria. Extract DRDDRSTS from existing DRXTOT.xpt using SEQN; it was omitted from the earlier broad derived dataset. 2001–2002 uses DRDDRSTZ; 2003+ uses DR1DRSTZ/DR2DRSTZ.

Official source: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/DRXTOT.htm#DRDDRSTS ; local analysis/data/raw/1999-2000/DRXTOT.htm, heading DRDDRSTS and dietary quality discussion.

Initial V3 dictionary gave zero usable energy for1999 because it looked at a variable absent in that cycle. Do not accept this as actual absence of dietary data. Preserve affected initial results as superseded, then regenerate derivatives/domains/models under corrected alias. This is a source-mapping correction, not tuning to publication numbers or significance.

Separately drop **unused factor levels** within each model's domain before building the model matrix, recording the absent levels. Preserve all estimable terms and the same factor reference for observed levels; do not drop nonconstant aliased terms. Zero columns for unsampled cycles are software representation artifacts, not scientific nonidentifiability.
