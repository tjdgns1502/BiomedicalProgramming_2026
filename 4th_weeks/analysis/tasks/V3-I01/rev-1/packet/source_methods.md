# V3-P01 source audit (2026-09-28)

Scope: source audit only; no fitting, count matching, or inferred author code. Previous published results were visible. Existing extractions and references22/23 were rechecked, official NHANES codebooks added. PDF skill used for visual inspection of p8.

## Actionable discovery: PFQ structural skip (all nine cycles checked)

Official PFQ059A check item explicitly skips the functional battery to PFQ090 when age<=59 and three screening items are all code2 (No). This is documented routing, not ordinary missingness. A candidate binary deficit reconstruction may infer zero for missing functional items on this precisely identified path because PFQ059 explicitly denies any activity limitation due to a physical, mental, or emotional problem. This remains a reconstruction of a screen-negative response, not a directly answered item or verified Han implementation. Keep a provenance flag and retain the original NA.

- 1999–2000 and 2001–2002: age<=59, PFQ048=2, PFQ056=2, PFQ059=2. Functional prefix PFQ060.
- 2003–2004 through 2015–2016: age<=59, PFQ049=2, PFQ057=2, PFQ059=2. Functional prefix PFQ061.
- Nine Han function suffixes: A (money), D (stoop), E (lift), H (rooms), I (chair), J (bed), L (dress), P (small objects), R (social events).
- Conservative implementation: infer only when the target is system missing, age50–59, all three explicit negatives hold, and no earlier routing item says1. Earlier routing check PFQ058 uses048/050/055/056 in1999–2002 and049/051/054/057 thereafter. For1999–2002,050/055 may be skipped after048=2 and need not be observed2. In2003+ require051 and054 observed2 for strict route confirmation; contradictory/unknown cases remain missing.
- Never infer for age>=60, code7/9 refusal/unknown, code5 do-not-do, missing screen items, or isolated target missingness without this exact route. Code5 is not shown in1999 functional codebook, but is present in later cycles.
- This is evidence supporting a distinct screen-negative reconstruction sensitivity. It does not make existing complete36 wrong for its declared definition, but explains why complete36 can select50–59-year-olds with limitations.

All nine official codebooks are saved here as PFQ.html, PFQ_B.html,...,PFQ_I.html. URLs follow https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/{year}/DataFiles/{file}.htm with year/file pairs1999/PFQ,2001/PFQ_B,2003/PFQ_C,2005/PFQ_D,2007/PFQ_E,2009/PFQ_F,2011/PFQ_G,2013/PFQ_H,2015/PFQ_I. Locate PFQ058, PFQ059, PFQ059A and each item heading. Actual routing text was checked in every file, not extrapolated.

## Model2: what can be implemented, and what remains candidate

Han p3 Covariate assessment and p6 Table2 footnote: Model1 age continuous, sex, cycle, race; Model2 adds education, PIR, drinking, smoking, BMI, physical activity, total energy, self-reported diabetes and hypertension. Race five groups; education <high school/high school/college or higher; smoking lifetime>=100 cigarettes. Tables use BMI<25/25–30/>=30; text overlaps at25. PIR<=1/1.1–3/>3 leaves1.01–1.09 unassigned without a declared operational choice. Disease borderline/unknown treatment and detailed PA cutpoints remain unpublished.

IMPORTANT alcohol distinction: ALD100 in2001B and ALQ101 in2015I ask about >=12 drinks in ANY one year, not specifically the past12months. Do not name this variable past-year drinking. ALQ120Q/U measure past12month frequency and ALQ130 drinks per drinking day. A past-year>=12 candidate can estimate annual drinks from those, with explicit annualization (week multiplier, month multiplier), topcoding and rounding assumptions. Frequency0 or lifetime<12 imply below12 without needing average drinks; observed yes to any-year alone does not imply current drinking. Missing/refused data cannot become nondrinking. Han's mixed past-year/lifetime language does not uniquely identify its implementation.
Sources: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2001/DataFiles/ALQ_B.htm#ALD100 and https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/ALQ_I.htm#ALQ101 . Both inspected including frequency/unit/average quantity fields.

Energy: official2003DR2TOT documentation explicitly says2001–2002 released1day and2003–2004 released2days. Han's two-day mean for all1999–2016 is therefore not literally available from these public files. Two-day complete-case2003+ and available-day mean with day1 fallback are different declared candidates. Neither can be silently called identical to Han.
Source: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2003/DataFiles/DR2TOT_C.htm ; Component Description, What's New/Table1. DR2TKCAL=kcal; day1/day2 reliability must be handled explicitly.

Activity:1999PAD200/PAD320 ask leisure/school activity>=10min in past30days. Codes1yes,2no,3unable,7refused,9unknown.2007PAQ605/620 ask vigorous/moderate work,635transport,650vigorous recreation,665moderate recreation in a typical week. Thus low/moderate/vigorous from yes/no is feasible as a declared intensity candidate, but early leisure-only versus later all-domain is a domain and recall-period change. Prefer also a leisure-only harmonized sensitivity (late650/665), rather than treating all-domain definition as source-identical. Unknown and early unable must be handled explicitly; no published Han PA cutpoints found.
Sources: https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/PAQ.htm#PAD200 and https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2007/DataFiles/PAQ_E.htm#PAQ605 .


