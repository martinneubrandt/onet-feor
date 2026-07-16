* ============================================================================
* 08: Plot the yearly trend of the task measures by 1-digit FEOR major group
* ============================================================================
* Two small-multiples line charts from the pooled panel, the same data seen
* from both sides:
*   figure 1  one panel per FEOR-08 major group (first digit, 1-9; group 0,
*             armed forces, is excluded - see below), one line per task
*             category
*   figure 2  one panel per task category, one line per major group
* x = data year. The plotted value is always the unweighted mean of the
* standardized composites (task_*_z) across the group's 4-digit codes.
*
* NOTE: the composites are standardized WITHIN each year (step 05), so a
* trend line shows a group's relative position drifting across years, not a
* change in task levels.
*
* Like steps 04-06 this is taxonomy-agnostic: the plotted series come from
* $taskcats / $lab_*, with a fixed 8-slot color+pattern palette (line
* patterns double as the colorblind-safe channel, so identity never rides on
* hue alone). More than 8 categories fails loudly.
*
* Reads:  output/${taskdef_name}/task_measures_feor08_panel.dta
* Writes: output/${taskdef_name}/task_trends_feor1.png          (fig 1)
*         output/${taskdef_name}/task_trends_feor1_by_task.png  (fig 2)
* Both figures are embedded in the README.
*
* Run from the project root:  do "code/08_plot_trends.do"
* ============================================================================

clear

* If run standalone with no definition in memory, load the default one.
if "$taskcats" == "" do "code/taskdef_acemoglu_autor_2011.do"

use "output/${taskdef_name}/task_measures_feor08_panel.dta", clear

* --- FEOR-08 major group = first digit --------------------------------------
* feor_08 is numeric, so the armed-forces codes 0110/0210/0310 are stored as
* 110-310 and floor()/1000 correctly puts them in major group 0.
generate byte feor1 = floor(feor_08/1000)
assert inrange(feor1, 0, 9)

label define feor1 ///
	1 "1 Managers"              2 "2 Professionals"        ///
	3 "3 Technicians, assoc."   4 "4 Clerical"             ///
	5 "5 Services, sales"       6 "6 Agricultural"         ///
	7 "7 Trades"                8 "8 Operators, drivers"   ///
	9 "9 Elementary", replace
label values feor1 feor1

* Major group 0 (armed forces) is excluded from both figures: 0110/0210 are
* never rated in O*NET, and 0310 rests on a single thin source that is only
* rated from data year 2020 - the group's line is more artifact than signal.
drop if feor1 == 0

* Unweighted mean of the standardized composites across the group's codes
collapse (mean) task_*_z, by(feor1 year)

* --- Build one line plot per task category ----------------------------------
* Categorical palette (colorblind-validated order and RGB steps); the line
* pattern is the secondary encoding required for hues this close.
local color1   "42 120 214"
local color2   "0 131 0"
local color3   "232 123 164"
local color4   "237 161 0"
local color5   "27 175 122"
local color6   "235 104 52"
local color7   "74 58 167"
local color8   "227 73 72"
local pattern1 solid
local pattern2 dash
local pattern3 longdash_dot
local pattern4 shortdash
local pattern5 dot
local pattern6 longdash
local pattern7 dash_dot
local pattern8 shortdash_dot

local plots ""
local legorder ""
local i 0
foreach c in $taskcats {
	local ++i
	if `i' > 8 {
		display as error "More than 8 task categories - extend the palette in 08_plot_trends.do"
		exit 198
	}
	local plots `plots' ///
		(line task_`c'_z year, lcolor("`color`i''") lpattern(`pattern`i'') lwidth(medthick))
	local legorder `legorder' `i' "${lab_`c'}"
}

quietly summarize year
local ymin = r(min)
local ymax = r(max)

twoway `plots', ///
	by(feor1, rows(3) note("") legend(position(6)) ///
		graphregion(color(white)) plotregion(color(white))) ///
	yline(0, lcolor("195 194 183") lwidth(thin)) ///
	ylabel(, grid glcolor("225 224 217") glwidth(vthin) angle(horizontal) labsize(small) labcolor("82 81 78")) ///
	xlabel(`ymin'(3)`ymax', labsize(small) labcolor("82 81 78")) ///
	ytitle("Task measure (z, standardized within year)", size(small)) ///
	xtitle("") ///
	subtitle(, size(small) bcolor(white)) ///
	legend(order(`legorder') cols(2) size(vsmall) symxsize(8) rowgap(1) region(lstyle(none))) ///
	graphregion(color(white)) plotregion(color(white)) ///
	xsize(9) ysize(8)

graph export "output/${taskdef_name}/task_trends_feor1.png", replace width(2600)

* ============================================================================
* Figure 2: the transposed view - one panel per task category, one line per
* FEOR major group
* ============================================================================
* Nine series exceed the 8-slot categorical palette by one, so group 9 takes
* a neutral extension (gray). Identity still never rides on hue alone: every
* series keeps its own color x pattern pair, and within a panel the groups'
* rank separation does most of the work.
local color9   "82 81 78"
local pattern9 solid

* Long over task categories, encoded in $taskcats order so the panels appear
* in the definition's own order with the definition's labels.
reshape long task_@_z, i(feor1 year) j(cat) string
generate int catnum = .
capture label drop catlab
local i 0
foreach c in $taskcats {
	local ++i
	replace catnum = `i' if cat == "`c'"
	label define catlab `i' "${lab_`c'}", add
}
assert !missing(catnum)
label values catnum catlab

local plots ""
local legorder ""
foreach g of numlist 1/9 {
	local plots `plots' ///
		(line task__z year if feor1 == `g', lcolor("`color`g''") lpattern(`pattern`g'') lwidth(medthick))
	local lbl : label feor1 `g'
	local legorder `legorder' `g' `"`lbl'"'
}

twoway `plots', ///
	by(catnum, rows(1) note("") legend(position(6)) ///
		graphregion(color(white)) plotregion(color(white))) ///
	yline(0, lcolor("195 194 183") lwidth(thin)) ///
	ylabel(, grid glcolor("225 224 217") glwidth(vthin) angle(horizontal) labsize(small) labcolor("82 81 78")) ///
	xlabel(`ymin'(3)`ymax', labsize(small) labcolor("82 81 78")) ///
	ytitle("Task measure (z, standardized within year)", size(small)) ///
	xtitle("") ///
	subtitle(, size(small) bcolor(white)) ///
	legend(order(`legorder') rows(2) size(small) region(lstyle(none))) ///
	graphregion(color(white)) plotregion(color(white)) ///
	xsize(13) ysize(5)

graph export "output/${taskdef_name}/task_trends_feor1_by_task.png", replace width(2600)
