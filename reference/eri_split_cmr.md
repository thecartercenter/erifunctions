# Split a CMR monthly report into per-disease, per-measure staged datasets

**\[experimental\]**

Reads every sheet a country's CMR schema routes (those declaring a
`disease` and a `data_type`), and writes each sheet's parsed rows to
`data/{country}/{disease}/programmatic/{data_type}/staged/` in the
`data` blob (ADR-0012, \#175). The **disease comes from the sheet**
(e.g. `RB Treatment` → `oncho`, `SCH Treatment` → `sch`, `LF MMDP` →
`lf`); cross-programme Training sheets route together under the combined
`rblf` disease. The per-row `#..._disease` field — which holds
program-coverage codes (`RB` / `RBLF` / `RBLFSCH`) — is kept as a data
column, **not** split on, so no row is duplicated across diseases.

Data is staged **parsed as-is** (machine-readable `#field-code` columns;
no reshape, no automated DQ — CMR review is manual).
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
then promotes each `{disease}/programmatic/{data_type}` to `processed/`.

If `country` has no bundled CMR schema, this does not just abort: it
also writes a starter schema template for that country to the working
directory (the same template
[`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
produces) so the failure leaves you with something to edit and submit,
not just a dead end.

### Mirroring to the legacy contractor pipeline

During the Phase-3 parallel run, some countries' CMR still also feeds a
legacy contractor process that reads the raw workbook from a fixed Azure
location (`{project_folder}/{raw_dir}/{country}/{period}/`, e.g.
`health-rb-country-expansion-dev/raw/filled_templates/ssd/202605/`).
Passing `mirror_pipeline` uploads `path` there too, so a DA does **one
step** (`eri_split_cmr(..., mirror_pipeline = "rb-expansion")`) instead
of also separately dropping the file for the legacy pipeline to pick up.
`period` defaults to a `YYYYMM` prefix parsed from `basename(path)` (the
real convention observed in submitted filenames); pass it explicitly if
the filename doesn't start that way.

This does **not** replace
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md):
that function reads the *same* raw-drop location and copies the workbook
into `data/{country}/rblf/cmr/staged/` as the governed raw archive
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
promotes. `mirror_pipeline` here only *writes* to the raw-drop location
for the legacy pipeline's benefit — a DA doing a fresh-period pilot run
may still want both: `eri_split_cmr(..., mirror_pipeline = ...)` then
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
(or the reverse order; neither depends on the other having run first).

### Re-splitting the same period from a corrected file

If you fix an issue upstream and re-run this on a different local file
(e.g. the `_fixed.xlsx` copy convention) for a period already split, the
prior staged file(s) for each sheet's destination folder are removed
first (when `period` is known) – otherwise both the broken original and
the corrected file would sit in `staged/` together, and
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)'s
period-substring match would promote both. Each removal is logged as a
`supersede_staged` step.

## Usage

``` r
eri_split_cmr(
  path,
  country,
  data_con = NULL,
  overwrite = FALSE,
  dry_run = FALSE,
  mirror_pipeline = NULL,
  period = NULL,
  projects_con = NULL,
  supersede_staged = FALSE
)
```

## Arguments

- path:

  `str` Local path to the CMR Excel file.

- country:

  `str` Three-letter country code (e.g. `"uga"`); resolves the CMR
  schema via
  [`load_cmr_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_cmr_schema.md).

- data_con:

  Azure container for the `data` blob. `NULL` connects using
  `ERIFUNCTIONS_DATA_STORAGE_NAME`.

- overwrite:

  `logical` If `FALSE` (default), warns before overwriting an existing
  staged file.

- dry_run:

  `logical` If `TRUE`, returns the routing plan and writes no *data*.
  Default `FALSE`. One exception: if the dry run finds a skipped sheet
  or a warning, that fact **is** logged (a lightweight triage entry, not
  staged data) so there's a stable `log_path` to attach an
  [`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
  note to later – see step 3 of the CMR guide.

- mirror_pipeline:

  `str` or `NULL` Registered pipeline name (e.g. `"rb-expansion"`) whose
  legacy raw-drop location `path` should also be uploaded to. Default
  `NULL` (no mirror; sandbox-safe).

- period:

  `str` or `NULL` Reporting period (e.g. `"202605"`), used to tag the
  op-log (so
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md)
  can find this run again) and, if `mirror_pipeline` is set, the mirror
  upload. `NULL` (default) parses a leading `YYYYMM_` from
  `basename(path)`; only required to be resolvable when
  `mirror_pipeline` is set.

- projects_con:

  Azure container for the `projects` blob; used only when
  `mirror_pipeline` is set. If `NULL`, connects automatically.

- supersede_staged:

  `logical` Re-splitting the same period from a DIFFERENT local file
  (e.g. a `_fixed.xlsx` correction) can leave a prior staged file behind
  in each destination folder –
  [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)'s
  period match would then promote both to `processed/`. When `period` is
  known, candidate stale files (their name starts with `period`, not
  just contains it anywhere – the real filename convention, so this
  doesn't collide with an unrelated file that merely mentions those six
  digits) are always detected and reported. Default `FALSE` only warns
  about them – **this package's first destructive Azure operation is
  opt-in, not automatic**; set `TRUE` to actually delete them. Ignored
  (nothing detected or deleted) when `period` couldn't be resolved.

## Value

Invisibly, a tibble with one row per routed sheet: `sheet`, `disease`,
`data_type`, `dest`, `n_rows`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Preview where each sheet would land
eri_split_cmr("uga_2024_06.xlsx", "uga", dry_run = TRUE)
# Stage for real, then approve each disease/measure
eri_split_cmr("uga_2024_06.xlsx", "uga")
eri_approve("uga", "oncho", "programmatic", "2024-06", data_type = "treatment")
# One step: also mirror the raw file to the legacy contractor pipeline
eri_split_cmr("202605_ssd_report.xlsx", "ssd", mirror_pipeline = "rb-expansion")
# Re-splitting a corrected file for a period already staged: opt in to
# actually removing the superseded original (default only warns)
eri_split_cmr("202605_ssd_report_fixed.xlsx", "ssd", supersede_staged = TRUE)
} # }
```
