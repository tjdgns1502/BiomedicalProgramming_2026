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

## Figure3 visual transcription, p8

Six modifiers: age, sex, BMI, physical activity, smoking status, alcohol. Figure printed age labels50–65 and>=65 overlap at65; choose50–64/65+ only as declared interpretation. Sex male/female. BMI printed<=25,25–30,>=30 overlaps, whereas Table2 uses<25. Activity low/moderate/vigorous (text calls last active). Smoking/alcohol yes/no. Caption lists full Model2 adjustment, but does not say how stratified covariate removed, whether residual continuous age/BMI retained, or which interaction test used. Continuous log marker scale follows methods but log base unreported.

Interaction p-values in modifier order above (visual reading): NLR .048,.018,.227,.105,.109,.985; MLR .001,.870,.071,.355,.085,.393; SIRI .040,.065,.362,.065,.035,.318; SII .643,.063,.128,.043,.140,.948. These are published labels, never fitting targets. SIRI smoking panel OR yes2.66(2.01–3.52), no1.86(.90–3.82); retain figure vs prose discrepancy.

RCS p3 reports comparing linear and spline models for nonlinearity. Figure2 uses fullModel2 adjustment. Knots, degrees of freedom, reference, trimming, weighting, and test implementation are not reported in main text/supplement. Do not claim an exact author RCS reconstruction. A declared fixed-knot candidate is permitted by evidence but not validated by visual curve similarity.

## Direct reference audit and bounded search log

1. Read original Han paper extraction, supplement evidence, reference22 and23 supplements. Han supplement lists36names/ranges, not self-report scoring thresholds. Existing reference supplements locally preserved under S01.
2. Opened publisher fulltexts https://link.springer.com/article/10.1007/s11357-017-9993-7 (ref22) and https://link.springer.com/article/10.1186/s12916-021-01918-5 (ref23). Ref22 Methods/Frailty index construction explicitly says outside normal range=1, <20%missing required; its68item combined FI differs from Han36. Ref23 Frailty index paragraph says deficits/possible deficits; S2 matches36names/ranges but adds no complete self-report thresholds. Ref23 usesSPSS25, so it cannot document Han'sR4.3/RCS implementation.
3. Publisher data availability for Han https://link.springer.com/article/10.1186/s12889-024-20908-9 links only publicNHANES; ref23 likewise. No author analysis repository identified there.
4. Web queries: exact Han DOI plus code/github; ShaojieHan frailty code; Jayanama frailty github; Blodgett NHANES github; site:github.com exactHanDOI; site:github.com frailtyJayanama. Returned article pages and related papers, no identified author code. This is bounded search failure, not proof no repository exists.
5. Re-read p8 visually using renderedpage8.png after reading PDF skill. Publisher figure-image requests failed; local originalPDF supplied actual figure labels.
6. Downloaded and checked allninePFQ official HTMLs. Opened officialALQ_B/ALQ_I,PAQ1999/PAQ_E,DR2TOT_C for specific coding uncertainties above.

Remaining nonidentifiable author details: five named self-report health/utilization/medication dichotomizations, partialFI missingness/denominator, exactPA mapping, any-year versus past-year alcohol implementation, energy fallback, PIR decimal boundaries, survey regression settings, log base, spline specification, categorical subgroup boundaries and interaction details. These do not prevent transparent candidate analyses; they prevent claiming author-identical variables and methods.

## PA frozen-source addendum

All nine cycle PA variable pairs verified (1999/2007 via CDC web; remaining7 HTML archived here):1999–2006 PAD200/PAD320;2007–2016 PAQ650/PAQ665. Leisure/recreation only. Work/transport excluded. Candidate three-level hierarchy: vigorous if vigorous=1; moderate if vigorous explicitly nonparticipating and moderate=1; low if both explicitly nonparticipating; otherwise unknown. Early code3 unable can count as nonparticipation only as declared choice and retain an unable flag; conservative alternative leaves3missing. Codes7/9 and system missing never count as no. A vigorous yes determines highest category even if moderate unknown, by hierarchy; this is logical classification rather than NA imputation. There is no documented reason to fill missing yes/no leisure gates from work/transport gates. Later no/refused/unknown vigorous skips only its follow-up days/minutes and proceeds to moderate gate. Missing follow-up duration after explicit no is a legitimate zero-duration inference, but irrelevant when only gate intensities used. Early both gates are asked independently; no gate-null filling justified. These three classes are analyst intensity categories, not verified Han cutpoints or WHO guideline adherence.

## Verified two-day dietary sensitivity contract (final addendum)

Official sources support WTDR2D for analyses that use both recalls. CDC2003–2004 DR2TOT_C, Analytic Notes/sample weights, explicitly distinguishes day1WTDRD1 from two-dayWTDR2D;2015–2016 DR2TOT_I reiterates WTDR2D for the smaller completed-both-days sample and explains second-recall nonresponse/weekend-weekday adjustment. MEC weights do not make the dietary subset representative in the same way. This supports a separate two-day dietary-weight analysis, while the current MEC-weight/day1 model retains its exploratory label.

- Two-day energy=(DR1TKCAL+DR2TKCAL)/2, requiring both nonmissing and DR1DRSTZ=1 and DR2DRSTZ=1 for adult candidate membership; WTDR2D must be finite and>0. Code1 means reliable and minimum completion criteria met. Do not require calories>0: official documents explicitly permit fasting/zero nutrient recalls as complete and reliable. Other status codes and systemmissing are not silently converted to1.
- Public two-day data begin with2003–2004. Seven2year cycles2003–04,05–06,07–08,09–10,11–12,13–14,15–16 imply pooled weightWTDR2D/7. This is application of CDC's stated rule (2001+ equal2year cycles divide the2yearweight by number ofcycles), not an author-specific Han specification. No1999weight exception needed in this2003+ sensitivity.
- Join all-age DEMO records to dietaryweight records by cycle+SEQN before marking age/FI/model complete-case eligibility. Build survey design from the positiveWTDR2D parent and use a domain/subpopulation indicator for adult candidate eligibility. Do not prefilter toage>=50 or modelcomplete rows before design. Parent includes any legitimate positiveweight records, including infant specialstatus cases, while adult analysis domain specifically requires bothstatus1; this avoids inadvertently deleting samplingunits before domainvariance calculation. DEMO supplies SDMVSTRA/SDMVPSU. Verify uniqueness, joins, and actual positiveweight coverage.
- Matched day1 versusmean2 sensitivity should use exactly the same two-day eligible domain and WTDR2D/7 design, changing only energy covariate. This is a controlled analyst comparison within two-day responders; it is not the standard full day1 population estimate (which would useWTDRD1). Neither comparison establishes Han's unavailable1999–2002 two-daymean.

URLs/locations:
1. https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2003/DataFiles/DR2TOT_C.htm — What's New/Table1(firsttwo-dayrelease); Analytic Notes/sampleweights; fastingparagraph; DR2DRSTZ andWTDR2D codebook.
2. https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2015/DataFiles/DR2TOT_I.htm — dietaryrecallstatuscodes(DR1DRSTZ/DR2DRSTZ), status1; Sampleweightsfordietaryintakedata, paragraphsWTDRD1/WTDR2D; zero-intakeparagraph.
3. https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx — CombiningSurveyCycles, rulefor2001–2002onward; smallest-relevant-sampleweight guidance.
4. https://wwwn.cdc.gov/nchs/nhanes/tutorials/varianceestimation.aspx — subpopulation/domainanalysis guidance. Surveyparent/domain implementation is an application of officialvariance guidance, not an exact published Han code claim.
