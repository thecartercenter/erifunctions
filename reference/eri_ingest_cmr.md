# Read and parse a CMR monthly report Excel file

**\[experimental\]**

Reads a single sheet from a Carter Center RBLF monthly report template,
using the machine-readable field code row (row 5 of the template) as
column names. Field codes (e.g. `#rbtrt_year`, `#rbtrt_adm1`) are
consistent across all country templates regardless of language, so the
same function parses both English and French templates.

### Template structure assumed

|     |                                                    |
|-----|----------------------------------------------------|
| Row | Content                                            |
| 1   | Sheet title                                        |
| 2   | Empty spacer                                       |
| 3   | Group headers (Location / Targets / Month columns) |
| 4   | Human-readable column names                        |
| 5   | Machine-readable field codes — **parsing anchor**  |
| 6+  | Data                                               |

## Usage

``` r
eri_ingest_cmr(path, sheet, country = NULL)
```

## Arguments

- path:

  `str` Local path to the CMR Excel file.

- sheet:

  `str` or `int` Sheet name, 1-based index, or canonical slug (e.g.
  `"rb_treatment"`). Slugs are resolved to actual sheet names via the
  country schema's `sheet_aliases` block when `country` is supplied.

- country:

  `str` or `NULL` Optional country code (e.g. `"tcd"`, `"uga"`). When
  supplied, the country code is prepended as a `country` column and slug
  aliases are resolved. Default `NULL`.

## Value

A tibble with field-code column names and data from row 6 onward, plus
an `excel_row` column recording each row's real position in the workbook
(survives all-NA spacer-row dropping, so it stays accurate even after
rows are removed). If `country` is supplied it is prepended as a
`country` column.

## Examples

``` r
if (FALSE) { # \dontrun{
# English template — sheet name directly
df <- eri_ingest_cmr("data/uga_2024_01.xlsx", sheet = "RB Treatment", country = "uga")
# French template — canonical slug resolved via schema
df <- eri_ingest_cmr("data/tcd_2024_01.xlsx", sheet = "rb_treatment", country = "tcd")
} # }
```
