* ============================================================================
* 07: Pool the per-year FEOR-08 task measures into one panel
* ============================================================================
* Appends the per-year outputs of 06_crosswalk_feor.do for the loaded task
* definition into one long file, one row per FEOR-08 code x data year.
*
* NOTE: the measures are standardized WITHIN each year's O*NET release
* (step 05), so values are relative positions among that year's occupations.
* Comparing an occupation's value across years is meaningful as a change in
* relative position, not as a change in task level.
*
* Reads:  output/<year>/${taskdef_name}/task_measures_feor08.dta  (per year)
* Writes: output/${taskdef_name}/task_measures_feor08_panel.dta
*
* Run from the project root:  do "code/07_build_panel.do" "<year list>"
* e.g.                        do "code/07_build_panel.do" "2019 2020 2021"
* ============================================================================

clear

args years
if "`years'" == "" local years "2019 2020 2021 2022 2023 2024 2025"
* If run standalone with no definition in memory, load the default one.
if "$taskcats" == "" do "code/taskdef_acemoglu_autor_2011.do"

capture mkdir "output"
capture mkdir "output/${taskdef_name}"

tempfile panel
local first 1
foreach y of local years {
	local f "output/`y'/${taskdef_name}/task_measures_feor08.dta"

	* Fail loudly on a missing year rather than silently building a shorter
	* panel - every year in the list must have been built by step 06.
	capture confirm file "`f'"
	if _rc {
		display as error "`f' not found - run the pipeline for data year `y' first"
		exit 601
	}

	use "`f'", clear
	generate int year = `y'
	if !`first' append using "`panel'"
	save "`panel'", replace
	local first 0
}

label variable year "O*NET data year"
isid feor_08 year
sort feor_08 year
order feor_08 year feor_08_name

compress
save "output/${taskdef_name}/task_measures_feor08_panel.dta", replace
