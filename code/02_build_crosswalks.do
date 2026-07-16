* ============================================================================
* 02: Build the crosswalk .dta files from their raw sources
* ============================================================================
* Produces all four crosswalk legs from input/crosswalks/raw/:
*
*   Leg 1  O*NET-SOC 2019 -> SOC 2018   downloaded here, then imported
*   Leg 2  SOC 2010  <-> SOC 2018       imported from the committed BLS xlsx
*   Leg 4  ISCO-08    -> FEOR-08        imported from the committed KSH csv
*   Leg 3  SOC 2010  <-> ISCO-08        imported from the committed BLS xls
*
* Leg 4 is built BEFORE leg 3, which uses it as the list of valid 4-digit
* ISCO unit groups.
*
* All legs are year-independent, so this runs once per master run. Data year
* 2019 (O*NET 24.1, still on the O*NET-SOC 2010 taxonomy) uses only legs 3-4:
* its O*NET-SOC -> SOC 2010 step needs no crosswalk file at all (the first 7
* characters of an O*NET-SOC 2010 code ARE its 2010 SOC code) and is done
* inline in 06_crosswalk_feor.do.
*
* The two BLS files cannot be fetched automatically - BLS returns HTTP 403 to
* curl and to Stata's copy - so they are committed to input/crosswalks/raw/
* and read from there. KSH publishes leg 4 only as a PDF (committed at
* input/crosswalks/raw/fordkulcs_isco_feor_hu.pdf); the committed CSV next to
* it is a transcription of that PDF produced by
* code/extract_isco08_feor08_pdf.py, which can be re-run to verify the CSV
* against the PDF.
*
* Reads:  input/crosswalks/raw/2019_to_SOC_Crosswalk.xlsx      (downloaded here)
*         input/crosswalks/raw/soc_2010_to_2018_crosswalk.xlsx (committed)
*         input/crosswalks/raw/fordkulcs_isco_feor_hu.csv      (committed)
*         input/crosswalks/raw/ISCO_SOC_Crosswalk.xls          (committed)
* Writes: input/crosswalks/onetsoc2019_to_soc2018.dta
*         input/crosswalks/soc2010_to_soc2018.dta
*         input/crosswalks/crosswalk_isco08_feor08.dta
*         input/crosswalks/soc10_isco08.dta
*
* Run from the project root.
* ============================================================================

clear

* Stata's mkdir does not create parents, hence one call per level.
capture mkdir "input"
capture mkdir "input/crosswalks"
capture mkdir "input/crosswalks/raw"

* ============================================================================
* Leg 1: O*NET-SOC 2019 -> SOC 2018
* ============================================================================
* This one IS fetchable: the O*NET Center does not block non-browser requests.

local url "https://www.onetcenter.org/taxonomy/2019/soc/2019_to_SOC_Crosswalk.xlsx?fmt=xlsx"
local raw "input/crosswalks/raw/2019_to_SOC_Crosswalk.xlsx"
copy "`url'" "`raw'", replace

* Rows 1-3 are title banners; the header is on row 4, data from row 5.
import excel using "`raw'", cellrange(A4) firstrow clear
rename ONETSOC2019Code  onetsoc19
rename ONETSOC2019Title onetsoc19_title
rename SOCCode          soc18
rename SOCTitle         soc18_title
keep onetsoc19 onetsoc19_title soc18 soc18_title
drop if missing(onetsoc19)

label variable onetsoc19       "O*NET-SOC 2019 code"
label variable onetsoc19_title "O*NET-SOC 2019 title"
label variable soc18           "2018 SOC code"
label variable soc18_title     "2018 SOC title"

compress
save "input/crosswalks/onetsoc2019_to_soc2018.dta", replace

* ============================================================================
* Leg 2: SOC 2010 <-> SOC 2018
* ============================================================================
* Rows 1-8 are BLS title banners, the header is on row 9, data from row 10.
*
* Imported BY POSITION, not by header name. The sheet has both a "2010 SOC
* Code" and a "2018 SOC Code" column; Stata's firstrow maps both to the same
* variable name, silently falls back to the column letters (c, d) for the
* second pair, and the result is unreadable. Column order is A=2010 code,
* B=2010 title, C=2018 code, D=2018 title.

import excel using "input/crosswalks/raw/soc_2010_to_2018_crosswalk.xlsx", ///
	cellrange(A10) clear allstring
rename A soc10
rename B soc10_title
rename C soc18
rename D soc18_title
keep soc10 soc10_title soc18 soc18_title

foreach v of varlist soc10 soc10_title soc18 soc18_title {
	replace `v' = strtrim(`v')
}
drop if missing(soc10) | missing(soc18)

label variable soc10       "2010 SOC code"
label variable soc10_title "2010 SOC title"
label variable soc18       "2018 SOC code"
label variable soc18_title "2018 SOC title"

isid soc10 soc18
compress
save "input/crosswalks/soc2010_to_soc2018.dta", replace

* ============================================================================
* Leg 4: ISCO-08 -> FEOR-08 (built before leg 3, which consumes it)
* ============================================================================
* One row per printed mapping in the KSH PDF: 548 rows, of which 12 are ISCO
* unit groups with no FEOR-08 counterpart (marked blue in the PDF); those
* keep a missing feor_08 and fall out downstream after the join in 06.
*
* Codes arrive as 4-character strings. The armed-forces codes 0110/0210/0310
* would lose their leading zero to any numeric conversion, so the 4-digit
* length is asserted BEFORE destring; they are stored numerically
* (110/210/310), which is how isco08 is keyed throughout the pipeline.

import delimited using "input/crosswalks/raw/fordkulcs_isco_feor_hu.csv", ///
	varnames(1) stringcols(_all) encoding("utf-8") clear

assert _N == 548
assert strlen(isco08) == 4
assert strlen(feor_08) == 4 if !missing(feor_08)

destring isco08 feor_08, replace
isid isco08 feor_08, missok

label variable isco08       "ISCO-08 unit group (4-digit)"
label variable isco_name    "ISCO-08 title (Hungarian)"
label variable feor_08      "FEOR-08 occupation code (4-digit)"
label variable feor_08_name "FEOR-08 occupation title"

compress
save "input/crosswalks/crosswalk_isco08_feor08.dta", replace

* ============================================================================
* Leg 3: SOC 2010 <-> ISCO-08
* ============================================================================
* Rows 1-6 are BLS title banners, the header is on row 7, data from row 8.
*
* BLS maps a couple of SOC codes to a 3-digit ISCO MINOR GROUP rather than to
* a 4-digit unit group (in the current file: 211 and 315). The pipeline joins
* on 4-digit isco08, so a minor group would silently match nothing and those
* occupations would vanish. Each minor group is therefore expanded to every
* 4-digit unit group it contains, taking the list of valid unit groups from
* the ISCO-08 -> FEOR-08 crosswalk.
*
* NOTE: the minor-group test is on the RAW STRING LENGTH, not on the numeric
* value. The armed-forces codes 0110 / 0210 / 0310 are genuine 4-digit unit
* groups whose leading zero is lost the moment real() is applied - testing
* isco08 < 1000 would wrongly treat them as minor groups.

* --- Valid 4-digit ISCO unit groups, and the minor group each sits in --------
use "input/crosswalks/crosswalk_isco08_feor08.dta", clear
keep isco08
duplicates drop
generate str3 isco_minor = substr(string(isco08, "%04.0f"), 1, 3)
tempfile isco_units
save "`isco_units'", replace

* --- Raw BLS mapping ---------------------------------------------------------
import excel using "input/crosswalks/raw/ISCO_SOC_Crosswalk.xls", ///
	sheet("ISCO-08 to 2010 SOC") cellrange(A7) firstrow clear allstring
rename *, lower
keep isco08code soccode

* A few cells in the BLS file carry stray whitespace ("3322 ", "5169 ", ...),
* which would defeat the string-length test below.
replace isco08code = strtrim(isco08code)
replace soccode    = strtrim(soccode)
drop if missing(isco08code) | missing(soccode)

generate long soc10 = real(subinstr(soccode, "-", "", 1))
assert !missing(soc10)

* Every ISCO code must be either a 4-digit unit group or a 3-digit minor group.
assert inlist(strlen(isco08code), 3, 4)

* --- Rows already at 4-digit ISCO --------------------------------------------
preserve
	keep if strlen(isco08code) == 4
	generate long isco08 = real(isco08code)
	keep soc10 isco08
	tempfile direct
	save "`direct'", replace
restore

* --- Minor-group rows: expand to every unit group inside the minor group -----
keep if strlen(isco08code) == 3
generate str3 isco_minor = isco08code
local n_minor = _N
joinby isco_minor using "`isco_units'", unmatched(master)

* A minor group with no unit groups in the ISCO->FEOR list would be dropped
* here, silently losing that SOC. Fail loudly instead.
capture confirm variable _merge
if !_rc {
	count if _merge == 1
	if r(N) > 0 {
		display as error "A 3-digit ISCO minor group matched no 4-digit unit group"
		exit 459
	}
	drop _merge
}
keep soc10 isco08

* --- Combine -----------------------------------------------------------------
append using "`direct'"
duplicates drop
isid soc10 isco08
sort soc10 isco08

label variable soc10  "2010 SOC code (digits only, dash removed)"
label variable isco08 "ISCO-08 unit group (4-digit)"

compress
save "input/crosswalks/soc10_isco08.dta", replace
