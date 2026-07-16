* ============================================================================
* Task-content measures for FEOR-08, from O*NET data years 2019-2025
* ============================================================================
* Builds task composites at the O*NET-SOC occupation level for every data
* year listed below and crosswalks them down to Hungarian FEOR-08 (4-digit).
*
* Version policy: each data year uses that year's final (November) O*NET
* release - see the year->version map in 01_download_onet.do.
*
* Crosswalk chain (data year 2019 uses the older O*NET-SOC 2010 taxonomy;
* the O*NET-SOC 2019 taxonomy starts with release 25.0):
*   2019:       O*NET-SOC 2010 -> SOC 2010 -> ISCO-08 -> FEOR-08
*   2020-2025:  O*NET-SOC 2019 -> SOC 2018 -> SOC 2010 -> ISCO-08 -> FEOR-08
* Aggregation at every leg: unweighted mean across matched occupations.
*
* The task taxonomy itself - which O*NET elements go into which category, on
* which scale, and what is reverse-coded - lives entirely in the swappable
* taskdef_*.do files listed below. Steps 01-08 are taxonomy-agnostic and
* contain no element ids.
*
* Run from the project root:  do "code/00_master.do"
* ============================================================================

clear all
set more off

* --- Data years to build -----------------------------------------------------
* Each year needs an entry in the year->version map in 01_download_onet.do.
local years "2019 2020 2021 2022 2023 2024 2025"

* --- Task definitions to build ----------------------------------------------
* One entry per taskdef_*.do file, without the "taskdef_" prefix or ".do".
* Add more to build several definitions in the same run: each writes to its
* own folder under output/<year>/, named by its $taskdef_name.
local defs "acemoglu_autor_2011 autor_dorn_2013"

* --- Crosswalks (year-independent, built once) -------------------------------
do "code/02_build_crosswalks.do"

* --- Per-year steps -----------------------------------------------------------
* The O*NET Excel files are parsed once per year (steps 01+03) and shared by
* every task definition; steps 04-06 then run per year x definition.
foreach y of local years {
	display as text _newline(1) "{hline 76}"
	display as text "Data year `y'"
	display as text "{hline 76}"

	do "code/01_download_onet.do" `y'
	do "code/03_append_onet.do"   `y'

	foreach d of local defs {
		display as text _newline(1) "Building task definition: `d' (data year `y')"

		do "code/taskdef_`d'.do"
		do "code/04_build_elements.do" `y'
		do "code/05_build_measures.do" `y'
		do "code/06_crosswalk_feor.do" `y'
	}
}

* --- Pooled panel across years + trend figure, one per definition ------------
foreach d of local defs {
	do "code/taskdef_`d'.do"
	do "code/07_build_panel.do" "`years'"
	do "code/08_plot_trends.do"
}
