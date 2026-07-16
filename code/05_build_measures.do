* ============================================================================
* 05: Build the task composites at O*NET-SOC level
* ============================================================================
* Each element is standardized (mean 0, sd 1, unweighted across that year's
* O*NET-SOC occupations), reverse-coded where the definition says so, then
* each composite is the unweighted mean of its standardized elements and is
* itself re-standardized (task_*_z).
*
* NOTE: standardization is WITHIN the data year's release. The measures are
* relative positions among that year's occupations, not levels comparable
* across years.
*
* Which elements form each composite, and which are reversed, is driven
* entirely by the task-definition globals ($taskcats, $els_*, $rev_els,
* $lab_*). See the loaded taskdef_*.do file for the actual taxonomy.
*
* Reads:  temp/<year>/${taskdef_name}/onet_elements_wide.dta
* Writes: temp/<year>/${taskdef_name}/task_measures_onetsoc.dta
*
* Run from the project root:  do "code/05_build_measures.do" <year>
* ============================================================================

args year
if "`year'" == "" local year 2022
* If run standalone with no definition in memory, load the default one.
if "$taskcats" == "" do "code/taskdef_acemoglu_autor_2011.do"

use "temp/`year'/${taskdef_name}/onet_elements_wide.dta", clear

* Standardize every element variable (everything except the occupation id).
ds onetsoc, not
foreach v in `r(varlist)' {
	egen z_`v' = std(`v')
}

* Reverse-code the elements flagged in the definition. A high raw value on
* these means LESS of the task (e.g. Structured vs Unstructured Work: a high
* value is high autonomy, i.e. less routine).
foreach tok in $rev_els {
	local scale = substr("`tok'", 1, strpos("`tok'", ":") - 1)
	local elid  = substr("`tok'", strpos("`tok'", ":") + 1, .)
	local vname `scale'_`= subinstr("`elid'", ".", "", .)'
	replace z_`vname' = -z_`vname'
}

* Build each composite as the unweighted mean of its standardized elements,
* then standardize the composite. Labels come from the definition.
foreach c in $taskcats {
	local zvars ""
	foreach tok in ${els_`c'} {
		local scale = substr("`tok'", 1, strpos("`tok'", ":") - 1)
		local elid  = substr("`tok'", strpos("`tok'", ":") + 1, .)
		local vname `scale'_`= subinstr("`elid'", ".", "", .)'
		local zvars `zvars' z_`vname'
	}
	egen task_`c'   = rowmean(`zvars')
	egen task_`c'_z = std(task_`c')
	label var task_`c'   "${lab_`c'}"
	label var task_`c'_z "${lab_`c'} (std)"
}

keep onetsoc task_*
compress
save "temp/`year'/${taskdef_name}/task_measures_onetsoc.dta", replace
