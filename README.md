# O\*NET–FEOR

Builds **task-content measures** from the O\*NET database and crosswalks them
to Hungarian **FEOR-08** (4-digit) occupations, for every **data year
2019–2025** (each year from that year's final O\*NET release). The task
taxonomy lives in **swappable definition files** — the rest of the pipeline is
taxonomy-agnostic, and several definitions build in one run, each to its own
output folder. Two ship with the repo: **Acemoglu & Autor (2011)** and
**Autor & Dorn (2013)** — see [Task definitions](#task-definitions).

## How to run

From the **project root** (all paths in the do-files are relative to it):

```stata
do code/00_master.do
```

The master builds the crosswalks once, loops over the `years` and `defs`
macros, then pools each definition into a panel and draws its figures. It
needs no network access — see [Repository layout](#repository-layout).

## Pipeline (`code/`)

File names sort in run order. Steps 01 and 03–07 take the data year as a
do-file argument (e.g. `do "code/03_append_onet.do" 2023`; step 07 takes the
year list) and default to 2022 standalone. Step 02 is year-independent.

| Step | File | Scope | What it does |
|------|------|-------|--------------|
| 00 | `00_master.do` | — | Entry point. Runs 02 once, 01+03 per year, 04–06 per year × definition, 07–08 per definition. |
| 01 | `01_download_onet.do` | per year | Ensures the Abilities / Work Activities / Work Context xlsx are in `input/onet_<year>/`. The xlsx are committed; the release zip is downloaded (into the gitignored `raw/` cache) only when they are missing. Holds the year → release map. |
| 02 | `02_build_crosswalks.do` | shared | Builds all four crosswalk legs into `input/crosswalks/`: downloads the O\*NET-SOC 2019 → 2018 SOC mapping, imports the two committed BLS files and the committed KSH transcription (see [Data sources](#data-sources-and-provenance)). |
| 03 | `03_append_onet.do` | per year | Stacks the three Excel files into one long table, every element on every scale. Definition-independent, so Excel parsing happens once per year however many definitions are built. |
| def | `taskdef_*.do` | per def | Defines the task taxonomy: name, elements (and scales) per category, reverse-coding, labels. **The only files with element IDs in them.** |
| 04 | `04_build_elements.do` | year × def | Keeps only the definition's elements, reshapes wide (one variable per element, `SCALE_ELEMENTID`). |
| 05 | `05_build_measures.do` | year × def | Standardizes each element (within the year's release), reverse-codes where flagged, composites = unweighted means of standardized elements, re-standardized (`task_*_z`). |
| 06 | `06_crosswalk_feor.do` | year × def | Crosswalks the composites from O\*NET-SOC down to FEOR-08 (chain depends on the year — see [Crosswalk chain](#crosswalk-chain)). |
| 07 | `07_build_panel.do` | per def | Appends the per-year FEOR-08 files into one long panel with a `year` variable. |
| 08 | `08_plot_trends.do` | per def | Draws the yearly trends from the panel, in both views (the figures under [Task definitions](#task-definitions)). |

## Repository layout

```
code/       the pipeline (master + 8 steps + task definitions)
input/
  crosswalks/          4 derived .dta + the raw BLS/KSH sources   [in git]
  onet_<year>/*.xlsx   the 3 O*NET files the pipeline reads       [in git]
  onet_<year>/raw/     download cache: release zip + unzipped     [ignored]
temp/                  pipeline intermediates                     [ignored]
output/                the task measures + figures                [in git]
```

**The repo is self-contained: it runs offline, with no downloads.** The three
xlsx per data year are committed (~24 MB per year, ~170 MB total, largest
file 17 MB). The full release zips are *not*: they would nearly double that
(~320 MB), and the 24.1 zip alone exceeds GitHub's 50 MB per-file warning.
`01_download_onet.do` re-downloads a release into the gitignored `raw/` cache
only when a year's xlsx are missing — e.g. after adding a new data year.
`temp/` is likewise regenerated in full by steps 03–06; nothing in it is a
source of truth.

## Crosswalk chain

```
2019:       O*NET-SOC 2010 → SOC 2010 → ISCO-08 → FEOR-08
2020–2025:  O*NET-SOC 2019 → SOC 2018 → SOC 2010 → ISCO-08 → FEOR-08
```

For 2020–2025 the two SOC legs are needed because those releases use the
O\*NET-SOC 2019 taxonomy (built on 2018 SOC), while the repo's ISCO-08
crosswalk is keyed to 2010 SOC; there is no direct SOC-2018 → ISCO-08
crosswalk, so it routes through the official BLS SOC-2010 ↔ ISCO-08 mapping.

Data year 2019 (release 24.1) is still on the O\*NET-SOC **2010** taxonomy and
skips both 2018-SOC legs. Its O\*NET-SOC → SOC 2010 step needs no crosswalk
file: by construction, the first 7 characters of an O\*NET-SOC 2010 code
(`XX-XXXX.YY`) *are* its 2010 SOC code, and step 06 takes the substring.
(O\*NET publishes no downloadable 2010-taxonomy → SOC crosswalk, so this is
also the only option.)

At every leg, occupations that map many-to-one are aggregated with an
**unweighted mean** (`joinby` expands all matches, then `collapse (mean)`).

## Data sources and provenance

All inputs come from official sources and all are committed, so the pipeline
needs no network access.

### The O\*NET database

| Data | Source | Handled by |
|------|--------|-----------|
| O\*NET database (Excel) — Abilities, Work Activities, Work Context | [O\*NET Center database releases](https://www.onetcenter.org/database.html) → `db_<ver>_excel.zip` | `01_download_onet.do` |

**Version policy:** each data year uses that year's **final (November)
release**:

| Data year | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|-----------|------|------|------|------|------|------|------|
| O\*NET release | 24.1 | 25.1 | 26.1 | 27.1 | 28.1 | 29.1 | 30.1 |

Release 24.1 is the last on the **O\*NET-SOC 2010** taxonomy; 25.0+ use
O\*NET-SOC 2019, which is why 2019 has its own crosswalk chain. To add a data
year, extend the year → release map at the top of `01_download_onet.do` and
the `years` macro in `00_master.do`.

### Built from raw sources (legs 1–3)

`02_build_crosswalks.do` builds these from the raw files in
`input/crosswalks/raw/`, so they are reproducible rather than taken on trust:

| Leg | Crosswalk | Raw source | How it gets there |
|-----|-----------|------------|-------------------|
| 1 | O\*NET-SOC 2019 → SOC 2018 | `2019_to_SOC_Crosswalk.xlsx` | downloaded by step 02 |
| 2 | SOC 2010 ↔ SOC 2018 | `soc_2010_to_2018_crosswalk.xlsx` | committed |
| 3 | SOC 2010 ↔ ISCO-08 | `ISCO_SOC_Crosswalk.xls` | committed |

The two BLS files are committed rather than fetched because BLS returns
**HTTP 403** to `curl` and Stata's `copy` — the links below are correct but
succeed only from an interactive browser session.

| Leg | Landing page | Direct file |
|-----|--------------|-------------|
| 2 | [BLS 2018 SOC crosswalks](https://www.bls.gov/soc/2018/crosswalks.htm) | `https://www.bls.gov/soc/2018/soc_2010_to_2018_crosswalk.xlsx` |
| 3 | [BLS 2010 SOC crosswalks](https://www.bls.gov/soc/soccrosswalks.htm) | `https://www.bls.gov/soc/ISCO_SOC_Crosswalk.xls` |

Two decisions in leg 3:

- **Minor-group expansion.** BLS maps a few SOC codes to a 3-digit ISCO
  *minor group* instead of a 4-digit unit group (currently `211` and `315`).
  The pipeline joins on 4-digit `isco08`, so those rows would silently match
  nothing and the occupations would vanish. Each minor group is expanded to
  every unit group it contains, using the ISCO→FEOR crosswalk as the list of
  valid unit groups. The minor-group test is on **string length**, not
  numeric value: the armed-forces codes `0110`/`0210`/`0310` are genuine
  4-digit unit groups whose leading zero `real()` silently drops.
- **SOC 29-2055 restored.** The previously shipped `soc10_isco08.dta` omitted
  Surgical Technologists → ISCO 3259 with no rule accounting for it, so that
  occupation's task content reached no Hungarian occupation at all. The
  rebuild restores it; apart from this it reproduces the previously shipped
  crosswalks **exactly** — legs 1 and 2 row-for-row, leg 3 with this single
  addition. It moves one FEOR code: `3339` (*Egyéb, humánegészségügyhöz
  kapcsolódó foglalkozások*), by at most 0.065 SD.

### Transcribed from the KSH PDF (leg 4)

KSH publishes the ISCO-08 → FEOR-08 mapping only as a **PDF** (committed at
`input/crosswalks/raw/fordkulcs_isco_feor_hu.pdf`), which Stata cannot read.
The committed CSV next to it is a faithful transcription of the PDF's table
(548 rows: 536 mappings plus 12 ISCO unit groups KSH marks as having no
FEOR-08 counterpart), produced by `code/extract_isco08_feor08_pdf.py`
(Python + pdfplumber). The script is not part of the Stata pipeline — it
documents how the CSV was made and can be re-run to verify it against the
PDF. `02_build_crosswalks.do` builds `crosswalk_isco08_feor08.dta` from the
CSV.

| Leg | Landing page | Direct file |
|-----|--------------|-------------|
| 4 | [KSH FEOR-08 menu](https://www.ksh.hu/feor_menu) | `https://www.ksh.hu/docs/osztalyozasok/feor/fordkulcs_isco_feor_hu.pdf` (ISCO→FEOR), [methodology](https://www.ksh.hu/docs/osztalyozasok/feor/feor_isco_modsz_utmut_2013_12_19.pdf) |

**The rebuild vs. the previously shipped file.** The previously shipped
`.dta` (provenance unknown) differed from the PDF by seven mappings: four PDF
rows were missing from it — `3341→3161`, `4412→3161`, `6111→6114`,
`6113→6113` — and three rows it contained appear nowhere in the PDF:
`1112→1121`, `3119→3134`, `3432→3715`. Its titles also carried typos absent
from the PDF (e.g. *Víhordók* for *Vízhordók*), suggesting a hand
transcription or a different revision. The rebuild follows the committed PDF
exactly. Downstream, FEOR `3134` loses its only ISCO source (`3119`) and
drops out of the output; the set of 4-digit ISCO unit groups — which leg 3's
minor-group expansion relies on — is identical in both versions.

## Output

For each definition (`<def>` = `acemoglu-autor-2011`, `autor-dorn-2013`):

- `output/<year>/<def>/task_measures_feor08.dta` — one file per data year;
  one row per FEOR-08 code, the definition's composites in raw (`task_*`) and
  standardized (`task_*_z`) form, plus `feor_08` and `feor_08_name`.
- `output/<def>/task_measures_feor08_panel.dta` — the seven years stacked
  long, one row per FEOR-08 code × `year`.
- `output/<def>/task_trends_feor1*.png` — the two trend figures shown under
  [Task definitions](#task-definitions).

These files are committed, so the measures can be used without running Stata.

**Cross-year comparability caveat:** the composites are standardized *within*
each year's release (step 05). A value is an occupation's relative position
among that year's occupations; changes across years are changes in relative
position, not in task levels.

### FEOR-08 coverage

The official FEOR-08 nomenclature ([KSH structure listing](https://www.ksh.hu/docs/szolgaltatasok/hun/feor08/feorlista.html))
has **485** four-digit occupations; the 2022 output covers **470** of them
(97%). The audit below was done in full for data year 2022; the other years
differ only at the margin (verified from the built outputs, 2026-07-16):

| Years | Codes | Difference vs 2022 |
|-------|-------|--------------------|
| 2020–2023 | 470 | — |
| 2019 | 471 | gains `2226` (EMTs are the single rated 29-2041 under the 2010 taxonomy) and `3410`; loses `0310` (its lone source, 55-3017, is an unrated military code before the SOC-2018 reclassification — see the `0310` caveat below) |
| 2024–2025 | 471 | gains `3410` (its SOC sources are rated from release 29.1 on) |

The 15 codes missing in 2022 are structural, not pipeline defects:

**No ISCO source in the KSH crosswalk (1 code).** FEOR `3134`
(*Környezetvédelmi technikus*) is never assigned from any ISCO unit group in
the fordítókulcs. (The previously shipped crosswalk patched this with a
`3119→3134` mapping that has no basis in the published key — see the leg-4
rebuild note above.)

**Mapped, but no O\*NET data behind any source (14 codes).** These trace back
exclusively to SOC occupations the O\*NET release never rates — its three
known blind spots:

| FEOR | Blind spot |
|------|-----------|
| `0110`, `0210` (military officers / NCOs) | O\*NET rates no military (SOC 55-) occupation |
| `1110`, `1122` (törvényhozó; választott önkormányzati vezető) | ← ISCO 1111 ← SOC 11-1031 *Legislators*, unrated in O\*NET |
| `2226` (mentőtiszt) | ← EMTs/Paramedics 29-2042/43, a 2018 SOC split not yet rated in the 2022 release |
| `2728`, `2729`, `3410`, `3730`, `4213`, `7915`, `8123`, `9222`, `9238` | fed only by SOC "All Other" residual codes, which O\*NET never rates |

The absence was verified in the raw O\*NET source files themselves (the
occupations are missing from Abilities / Work Activities / Work Context
entirely); the pipeline drops nothing on its own.

**Caveat — FEOR `0310`.** The third military code *does* receive measures
(from 2020 on), but only because one of its nine SOC 2010 sources (55-3017,
*Radar and Sonar Technicians*) was reclassified to the civilian, rated code
17-3029 in SOC 2018. Its task content rests on a single, arguably
unrepresentative source; treat it with care alongside the deliberately
missing `0110`/`0210`.

## Methodology notes / decisions

- **Aggregation is by simple mean throughout** — both when averaging
  standardized elements into a composite (step 05) and when collapsing across
  matched occupations at each crosswalk leg (step 06). This matches the
  standard task literature (Autor-Levy-Murnane 2003; Acemoglu-Autor 2011;
  Autor-Dorn 2013), which uses equal-weighted averages of standardized items
  rather than PCA/factor scores. PCA is a reasonable robustness check but not
  the default here.
- **Scales**: Importance (IM) for Abilities / Work Activities elements,
  Context (CX) for Work Context. The CXP (category-distribution) and CT/CTP
  scales in the Work Context file are dropped — a row is kept only if its
  `scaleid` matches the token's scale.
- **Reverse coding**: 4.C.3.b.8 (Structured versus Unstructured Work) is
  reversed, because a high value means high autonomy, i.e. *less* routine.
- **Occupations missing a required element are dropped, not averaged over.**
  If an occupation lacks any element the definition names, step 04 drops it
  (listing it in the log) rather than building its composite from fewer items
  than every other occupation's. The only instance across 2019–2025: O\*NET
  24.1 publishes no 4.C.3.b.8 value for 15-2091.00 *Mathematical
  Technicians*, so that occupation is absent from data year 2019.
- **No employment weighting**: the repo has no Hungarian employment counts by
  FEOR/ISCO, so all aggregation is unweighted. US employment weights would be
  wrong for the Hungarian occupational structure anyway.

## Conventions

- All paths are **relative to the project root**; do-files assume that is the
  working directory. No absolute paths, no path globals.
- Globals hold **only** the task specification (`$taskdef_name`, `$taskcats`,
  `$els_*`, `$rev_els`, `$lab_*`), never file paths. Each `taskdef_*.do`
  drops the previous definition's globals before setting its own, so nothing
  leaks between definitions in a multi-definition run.
- The data year is a **do-file argument** (`args year`), not a global; steps
  01 and 03–07 default to 2022 (07: to all years) when run standalone.
- Steps 04–08 self-load the default task definition if run standalone with no
  definition in memory.

## Task definitions

Every definition lists its elements as `SCALE:ELEMENTID` tokens, where
`SCALE` is the O\*NET scale to read — `IM` (Importance) for Abilities / Work
Activities, `CX` (Context) for Work Context.

For each definition, step 08 draws the panel in two views: yearly trends by
1-digit FEOR major group (first digit of `feor_08`, English glosses of the
KSH group names; each line the unweighted mean of a `task_*_z` across the
group's 4-digit codes), and the transpose — one panel per task measure, one
line per group. Major group 0 (armed forces) is excluded from the figures:
two of its three codes are never rated in O\*NET and the third rests on a
single thin source (the `0310` caveat above), so its line would be more
artifact than signal. Per the comparability caveat, a drifting line is a
group's relative position moving, not its task content changing level — and
the flatness is itself informative: O\*NET re-rates only a slice of
occupations per release, so year-to-year movement within a group is small by
construction.

### Acemoglu & Autor (2011) — `acemoglu-autor-2011`

| Category (code) | O\*NET elements |
|-----------------|-----------------|
| Non-routine cognitive: analytical (`nrca`) | 4.A.2.a.4 Analyzing Data or Information; 4.A.2.b.2 Thinking Creatively; 4.A.4.a.1 Interpreting the Meaning of Information for Others |
| Non-routine cognitive: interpersonal (`nrci`) | 4.A.4.a.4 Establishing and Maintaining Interpersonal Relationships; 4.A.4.b.4 Guiding, Directing, and Motivating Subordinates; 4.A.4.b.5 Coaching and Developing Others |
| Routine cognitive (`rc`) | 4.C.3.b.7 Importance of Repeating Same Tasks; 4.C.3.b.4 Importance of Being Exact or Accurate; 4.C.3.b.8 Structured versus Unstructured Work *(reverse-coded)* |
| Routine manual (`rm`) | 4.C.3.d.3 Pace Determined by Speed of Equipment; 4.A.3.a.3 Controlling Machines and Processes; 4.C.2.d.1.i Spend Time Making Repetitive Motions |
| Non-routine manual: physical (`nrmp`) | 4.A.3.a.4 Operating Vehicles, Mechanized Devices, or Equipment; 4.C.2.d.1.g Spend Time Using Your Hands to Handle, Control, or Feel Objects; 1.A.2.a.2 Manual Dexterity; 1.A.1.f.1 Spatial Orientation |

Reference: Acemoglu, D. & Autor, D. (2011), "Skills, Tasks and Technologies:
Implications for Employment and Earnings", *Handbook of Labor Economics* 4B.

![Yearly trend of the five task composites by 1-digit FEOR-08 major group, 2019–2025](output/acemoglu-autor-2011/task_trends_feor1.png)

![Yearly trend by task measure, lines by FEOR-08 major group](output/acemoglu-autor-2011/task_trends_feor1_by_task.png)

### Autor & Dorn (2013) — `autor-dorn-2013`

The three task aggregates behind Autor & Dorn's routine task intensity (RTI)
index. **Provenance caveat:** the original Autor–Dorn measures come from the
1977 DOT, not O\*NET; this is the standard O\*NET adaptation used in the later
literature, building the aggregates from the same 16 elements as the
Acemoglu–Autor composites — only the grouping differs:

| Category (code) | Composition |
|-----------------|-------------|
| Abstract (`abstract`) | the `nrca` + `nrci` elements (6) |
| Routine (`routine`) | the `rc` + `rm` elements (6), 4.C.3.b.8 reverse-coded as above |
| Manual (`manual`) | the `nrmp` elements (4) |

RTI itself is deliberately not in the output. The original
`ln(R) − ln(A) − ln(M)` is undefined for standardized scores, and the
literature's z-score version is a linear combination —

```stata
generate rti = task_routine_z - task_abstract_z - task_manual_z
```

— which commutes with the unweighted means used at every crosswalk leg, so
building it from the FEOR-level output (one line, above) is identical to
crosswalking an occupation-level RTI.

Reference: Autor, D. & Dorn, D. (2013), "The Growth of Low-Skill Service Jobs
and the Polarization of the US Labor Market", *American Economic Review*
103(5).

![Yearly trend of the Autor–Dorn task aggregates by 1-digit FEOR-08 major group, 2019–2025](output/autor-dorn-2013/task_trends_feor1.png)

![Yearly trend by Autor–Dorn task aggregate, lines by FEOR-08 major group](output/autor-dorn-2013/task_trends_feor1_by_task.png)

### Adding a task definition

1. Copy `taskdef_acemoglu_autor_2011.do` to e.g. `taskdef_myversion.do`.
2. Set `$taskdef_name` to a filesystem-safe slug (e.g. `my-version`). It
   names the definition's output folder, so definitions never overwrite each
   other.
3. Edit the element lists (`$els_*`), the category list (`$taskcats`), the
   reverse-code list (`$rev_els`), and the labels (`$lab_*`). Categories can
   be added or removed freely — the engine adapts.
4. Add the suffix to the `defs` macro in `00_master.do`:

```stata
local defs "acemoglu_autor_2011 autor_dorn_2013 myversion"
```

That's all. Every definition is then built in one run, each writing to its
own `output/<year>/<slug>/` folders plus a panel and figures. The O\*NET
Excel files are parsed once per year (step 03) and shared by all, and no step
outside the `taskdef_*.do` files needs editing.

## Licence

The **code** in this repository is released under the [MIT Licence](LICENSE).

The **data** carries the terms of its original publishers, not the MIT licence:

- **O\*NET** data is published by the U.S. Department of Labor, Employment and
  Training Administration under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  O\*NET® is a trademark of USDOL/ETA.
- **BLS** crosswalks (SOC 2010 ↔ 2018, SOC ↔ ISCO-08) are U.S. Government works
  in the public domain.
- **KSH** FEOR-08 material is published by the Hungarian Central Statistical
  Office under its own terms.

If you use these measures, cite the paper behind the task definition you use
(Acemoglu & Autor 2011; Autor & Dorn 2013) and the O\*NET database release
for the underlying data.
