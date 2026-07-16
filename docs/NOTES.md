# Notes: provenance details and coverage audit

Companion to the [README](../README.md) — the crosswalk decisions and the
FEOR-08 coverage audit in full.

## Leg 3: minor-group expansion

BLS maps a few SOC codes to a 3-digit ISCO *minor group* instead of a
4-digit unit group (currently `211` and `315`). The pipeline joins on
4-digit `isco08`, so those rows would silently match nothing and the
occupations would vanish. `02_build_crosswalks.do` expands each minor group
to every unit group it contains, using the ISCO→FEOR crosswalk as the list
of valid unit groups. The minor-group test is on **string length**, not
numeric value: the armed-forces codes `0110`/`0210`/`0310` are genuine
4-digit unit groups whose leading zero `real()` silently drops.

## Leg 4: the KSH PDF transcription

KSH publishes the ISCO-08 → FEOR-08 mapping only as a PDF, which Stata
cannot read. The committed `fordkulcs_isco_feor_hu.csv` is a faithful
transcription of the PDF's table — 548 rows: 536 mappings plus 12 ISCO unit
groups KSH marks as having no FEOR-08 counterpart — produced by
`code/extract_isco08_feor08_pdf.py` (Python + pdfplumber). The script is not
part of the Stata pipeline; it documents how the CSV was made and can be
re-run to verify it against the PDF.

## FEOR-08 coverage

The official FEOR-08 nomenclature ([KSH structure listing](https://www.ksh.hu/docs/szolgaltatasok/hun/feor08/feorlista.html))
has **485** four-digit occupations; the 2022 output covers **470** of them
(97%). The audit below was done in full for data year 2022; the other years
differ only at the margin:

| Years | Codes | Difference vs 2022 |
|-------|-------|--------------------|
| 2020–2023 | 470 | — |
| 2019 | 471 | gains `2226` (EMTs are the single rated 29-2041 under the 2010 taxonomy) and `3410`; loses `0310` (its lone source, 55-3017, is an unrated military code before the SOC-2018 reclassification — see the `0310` caveat below) |
| 2024–2025 | 471 | gains `3410` (its SOC sources are rated from release 29.1 on) |

The 15 codes missing in 2022 are structural, not pipeline defects:

**No ISCO source in the KSH crosswalk (1 code).** FEOR `3134`
(*Környezetvédelmi technikus*) is never assigned from any ISCO unit group in
the fordítókulcs.

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
