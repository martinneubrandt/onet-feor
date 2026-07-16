#!/usr/bin/env python3
# ============================================================================
# One-time extraction: KSH ISCO-08 -> FEOR-08 fordítókulcs PDF -> CSV
# ============================================================================
# Parses input/crosswalks/raw/fordkulcs_isco_feor_hu.pdf into
# input/crosswalks/raw/fordkulcs_isco_feor_hu.csv, which is committed and is
# what 02_build_crosswalks.do actually reads (leg 4). This script is NOT part
# of the Stata pipeline; it documents how the CSV was produced and can be
# re-run to verify the CSV against the PDF. Requires: pdfplumber.
#
# The PDF is a 12-page, 4-column ruled table (ISCO code | ISCO name | FEOR
# code | FEOR name). pdfplumber's own table detection mangles the pages where
# the header/first-row rule does not cross the ISCO code column (3, 4, 5, 7,
# 10, 12), so rows are reconstructed manually instead: every row boundary is
# a ruled horizontal line spanning the table, words are binned into rows by
# those lines and into columns by the vertical lines' x positions. The
# bottom-centre page number, which sits at the same height as the last table
# row, is dropped explicitly.
#
# Codes are written as 4-character strings: the armed-forces codes
# 0110/0210/0310 carry a leading zero that any numeric round-trip destroys.
# ISCO codes with no FEOR counterpart (marked blue in the PDF) are kept with
# empty FEOR columns.
#
# Run from the project root:  python3 code/extract_isco08_feor08_pdf.py
# ============================================================================

import csv
import re
import sys
from collections import defaultdict

import pdfplumber

PDF = "input/crosswalks/raw/fordkulcs_isco_feor_hu.pdf"
CSV = "input/crosswalks/raw/fordkulcs_isco_feor_hu.csv"

# Column boundaries, from the table's vertical ruled lines (constant across
# all 12 pages): 18 | 45 | 299 | 327 | 580.
COL_CUTS = (45, 299, 327)  # isco code | isco name | feor code | feor name

CODE_RE = re.compile(r"^\d{4}$")
PAGENUM_RE = re.compile(r"^\d{1,2}\.$")

# Page-1 banner rows, identified by content; the per-page header row consists
# solely of the two words dropped in HEADER_WORDS.
BANNER_SNIPPETS = ("fordítókulcs", "Sárgával", "Kékkel")
HEADER_WORDS = {"ISCO-08", "FEOR-08"}


def column(word):
    """Column index 0-3 for a word, from its left edge."""
    x = word["x0"]
    for i, cut in enumerate(COL_CUTS):
        if x < cut:
            return i
    return 3


def split_at_cuts(word):
    """Split a word whose bbox crosses a column boundary.

    The ISCO name column is justified, so its last word can end flush against
    the ruled line at x=299 with less than a space's gap to the FEOR code
    beyond it; extract_words then fuses them into one word
    ("technológiai1322"). Splitting the word's characters at the boundary
    undoes that.

    Only a split that separates a code from text is real: a long name in an
    unmapped (blue) row may itself overflow the ruled line ("gyűjtögetők" on
    page 8 crosses x=299) and must stay whole.
    """
    for cut in COL_CUTS:
        if word["x0"] < cut < word["x1"]:
            left = [c for c in word["chars"] if (c["x0"] + c["x1"]) / 2 < cut]
            right = [c for c in word["chars"] if (c["x0"] + c["x1"]) / 2 >= cut]
            if left and right and (
                all(c["text"].isdigit() for c in left)
                or all(c["text"].isdigit() for c in right)
            ):
                halves = []
                for chars in (left, right):
                    halves.append(
                        {
                            "text": "".join(c["text"] for c in chars),
                            "x0": chars[0]["x0"],
                            "x1": chars[-1]["x1"],
                            "top": word["top"],
                            "bottom": word["bottom"],
                            "chars": chars,
                        }
                    )
                return split_at_cuts(halves[0]) + split_at_cuts(halves[1])
    return [word]


def row_boundaries(page):
    """y positions of the ruled lines separating table rows.

    Horizontal edges at the same (rounded) height are merged and kept if they
    span the table width. The header/first-row rule starts at x=45 instead of
    x=18 on some pages, hence the loose left limit; boundaries closer than
    4pt are duplicates from rounding.
    """
    spans = defaultdict(lambda: [1e9, 0.0])
    for e in page.horizontal_edges:
        s = spans[round(e["top"])]
        s[0] = min(s[0], e["x0"])
        s[1] = max(s[1], e["x1"])
    ys = [y for y, (a, b) in sorted(spans.items()) if a < 60 and b > 570]
    merged = []
    for y in ys:
        if not merged or y - merged[-1] >= 4:
            merged.append(y)
    return merged


def rows_on(page):
    """The page's table rows, each as a list of 4 cell strings."""
    words = [
        w
        for word in page.extract_words(return_chars=True)
        # Drop the bottom-centre page number ("1." ... "12."), which sits at
        # the same height as the last table row, and the column headers,
        # which share a row bin with data on the pages where the header rule
        # does not span the ISCO code column.
        if not (
            PAGENUM_RE.match(word["text"])
            and word["top"] > 805
            and 280 < word["x0"] < 310
        )
        and word["text"] not in HEADER_WORDS
        for w in split_at_cuts(word)
    ]

    bounds = row_boundaries(page)
    bins = defaultdict(list)
    for w in words:
        mid = (w["top"] + w["bottom"]) / 2
        i = sum(1 for y in bounds if y < mid)  # 0 = above the table
        bins[i].append(w)

    rows = []
    for i in sorted(bins):
        # Reading order within the row: line by line, left to right. Words
        # are clustered into lines by the gap between their tops - sorting
        # on the raw top alone misorders words whose accented glyphs (ő, ű)
        # rise a fraction above their neighbours'.
        ordered, prev_top = [], None
        for w in sorted(bins[i], key=lambda w: w["top"]):
            if prev_top is None or w["top"] - prev_top > 5:
                ordered.append([])
            ordered[-1].append(w)
            prev_top = w["top"]
        cells = ["", "", "", ""]
        for line in ordered:
            for w in sorted(line, key=lambda w: w["x0"]):
                c = column(w)
                cells[c] = f"{cells[c]} {w['text']}".strip() if cells[c] else w["text"]
        # A line break directly after a compound-word hyphen ("... és -" /
        # "vésők") leaves the hyphen as its own word; reattach it.
        cells = [re.sub(r"(?<= )- (?=\S)", "-", c) for c in cells]
        text = " ".join(filter(None, cells))
        if text and not any(s in text for s in BANNER_SNIPPETS):
            rows.append(cells)
    return rows


def main():
    rows = []      # finished [isco, isco_name, feor, feor_name] rows
    current = None # row still being assembled (names may wrap across pages)

    with pdfplumber.open(PDF) as pdf:
        for page in pdf.pages:
            for cells in rows_on(page):
                if cells[0]:
                    # New logical row, opened by an ISCO code.
                    if not CODE_RE.match(cells[0]):
                        sys.exit(f"bad ISCO code cell: {cells!r}")
                    if cells[2] and not CODE_RE.match(cells[2]):
                        sys.exit(f"bad FEOR code cell: {cells!r}")
                    if current:
                        rows.append(current)
                    current = cells
                elif cells[2]:
                    # FEOR code without an ISCO code: the FEOR half of a row
                    # whose ISCO half stayed on the previous page.
                    if not CODE_RE.match(cells[2]):
                        sys.exit(f"bad FEOR code cell: {cells!r}")
                    if current is None or current[2]:
                        sys.exit(f"orphan FEOR cell: {cells!r}")
                    current[2] = cells[2]
                    current[3] = cells[3]
                else:
                    # A row's name(s) wrapped onto the next page.
                    if current is None:
                        sys.exit(f"continuation with no open row: {cells!r}")
                    for i in (1, 3):
                        if cells[i]:
                            current[i] = f"{current[i]} {cells[i]}".strip()
    if current:
        rows.append(current)

    with open(CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["isco08", "isco_name", "feor_08", "feor_08_name"])
        writer.writerows(rows)

    n_unmapped = sum(1 for r in rows if not r[2])
    print(f"{CSV}: {len(rows)} rows, {n_unmapped} ISCO codes with no FEOR mapping")


if __name__ == "__main__":
    main()
