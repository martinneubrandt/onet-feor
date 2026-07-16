* ============================================================================
* 03: Append the O*NET source files into one long table
* ============================================================================
* Imports the three O*NET files the pipeline uses for the data year passed as
* the argument and stacks them into a single long table, one row per
* occupation x element x scale.
*
* This step is DEFINITION-INDEPENDENT: it keeps every element on every scale
* and does not read the task-definition globals at all. That is deliberate -
* the appended table is shared infrastructure. When several task definitions
* are built in one master run, the Excel files are parsed once per year here
* and each definition then filters this same table for the elements it needs
* (step 04).
*
* Reads:  input/onet_<year>/Abilities.xlsx, Work Activities.xlsx, Work Context.xlsx
* Writes: temp/<year>/onet_appended.dta
*
* Run from the project root:  do "code/03_append_onet.do" <year>
* ============================================================================

clear

args year
if "`year'" == "" local year 2022

* temp/ is not in version control, so it may not exist in a fresh clone.
* Stata's mkdir does not create parents, hence one call per level.
capture mkdir "temp"
capture mkdir "temp/`year'"

import excel using "input/onet_`year'/Abilities.xlsx", firstrow clear
	rename *, lower
	keep onetsoccode elementid scaleid datavalue
save "temp/`year'/abilities.dta", replace

import excel using "input/onet_`year'/Work Activities.xlsx", firstrow clear
	rename *, lower
	keep onetsoccode elementid scaleid datavalue
save "temp/`year'/work_activities.dta", replace

import excel using "input/onet_`year'/Work Context.xlsx", firstrow clear
	rename *, lower
	keep onetsoccode elementid scaleid datavalue
save "temp/`year'/work_context.dta", replace

use "temp/`year'/abilities.dta", clear
append using "temp/`year'/work_activities.dta"
append using "temp/`year'/work_context.dta"

* NOTE: this table is deliberately NOT deduplicated and NOT unique on
* onetsoccode x elementid x scaleid. The Work Context file carries CXP
* (category-distribution) rows, which hold one row per response category for
* the same element and scale, distinguished only by a category column the
* pipeline does not keep. Deduplicating here would silently merge two CXP
* categories that happen to share a datavalue.
* Uniqueness is asserted in 04_build_elements.do instead, after the filter has
* reduced the table to the single-valued scales (IM / CX / LV) a definition
* actually names.

label variable onetsoccode "O*NET-SOC code (2010 taxonomy for data year 2019, 2019 taxonomy after)"
label variable elementid   "O*NET Content Model element id (dotted)"
label variable scaleid     "O*NET scale (IM, LV, CX, CXP, ...)"
label variable datavalue   "Element value on that scale"

compress
save "temp/`year'/onet_appended.dta", replace
