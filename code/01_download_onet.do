* ============================================================================
* 01: Get the O*NET database (Excel) and extract the files the pipeline uses
* ============================================================================
* Ensures the three source files 03_append_onet.do reads (Abilities, Work
* Activities, Work Context) are present in input/onet_<year>/ for the data
* year passed as the argument. The three xlsx are COMMITTED to the repo, so a
* fresh clone runs offline; the release zip is only downloaded (into the
* gitignored raw/ cache) when the xlsx are missing - e.g. after adding a new
* data year.
*
* Version policy: use each data year's final (November) O*NET release.
* The year->version map below is the one place it is encoded.
*
* Downloaded raw zip: input/onet_<year>/raw/db_<ver>_excel.zip   [gitignored]
* Extracted files:    input/onet_<year>/{Abilities, Work Activities,
*                     Work Context}.xlsx                          [committed]
*
* Run from the project root:  do "code/01_download_onet.do" <year>
* ============================================================================

args year
if "`year'" == "" local year 2022

* --- Data year -> O*NET release (the final, November release of that year) ---
local ver ""
if `year' == 2019 local ver "24_1"
if `year' == 2020 local ver "25_1"
if `year' == 2021 local ver "26_1"
if `year' == 2022 local ver "27_1"
if `year' == 2023 local ver "28_1"
if `year' == 2024 local ver "29_1"
if `year' == 2025 local ver "30_1"
if "`ver'" == "" {
	display as error "No O*NET release mapped to data year `year' - add it to the map in 01_download_onet.do"
	exit 198
}

local dest "input/onet_`year'"
local url  "https://www.onetcenter.org/dl_files/database/db_`ver'_excel.zip"

* Stata's mkdir does not create parents, hence one call per level.
capture mkdir "input"
capture mkdir "`dest'"
capture mkdir "`dest'/raw"

* --- Skip everything if the three committed xlsx are already there -----------
capture confirm file "`dest'/Abilities.xlsx"
local miss = _rc
capture confirm file "`dest'/Work Activities.xlsx"
local miss = max(`miss', _rc)
capture confirm file "`dest'/Work Context.xlsx"
local miss = max(`miss', _rc)
if !`miss' {
	display as text "Data year `year' (O*NET `ver'): using the committed xlsx (no download needed)"
	exit
}

* --- Get the release zip ------------------------------------------------------
* The zip lives only in the gitignored raw/ cache; reuse it if a previous run
* already downloaded it.
local zip "`dest'/raw/db_`ver'_excel.zip"
capture confirm file "`zip'"
if _rc {
	display as text "db_`ver'_excel.zip not found - downloading from `url'"
	copy "`url'" "`zip'", replace
}
else {
	display as text "Using the cached db_`ver'_excel.zip (no download needed)"
}

* --- Extract -----------------------------------------------------------------
* unzipfile extracts into the working directory, so cd into raw/ first (keeping
* everything contained there) and restore the working directory afterwards.
* The zip unpacks into a db_`ver'_excel/ subfolder.
local here "`c(pwd)'"
cd "`dest'/raw"
unzipfile "db_`ver'_excel.zip", replace
cd "`here'"

* --- Copy out the three files the pipeline reads ----------------------------
* confirm first, so a release with a different internal layout fails loudly
* instead of copy's generic error.
foreach f in "Abilities" "Work Activities" "Work Context" {
	confirm file "`dest'/raw/db_`ver'_excel/`f'.xlsx"
	copy "`dest'/raw/db_`ver'_excel/`f'.xlsx" "`dest'/`f'.xlsx", replace
}
