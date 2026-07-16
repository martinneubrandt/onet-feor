* ============================================================================
* 04: Build the wide element matrix for the loaded task definition
* ============================================================================
* Takes the appended O*NET table for the data year passed as the argument,
* keeps only the elements named by the loaded task definition, and reshapes
* them wide at the O*NET-SOC occupation level, one variable per element
* (named SCALE_ELEMENTID, e.g. IM_4A2a4).
*
* Which elements are kept is driven entirely by the task-definition globals
* ($taskcats, $els_*); this file contains no hardcoded element list. Output is
* written under the definition's own name, so several definitions can be built
* in one master run without overwriting each other.
*
* Reads:  temp/<year>/onet_appended.dta  (from 03_append_onet.do)
* Writes: temp/<year>/${taskdef_name}/onet_elements_wide.dta
*
* Run from the project root:  do "code/04_build_elements.do" <year>
* ============================================================================

* Clear data only (NOT macros) so the task-definition globals survive.
clear

args year
if "`year'" == "" local year 2022
* If run standalone with no definition in memory, load the default one.
if "$taskcats" == "" do "code/taskdef_acemoglu_autor_2011.do"

* Stata's mkdir does not create parents, hence one call per level.
capture mkdir "temp"
capture mkdir "temp/`year'"
capture mkdir "temp/`year'/${taskdef_name}"

use "temp/`year'/onet_appended.dta", clear

* Keep only the elements named in the task definition, each on the scale that
* the definition specifies (tokens are SCALE:ELEMENTID). Rows on any other
* scale - e.g. the CXP category-distribution version of a Work Context item -
* are dropped because their scaleid will not match.
generate byte keepflag = 0
foreach c in $taskcats {
	foreach tok in ${els_`c'} {
		local scale = substr("`tok'", 1, strpos("`tok'", ":") - 1)
		local elid  = substr("`tok'", strpos("`tok'", ":") + 1, .)
		replace keepflag = 1 if elementid=="`elid'" & scaleid=="`scale'"
	}
}
keep if keepflag == 1
drop keepflag

* Now that only the definition's scales remain (IM / CX / LV, all single-valued
* per occupation x element), one row per occupation x element x scale is
* expected. This cannot be asserted before the filter: the appended table still
* holds CXP category-distribution rows, which are many per element x scale.
duplicates drop
isid onetsoccode elementid scaleid

* Every SCALE:ELEMENTID token in the definition must have matched something.
* Without this, a typo in a token - or an element absent from an older O*NET
* release - would silently drop that element and the composite would quietly
* be built from fewer items.
foreach c in $taskcats {
	foreach tok in ${els_`c'} {
		local scale = substr("`tok'", 1, strpos("`tok'", ":") - 1)
		local elid  = substr("`tok'", strpos("`tok'", ":") + 1, .)
		count if elementid=="`elid'" & scaleid=="`scale'"
		if r(N) == 0 {
			display as error "Task definition token `tok' matched no O*NET rows"
			exit 459
		}
	}
}

* Generic id name: holds O*NET-SOC 2010 codes for data year 2019 and
* O*NET-SOC 2019 codes for later years. Step 06 picks the crosswalk chain.
rename onetsoccode onetsoc
replace elementid = subinstr(elementid, ".", "", .)
generate str varstub = scaleid + "_" + elementid
drop elementid scaleid

reshape wide datavalue, i(onetsoc) j(varstub) string
rename datavalue* *

* Occupations missing ANY element named by the task definition are dropped,
* loudly. Building a composite from fewer items than the definition names
* would silently change what the measure is for that occupation, so exclusion
* is the lesser evil - and the listing below keeps it auditable in the log.
* Known instance: O*NET 24.1 (data year 2019) publishes no CX 4.C.3.b.8
* (Structured versus Unstructured Work) for 15-2091.00 Mathematical
* Technicians; every other year x occupation is complete.
ds onetsoc, not
local elvars "`r(varlist)'"
generate byte incomplete = 0
foreach v of local elvars {
	replace incomplete = 1 if missing(`v')
}
count if incomplete
if r(N) > 0 {
	display as text "Dropping " r(N) " occupation(s) missing at least one required element:"
	list onetsoc if incomplete, noobs
	drop if incomplete
}
drop incomplete

compress
save "temp/`year'/${taskdef_name}/onet_elements_wide.dta", replace
