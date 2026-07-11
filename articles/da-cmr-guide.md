# Uploading and processing a monthly country report (CMR) (for data analysts)

Every month, country programmes file a **Case Management Report (CMR)**,
a filled Excel template of treatment, training, and survey numbers. This
guide, for a **Data Analyst**, walks the monthly job: take that incoming
Excel, **upload** it to Azure, **stage** it, **parse** each sheet, and
**approve** it into the governed data system.

The trick that makes it manageable: every CMR template has a row of
**machine-readable field codes** (`#rbtrt_year`, `#rbtrt_treated`, …).
Those codes are identical across countries *and languages*, so one
function parses an English Ugandan template and a French Chadian one
exactly the same way.

> **The golden rule is the same as every other dataset.** The report
> moves `projects/ (as filed)` → `staged/` → `processed/`, and nothing
> becomes canonical until you
> [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
> it. This is the CMR sibling of the [surveillance ingest
> guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md).

flowchart TD A\["Country files the monthly CMR Excel"\] --\> B\["Upload
to the projects blob"\] B --\> C\["eri_stage_cmr(): projects -\>
staged/"\] C --\> D\["eri_ingest_cmr(): parse each sheet by its \#field
codes"\] D --\> E\["Review the numbers"\] E --\> F\["eri_split_cmr():
route each sheet to {disease}/programmatic/{measure}/staged/"\] F --\>
G\["eri_cmr_dq_report(): one combined flags tibble across every
measure"\] G --\> H\["eri_dq_flag_resolve() issue by issue, then
eri_logs_resolve() each measure"\] H --\> I\["eri_approve_cmr(): approve
everything at once, only if all clean"\]

## Before you start

- `remotes::install_github("thecartercenter/erifunctions")`.
- **Azure access** for the upload / stage / approve steps (zero-config
  browser sign-in, see the [connections
  guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)).
  The **parsing** step
  ([`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md))
  is offline, it just reads a local Excel file.

``` r

library(erifunctions)
```

> **A note on the examples below.** The upload, stage, and approve steps
> run against the live Azure `projects`/`data` blobs and real,
> registered countries, so the outputs for those are shown as
> illustrations rather than run here. Unlike the surveillance and ODK
> guides, there is **no throwaway-sandbox path** for stage/approve:
> [`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
> only accepts a registered RB-expansion country (it rejects a made-up
> one). The **parsing** step *is* run for real on a small **synthetic**
> example report that ships with the package, so that output is exactly
> what you’ll see.

## 1. Where the report comes in

A filled monthly template lands in the **`projects` blob**, under a
per-country, per-period folder. The period is a six-digit `YYYYMM`:

    projects: health-rb-country-expansion-dev/raw/filled_templates/{country}/{period}/{file}.xlsx
    e.g.      …/raw/filled_templates/uga/202406/uga_cmr_2024_06.xlsx

Do this from R with
[`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md),
it keeps the whole monthly run in one place and one tool. (If a file
already arrived via Azure Storage Explorer or SharePoint, that’s fine
too; you can skip ahead to staging.) Connect to the `projects` blob and
upload the file to that path:

``` r

# Connect to the projects blob explicitly (the same blob eri_stage_cmr reads from).
projects_con <- get_azure_storage_connection(storage_name = "projects")

eri_upload(
  "uga_cmr_2024_06.xlsx",
  "health-rb-country-expansion-dev/raw/filled_templates/uga/202406/uga_cmr_2024_06.xlsx",
  azcontainer = projects_con
)
# (uploads the file; no console output)
```

### What the template looks like

Every CMR sheet has the same shape, a few rows of human-readable
headers, then the **field-code row**, then the data:

| Excel row | Contents |
|----|----|
| 1–4 | Title, group headers, human-readable column names |
| **5** | **`#field codes`** (e.g. `#rbtrt_year`, `#rbtrt_adm1`, `#rbtrt_treated`), the parsing anchor |
| 6+ | The monthly numbers |

That row 5 is what makes the whole thing work, as you’ll see in §3.

## 2. Stage it

[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
pulls the filed Excel(s) out of the `projects` blob and copies them into
the governed `data` blob’s `staged/` layer, ready for review. Give it
the country and the period:

``` r

eri_stage_cmr("uga", "202406")
#> ✔ Staged: uga_cmr_2024_06.xlsx
#> ── ✔ Staged CMR to data blob ──────────────────────────────
#> Files: 1
#> Location: uga/rblf/cmr/staged
#> ℹ Operation log: uga/rblf/cmr/logs/20240705_141500_eri_stage_cmr_202406.yaml
```

Omit the period and it stages the **most recent** one for you, and says
so:

``` r

eri_stage_cmr("uga")
#> ℹ No period specified; staging most recent: 202406
#> ✔ Staged: uga_cmr_2024_06.xlsx
#> …
```

(CMR data lives under the `rblf` disease folder, RB for onchocerciasis,
LF for lymphatic filariasis, the two programmes these reports cover.
Only the registered RB-expansion countries, `eth`, `nga`, `sdn`, `ssd`,
`uga`, `mad`, `tcd`, can be staged.)

> **Heads-up on the `rblf` coordinate.** CMR always uses
> `disease = "rblf"`, the combined RB + LF programme code, so the paths
> are `{country}/rblf/cmr/…` and you approve with
> `eri_approve(country, "rblf", "cmr", period)`. Scaffolding a new
> country’s CMR with `eri_onboard_cmr(create_dirs = TRUE)` creates those
> same `{country}/rblf/cmr/` folders.
>
> **From `rblf`/`cmr` to per-disease.** `rblf`/`cmr` were interim
> coordinates: under the [source ≠ measure model
> (ADR-0012)](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0012-source-measure-data-model.md),
> CMR is a *format* of the `programmatic` channel, and
> [`eri_split_cmr()`](#split) (below) routes each sheet to its own
> disease and measure, e.g. RB Treatment →
> `{country}/oncho/programmatic/treatment/`. You then approve **each
> disease/measure**, not one combined `rblf`/`cmr` bucket.

## 3. Parse each sheet

Now the offline heart of the job. First, see which sheets this country’s
template has:

``` r

schema <- load_cmr_schema("uga")
names(schema$sheets)
#>  [1] "RB Treatment"                  "SCH Treatment"
#>  [3] "LF MMDP"                       "VHT Training"
#>  [5] "Parish Supervisors Training"   "Local Leaders Training"
#>  [7] "Subcounty Supervisor Training" "MMDP (surgery) Training"
#>  [9] "MMDP (patient) Training"       "Field Ento Training"
#> [11] "Lab Training"                  "LF Surveys"
#> [13] "RB Epi Surveys"                "RB Ento Surveys"
```

(A real monthly file has many sheets, treatments, MMDP, the various
trainings, and surveys. The bundled `cmr-example.xlsx` below is a small
**two-sheet** subset, `RB Treatment` + `SCH Treatment`, so you can run
the parse and split offline.)

Then read a sheet with
[`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md).
It reads from **row 5** (the field codes), keeps only the `#`-coded
columns, drops the template’s blank spacer rows, and, when you pass
`country`, tags each row with it. (We use the package’s bundled
synthetic example here; in real work you’d point at your staged file.)

``` r

report <- system.file("extdata", "cmr-example.xlsx", package = "erifunctions")

rb <- eri_ingest_cmr(report, sheet = "RB Treatment", country = "uga")
#> ✔ CMR sheet "RB Treatment": 3 data rows, 6 field codes.

rb
#> # A tibble: 3 × 7
#>   country `#rbtrt_year` `#rbtrt_month` `#rbtrt_adm1` `#rbtrt_adm2` `#rbtrt_target` `#rbtrt_treated`
#>   <chr>   <chr>         <chr>          <chr>         <chr>         <chr>           <chr>
#> 1 uga     2024          06             Central       Kampala       12000           11400
#> 2 uga     2024          06             Western       Mbarara       8000            7600
#> 3 uga     2024          06             Eastern       Soroti        6000            5800
```

Each sheet is its own programme, parsed the same way:

``` r

sch <- eri_ingest_cmr(report, sheet = "SCH Treatment", country = "uga")
#> ✔ CMR sheet "SCH Treatment": 2 data rows, 6 field codes.
```

The column names *are* the field codes, stable identifiers you can rely
on across every monthly file. This is the moment to eyeball the numbers
(treated vs target, missing districts) before you sign off.

> **Same codes, any language.** The field codes (`#rbtrt_…`) are
> language-neutral, so the *same*
> [`eri_ingest_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest_cmr.md)
> parses a French template too. For a French file, the sheet is named in
> French (e.g. `"Oncho Traitement"`), pass the **canonical slug** and
> the country, and the schema’s `sheet_aliases` resolves it:
>
> ``` r
>
> eri_ingest_cmr("tcd_cmr_2024_06.xlsx", sheet = "rb_treatment", country = "tcd")
> #> ✔ CMR sheet "Oncho Traitement": 24 data rows, 6 field codes.
> ```

## 4. Split it by disease and measure

The sheets are per-programme, but the canonical store is
**per-disease**.
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
reads every routable sheet and routes its rows to
`{country}/{disease}/programmatic/{measure}/staged/`: the **disease from
the sheet** (RB Treatment → `oncho`, SCH Treatment → `sch`, LF MMDP →
`lf`), the **measure from its category**. It reads the Excel
**directly** (here the bundled example; in real work the file you
uploaded), independently of the `rblf/cmr/staged/` copy
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md)
made, that copy is the raw archive; this is the parse + route. Preview
the routing first with `dry_run`:

``` r

eri_split_cmr(report, "uga", dry_run = TRUE)
#> ✔ CMR sheet "RB Treatment": 3 data rows, 6 field codes.
#> ✔ CMR sheet "SCH Treatment": 2 data rows, 6 field codes.
#> ℹ Dry run -- no data written. Routing plan:
#>   "RB Treatment"  -> uga/oncho/programmatic/treatment/staged/cmr-example_rb_treatment.parquet (3 rows)
#>   "SCH Treatment" -> uga/sch/programmatic/treatment/staged/cmr-example_sch_treatment.parquet (2 rows)
#> Warning: Sheet "LF MMDP" not found in cmr-example.xlsx; skipping.   # ...and the
#> Warning: Sheet "VHT Training" not found in cmr-example.xlsx; skipping.  # other
#> # ... (the example has only the two treatment sheets; a real file routes them all)
```

A sheet the schema routes but the workbook doesn’t contain is **skipped
with a warning**, expected here, since the example is a two-sheet
subset. (If *none* of the routable sheets are present,
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
errors instead of silently doing nothing.)

> **Why the sheet, not the row?** Each sheet carries a per-row
> `#…_disease` field whose values are *programme-coverage* codes (`RB` /
> `RBLF` / `RBLFSCH`, which programmes run at that location), **not** a
> single disease.
> [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
> keeps that field as a data column and takes the routing disease from
> the sheet, so the same treatment numbers are **never duplicated**
> across diseases. Cross-programme **Training** sheets, which serve all
> programmes at once, route together under the combined `rblf` disease.

If the dry run comes back with nothing skipped and no warnings, you’ll
see a plain “Dry run clean – ready to run for real” instead of having to
infer it from an absence of complaints. If it does flag something (a
skipped sheet, or a real template defect like a duplicate field code),
it’s also logged so you have a stable reference to attach a note to
later, once you’ve looked into it and fixed whatever needed fixing:

``` r

# ... after investigating and correcting something upstream ...
eri_logs_resolve("uga/rblf/cmr/logs/20260710_150903_eri_split_cmr_dryrun.yaml",
                 note = "confirmed the skipped training sheets aren't part of this country's report")
```

Then stage for real, one parquet per sheet, in its disease/measure
folder. If this country’s raw file still also needs to reach the legacy
contractor pipeline during the Phase-3 parallel run, `mirror_pipeline`
uploads it there in the same call – one step instead of a separate
manual upload:

``` r

plan <- eri_split_cmr(report, "uga")   # add mirror_pipeline = "rb-expansion" if this country needs it
#> ✔ "RB Treatment"  -> uga/oncho/programmatic/treatment/staged/cmr-example_rb_treatment.parquet
#> ✔ "SCH Treatment" -> uga/sch/programmatic/treatment/staged/cmr-example_sch_treatment.parquet
#> ── ✔ Split CMR by disease/measure ───────────────────────
#> Sheets: 2 routed
#> Diseases: oncho, sch
```

Keep `plan` around for the next two steps. Lost it, or ran the split in
an earlier session? Recover it without rerunning anything (the routing
table is persisted in the op-log every real run writes):

``` r

plan <- eri_cmr_last_plan("uga", "202406")
```

**Re-splitting a corrected file.** Fixed something upstream and
re-splitting a `_fixed.xlsx` copy for a period you already split? By
default
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
only *warns* about the now-superseded prior staged file(s) – it never
deletes anything without you opting in, since this is the one place in
the package that can remove previously-staged data:

``` r

eri_split_cmr(fixed_report, "uga", supersede_staged = TRUE)
#> ✔ Superseded a prior staged file for this period: cmr-example_rb_treatment.parquet
```

Leave it `FALSE` (the default) if you’d rather review the warning and
remove the old file by hand.

## 5. Check data quality before approving

> **Prefer to do this interactively?** Sections 5 and 6 below are the
> scriptable core –
> [`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
> walks you through the same check → fix → re-check → approve loop as
> one guided, menu-driven session (fix a value in the workbook, adjust
> the schema, mark a flag not important/noted, force-approve with a
> typed confirmation, and submit a schema fix for a maintainer to fold
> in – all from one prompt): `eri_dq_review("uga", "202406")`. It’s
> built entirely on the functions below, so everything here still
> applies – interactive-only (it refuses to run in a script or CI, where
> these functions are what you use directly), and it holds no state of
> its own: close it mid-review and running it again picks up exactly
> where the logs say things are.

CMR routing does **not** auto-run DQ checks – CMR review is manual, on
purpose.
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
runs and logs DQ checks for every measure `plan` routed, in one call,
and gives you back **one combined tibble** – every flag from every
measure – instead of twelve separate
[`dq_report()`](https://thecartercenter.github.io/erifunctions/reference/dq_report.md)
printouts:

``` r

flags <- eri_cmr_dq_report("uga", "202406")
#> ✔ Logged 1 DQ flag (needs_review).
#> ✔ Logged 0 DQ flags (clean).
flags
#> # A tibble: 1 × 10
#>   sheet        disease data_type log_path      flag_id        row column value issue         status
#>   <chr>        <chr>   <chr>     <chr>         <chr>        <int> <chr>  <chr> <chr>         <chr>
#> 1 RB Treatment oncho   treatment uga/oncho/... uga/oncho...     4 target 0     out of range  open
```

Work through it **issue by issue**, not measure by measure: mark each
flag `"not_important"`, `"fixed"`, or `"noted"`, with a note explaining
what you did or decided:

``` r

eri_dq_flag_resolve(flags$flag_id[1], "not_important",
                   note = "confirmed with the country: target is genuinely 0 this period")
```

Once every flag in a measure’s report has been triaged, close out that
measure’s whole log entry – this is what actually unblocks
[`eri_approve_cmr()`](#approve) below. Skip `note` and it
auto-summarizes from the per-flag decisions you just made instead of
leaving the entry’s own note blank:

``` r

eri_logs_resolve(unique(flags$log_path)[1])
#> ✔ Marked ...yaml handled.
# note auto-filled as "1 not important" from the per-flag triage above
```

If you’d rather scan the *logged* state across the team’s whole backlog
(not just this run’s in-memory tibble),
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
still works the same way, one row per measure:

``` r

eri_logs("uga", data_source = "programmatic", operation = "dq_flags", since = "2026-07-01")
#> # A tibble: 2 × 15
#>   log_path       timestamp  operation status       disease data_type n_issues …
#>   <chr>          <chr>      <chr>     <chr>        <chr>   <chr>     <int>
#> 1 uga/oncho/...  2026-07-...dq_flags  needs_review oncho   treatment 1
#> 2 uga/sch/...    2026-07-...dq_flags  clean        sch     treatment 0
```

## 6. Approve

One CMR workbook fans out into several diseases/measures;
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
approves all of them in one call **but only if every one is clean** –
reviewed via the DQ-check step above, with no outstanding flags:

``` r

eri_approve_cmr("uga", "202406")
#> ✔ Approved 2 measures for "uga" / "202406".
```

If anything’s still outstanding (a measure was never DQ-checked, or has
unresolved flags), **nothing is approved** – you get a task list back
instead:

``` r

eri_approve_cmr("uga", "202406")
#> x 1 measure still needs attention -- approving nothing.
#> # A tibble: 1 × 4
#>   disease data_type log_path                                     issue
#>   <chr>   <chr>     <chr>                                        <chr>
#> 1 oncho   treatment uga/oncho/programmatic/treatment/logs/x.yaml 1 unresolved DQ flag(s)

# Review the flag, then close it out with a note explaining what you did/decided:
eri_logs_resolve("uga/oncho/programmatic/treatment/logs/x.yaml",
                 note = "confirmed with the country: target was genuinely 0 this period")
eri_approve_cmr("uga", "202406")   # re-run -- now clean, approves everything
```

Each disease’s data is now canonical and discoverable in the catalog on
its own coordinates. (You can still approve one measure at a time with
plain
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
–
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
is a convenience wrapper around exactly that, looped, with the DQ gate
in front.)

[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
also writes its own log entry recording exactly which `dq_flags` log(s)
it verified clean for this approval (`dq_reviewed`) – so the audit trail
from “this data is now processed” back to “here’s every flag that was
raised, and what was decided about each one” is traceable via
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md),
not just a bare approval stamp.

### The rare escape hatch: force-approving anyway

Every so often something is outstanding for a reason that will never
resolve cleanly – a known template quirk confirmed with the country, say
– and the data genuinely needs to go through. Pass `force = TRUE` and a
`justification` explaining why:

``` r

eri_approve_cmr("uga", "202406", force = TRUE,
                justification = "Known template quirk in RB Treatment; confirmed with country lead.")
#> x FORCE-APPROVING "uga" / "202406" despite 1 outstanding measure.
#> i Justification: Known template quirk in RB Treatment; confirmed with country lead.
#> # A tibble: 1 × 4
#>   disease data_type log_path                                     issue
#>   <chr>   <chr>     <chr>                                        <chr>
#> 1 oncho   treatment uga/oncho/programmatic/treatment/logs/x.yaml 1 unresolved DQ flag(s)
#> ✔ Marked 'x.yaml' handled (bypassed by a forced approval).
#> ✔ Force-approved 2 measures for "uga" / "202406".
```

This does **not** silently resolve the bypassed flag – it’s annotated
(`handled`, but marked `forced`) so the open backlog stays clean without
pretending it was ever actually reviewed, and the approval’s own log
records the justification and exactly what it bypassed. Reach for
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
first; force-approving is for when the flag itself will never close, not
a shortcut around reviewing it.

``` r

eri_catalog_query(country = "uga", data_source = "programmatic")
#> # A tibble: 2 × 13
#>   path                              country disease data_source  data_type layer …
#>   <chr>                             <chr>   <chr>   <chr>        <chr>     <chr>
#> 1 uga/oncho/programmatic/treatmen…  uga     oncho   programmatic treatment proce…
#> 2 uga/sch/programmatic/treatment/…  uga     sch     programmatic treatment proce…
```

That’s the monthly loop: **upload → stage → split → DQ-check →
approve.**

## What’s next

- **A new country files its first report?** Its CMR schema (which
  sheets, which field codes) has to exist first, see the CMR section of
  the [onboarding
  guide](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md)
  ([`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)).
- **[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  says “No routable sheets”?** A sheet only routes when its schema entry
  declares a `disease` and a `data_type`. `uga` is the worked example;
  other countries’ routing keys are being filled in, add them to the
  country’s `inst/schemas/cmr/{code}.yaml` (one `disease` + `data_type`
  per sheet) to enable the split there.
- The [surveillance ingest
  guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
  covers the same `raw → staged → approved` gate for line-list data, and
  the data-catalog mechanics in more depth.

> **Real reports are not practice data.** The monthly CMR files are
> protected country data, staged and approved through this pipeline,
> never deleted or moved casually. (The example here is synthetic, which
> is the only reason we could pass it around freely.)

See the [guide
index](https://github.com/thecartercenter/erifunctions/blob/main/docs/guides.md)
for the full set of guides.
