* ============================================================================
* 06: Crosswalk task measures from O*NET-SOC down to FEOR-08
* ============================================================================
* Chain, by data year:
*   2019:       O*NET-SOC 2010 -> SOC 2010 -> ISCO-08 -> FEOR-08
*   2020-2025:  O*NET-SOC 2019 -> SOC 2018 -> SOC 2010 -> ISCO-08 -> FEOR-08
*
* Data year 2019 (O*NET 24.1) is the last release on the O*NET-SOC 2010
* taxonomy; from 25.0 on, releases use O*NET-SOC 2019 (built on 2018 SOC).
* The repo's ISCO-08 crosswalk is keyed to 2010 SOC, hence the two SOC legs
* for 2020+. For 2019 no SOC leg needs a crosswalk file at all: by
* construction of the O*NET-SOC 2010 taxonomy, the first 7 characters of an
* O*NET-SOC 2010 code (XX-XXXX.YY) ARE its 2010 SOC code. (O*NET publishes no
* downloadable 2010-taxonomy-to-SOC crosswalk, so substr is also the only
* option.)
*
* Every leg collapses to an unweighted mean across matched occupations
* (joinby handles many-to-many matches by expanding all pairs first).
*
* collapse strips variable labels, so they are re-applied after each leg.
*
* Reads:  temp/<year>/${taskdef_name}/task_measures_onetsoc.dta
*         input/crosswalks/onetsoc2019_to_soc2018.dta  (from 02_build_crosswalks.do)
*         input/crosswalks/soc2010_to_soc2018.dta
*         input/crosswalks/soc10_isco08.dta
*         input/crosswalks/crosswalk_isco08_feor08.dta
* Writes: output/<year>/${taskdef_name}/onet_task_measures_feor08_${taskdef_name}.dta
*
* The output folder AND the file name itself carry the definition's own name
* ($taskdef_name), so building several definitions in one run cannot
* overwrite anything. Nothing here needs editing when the task definition is
* swapped.
*
* Run from the project root:  do "code/06_crosswalk_feor.do" <year>
* ============================================================================

args year
if "`year'" == "" local year 2022
* If run standalone with no definition in memory, load the default one.
if "$taskcats" == "" do "code/taskdef_acemoglu_autor_2011.do"

* Stata's mkdir does not create parents, hence one call per level.
capture mkdir "output"
capture mkdir "output/`year'"
capture mkdir "output/`year'/${taskdef_name}"

* Build the list of task variables (levels + standardized) from the definition.
local taskvars ""
foreach c in $taskcats {
	local taskvars `taskvars' task_`c' task_`c'_z
}

capture program drop label_task_vars
program define label_task_vars
	foreach c in $taskcats {
		capture label variable task_`c'   "${lab_`c'}"
		capture label variable task_`c'_z "${lab_`c'} (std)"
	}
end

use "temp/`year'/${taskdef_name}/task_measures_onetsoc.dta", clear

if `year' == 2019 {
	* --- 2019: O*NET-SOC 2010 -> SOC 2010, by construction -------------------
	* The first 7 characters of an O*NET-SOC 2010 code are its 2010 SOC code
	* (the taxonomy is 2010 SOC plus .01+ detail extensions), so no crosswalk
	* file is involved.
	generate str7 soc10str = substr(onetsoc, 1, 7)
	collapse (mean) `taskvars', by(soc10str)
	label_task_vars
}
else {
	* --- Leg 1: O*NET-SOC 2019 -> SOC 2018 ------------------------------------
	rename onetsoc onetsoc19
	joinby onetsoc19 using "input/crosswalks/onetsoc2019_to_soc2018.dta"
	collapse (mean) `taskvars', by(soc18)
	label_task_vars

	* --- Leg 2: SOC 2018 -> SOC 2010 -------------------------------------------
	joinby soc18 using "input/crosswalks/soc2010_to_soc2018.dta"
	collapse (mean) `taskvars', by(soc10)
	label_task_vars
	rename soc10 soc10str
}

* soc10_isco08.dta stores SOC 2010 as a number without the dash
generate long soc10 = real(subinstr(soc10str, "-", "", 1))
assert !missing(soc10)
drop soc10str

* --- Leg 3: SOC 2010 -> ISCO-08 --------------------------------------------
joinby soc10 using "input/crosswalks/soc10_isco08.dta"
collapse (mean) `taskvars', by(isco08)
label_task_vars

* --- Leg 4: ISCO-08 -> FEOR-08 ---------------------------------------------
joinby isco08 using "input/crosswalks/crosswalk_isco08_feor08.dta"
collapse (mean) `taskvars' (first) feor_08_name, by(feor_08)
label_task_vars

destring feor_08, replace
drop if missing(feor_08)

label var feor_08      "FEOR-08 occupation code (4-digit)"
label var feor_08_name "FEOR-08 occupation title"
order feor_08 feor_08_name

compress
save "output/`year'/${taskdef_name}/onet_task_measures_feor08_${taskdef_name}.dta", replace
