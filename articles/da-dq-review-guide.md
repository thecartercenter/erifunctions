# Triaging and handing back DQ flags, interactively (for data analysts)

**Walkthrough** · ~20 min · needs: Azure · sandbox-safe: yes (runs on
`atlantis`)

> **This is the screen
> [`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
> already puts you on.** Its CMR flow (and the “Review & approve
> something already staged” menu item) hands off directly into this same
> [`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
> loop – so if you’re triaging flags inside
> [`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)
> right now, this guide is the reference for what each menu option (fix
> in source, mark noted, force-approve) actually does.

The [CMR
guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md)
and the [QC/feedback
guide](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.md)
both walk the DQ pipeline as a **sequence of functions you call
yourself**: check, resolve each flag, close out the entry, re-run,
approve. That’s the scriptable core, and it has to exist for automation.
But you shouldn’t have to remember that sequence, or which function does
which part of it, just to triage a CMR workbook.
**[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)**
is one function, one guided menu, that *is* the whole loop:

flowchart TD A\["eri_dq_review(country, period)"\] --\> B{"Any open
flags?"} B -- "yes" --\> C\["Work through flags one at a time  
fix in source / adjust schema / mark not important / mark noted"\] C
--\> D\["Re-run the DQ check"\] D --\> B B -- "no" --\> E\["Nothing
outstanding"\] E --\> F\["Approve"\] E --\> G\["Print report -\>
eri_dq_export()"\] G --\> E

Everything under the hood is still
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md),
and
[`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md)
– but as a DA running this interactively, you never call any of them
directly. You just answer the menu.

> **The wrapper holds no state of its own.** Every open re-derives
> current flags fresh from a real, logged DQ check against whatever’s
> actually staged – it never trusts a possibly-stale in-memory or cached
> view. Every triage decision is written through immediately too, not
> batched. So closing your laptop mid-review and running
> [`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
> again later is always safe: it re-checks from the real staged data and
> picks up your prior decisions from the logs. The one thing it doesn’t
> remember between separate runs is *which local file you were fixing* –
> point it back at your working copy (or the original; see
> [below](#fix-in-source)) if you come back to re-run a check.

## Before you start

- `remotes::install_github("thecartercenter/erifunctions")`.
- **Azure access** to the `data` blob (zero-config browser sign-in, see
  the [connections
  guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)).
- `openxlsx2` (already a package dependency) to build the practice
  workbook below.
- A CMR workbook already staged and split – see the [CMR
  guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md)
  sections 1-4 for a real country. Below, we practice on the built-in
  **`atlantis`** training sandbox instead, so nothing here touches a
  real program’s data.

``` r

library(erifunctions)
```

> **What’s `atlantis`?** A fictional country the package ships a CMR
> routing schema and a DQ schema for (`load_cmr_schema("atlantis")`,
> `load_dq_schema("atlantis", "oncho", "programmatic", "treatment")`),
> purely so this exact loop – split, flag, triage, approve – can be
> practiced against the real `data` Azure blob without ever touching a
> real country’s namespace.

## 1. Build a practice submission with two real problems

The bundled `cmr-example.xlsx` (used throughout the [CMR
guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md))
is clean data, so there’s nothing for a DQ check to catch. To have
something to actually review, we deliberately introduce two realistic
problems into a copy of it – the same kind of thing a real submission
might contain: an impossible value, and a locality the schema doesn’t
recognise yet.

We also drop the `SCH Treatment` sheet: `atlantis` only ships a bundled
DQ schema for `oncho/treatment`, and
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
blocks on **any** routed measure that’s never been DQ-checked (a
schema-less measure never gets one) – the same rule applies to a real,
multi-sheet CMR, where every routed measure needs a schema before the
whole workbook can be approved.

``` r

library(openxlsx2)

wb <- wb_load(system.file("extdata", "cmr-example.xlsx", package = "erifunctions"))
wb$remove_worksheet("SCH Treatment")
wb <- wb_add_data(wb, sheet = "RB Treatment", x = -50,
                  start_col = 6, start_row = 6, col_names = FALSE)             # Kampala's treated count
wb <- wb_add_data(wb, sheet = "RB Treatment", x = "Atlantis City",
                  start_col = 4, start_row = 8, col_names = FALSE)             # Soroti's district cell
path <- file.path(tempdir(), "202608_atlantis_demo.xlsx")
wb_save(wb, path, overwrite = TRUE)
```

## 2. Get a workbook with something to review

[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
routes the workbook to `atlantis`’s `oncho/programmatic/treatment`
measure;
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md)
checks it against that measure’s schema and combines every flag into one
tibble – both covered in depth in the [CMR
guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html#dq-check).

``` r

plan  <- eri_split_cmr(path, "atlantis", period = "202608")
flags <- eri_cmr_dq_report("atlantis", "202608", plan = plan)
#> ✔ DQ checks complete: 0 corrections, 2 flags for review.
#> ✔ Logged 2 DQ flags (needs_review).
flags[, c("excel_row", "column", "value", "issue", "status")]
#> # A tibble: 2 × 5
#>   excel_row column   value         issue                                  status
#>       <int> <chr>    <chr>         <chr>                                  <chr>
#> 1         6 treated  -50           Value outside expected range [0, 1000… open
#> 2         8 district Atlantis City Value not in allowed_values list       open
```

Two flags, one measure. Now forget that tibble exists – from here on,
one function.

## 3. Run the review

``` r

eri_dq_review("atlantis", "202608")
```

[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
is **interactive only** – it refuses to run in a script or from
`Rscript`, with a pointer back to the scriptable core
([`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md))
for CI/automation. Run it from a live R console or RStudio session.
Below is a real session against the workbook built above, one menu
choice at a time – the menu prompts themselves come straight from the
function; the informational and success messages between them are real,
captured output.

> **Your console will be busier than the transcripts below.** Each DQ
> check also prints its own “renamed column” and “corrections/flags”
> lines, and you’ll likely see
> `! Could not load schema from Azure (Not Found...). Falling back to local.`
> – expected here, since `atlantis`’s DQ schema only ships inside the
> package and is never uploaded to Azure. Nothing below is broken; the
> transcripts are trimmed to what changes each step, not a full console
> dump.

### It opens on the flags

    ── DQ review: atlantis / 202608 ────────────────────────────────────────────────
    ✖ 1 of 1 sheet have open flags (2 flags total)

    ── RB Treatment (oncho/treatment) -- 2 open ──

     excel_row   column         value                                      issue
             6  treated           -50 Value outside expected range [0, 10000000]
             8 district Atlantis City           Value not in allowed_values list

    ── 2 open flag(s) across the workbook. What do you want to do?

    1: Work through the open flags one at a time
    2: Re-run the DQ check
    3: Force-approve anyway
    4: Print report
    5: Exit

Two open flags need two different responses, not the same one – that’s
the whole reason to work through them one at a time rather than
bulk-resolving.

### Flag 1: a real error -\> fix in source

`treated = -50` is impossible – a genuine data-entry mistake, not a
judgement call. Choosing **“Work through the open flags”**, then **“Fix
in source”** for this flag:

    ── Flag 1/2: RB Treatment row 6
    treated: "-50" -- Value outside expected range [0, 10000000]
    ── What do you want to do with this flag?

    1: Fix in source (open/copy the workbook)
    2: Adjust the schema (alias, allowed value, range...)
    3: Mark not important
    4: Mark noted
    5: Skip to the next flag

    Path to the local source workbook for this period (or a '_fixed' copy you've already started, if you have one): <you type the path here>
    ✔ Made a working copy: '202608_atlantis_demo_fixed.xlsx' (original preserved)
    ℹ Fix treated on Excel row 6 in the "RB Treatment" sheet.
    ℹ Issue: Value outside expected range [0, 10000000]
    ℹ Open this file to review/edit: '.../202608_atlantis_demo_fixed.xlsx'
    ℹ When you're done with this and any other fixes, choose "Re-run the DQ check" from the main menu -- it re-splits '202608_atlantis_demo_fixed.xlsx' and re-checks.

The first time you fix anything in a session,
[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
forks a `_fixed` working copy before touching it – the file as submitted
is never edited in place. Open that copy, correct the value, save it.
(Picking this back up in a fresh R session? Point it at that same
`_fixed` file, or the original again – it detects the `_fixed` sibling
and reuses it rather than forking a second one.)

> In RStudio, the working copy opens directly in the editor instead of
> printing an “open this file” message –
> [`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
> uses `rstudioapi` when it’s available.

### Flag 2: not wrong, just not catalogued yet -\> defer it

`"Atlantis City"` isn’t a typo – it’s a real locality the schema’s
`allowed_values` list hasn’t caught up to yet. There’s nothing to *fix*.
Choose **“Skip to the next flag”** for now (we’ll come back to it once
the actual error above is out of the way):

    ── Flag 2/2: RB Treatment row 8
    district: "Atlantis City" -- Value not in allowed_values list

### Re-run: only what changed gets re-checked

Back at the main menu (still 2 open – fixing the workbook doesn’t
retroactively change the logged flags), choose **“Re-run the DQ
check”**:

    ── Re-split '202608_atlantis_demo_fixed.xlsx' and re-check just what it routes to?

    1: Yes
    2: No -- cancel

    ℹ Superseded a prior staged file for this period: '202608_atlantis_demo_rb_treatment.parquet'
    ✔ "RB Treatment" -> 'atlantis/oncho/programmatic/treatment/staged/202608_atlantis_demo_fixed_rb_treatment.parquet'
    ✔ DQ checks complete: 0 corrections, 1 flag for review.

    ── DQ review: atlantis / 202608 ────────────────────────────────────────────────
    ✖ 1 of 1 sheet have open flags (1 flag total)

    ── RB Treatment (oncho/treatment) -- 1 open ──

     excel_row   column         value                            issue
             8 district Atlantis City Value not in allowed_values list

The `treated` flag is gone – the underlying value is fixed, so it never
comes back. The `"Atlantis City"` flag reappears exactly as it was,
because it’s genuinely still there. If your workbook routes several
measures, only the ones you actually re-split get re-checked; every
other measure’s in-session decisions are left alone (see the [CMR
guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html#dq-check)
for a worked multi-measure example).

### Flag 2, revisited: mark it noted

One flag left. **“Work through the open flags”** again, then **“Mark
noted”** this time, with an explanation:

    ── Flag 1/1: RB Treatment row 8
    district: "Atlantis City" -- Value not in allowed_values list
    Note (optional): <you type your explanation here>
    ✔ Flag 1 in '...dq_flags_202608.yaml' marked "noted".

We typed: *“Confirmed with the country lead: Atlantis City is a real, if
not-yet-catalogued, locality – flagging for the schema maintainer to add
it to the allowed list.”* That note travels with the flag from here on –
into the log, and into the handback file below.

### Nothing outstanding -\> print the report

    ── DQ review: atlantis / 202608 ────────────────────────────────────────────────
    ✔ 1 sheet checked -- all clean.
    ── Nothing outstanding. What next?

    1: Approve
    2: Print report
    3: Exit

“All clean” means every flag has been triaged, not that the data is now
flawless – one flag is just `noted` rather than `open`. Choose **“Print
report”**:

    ── RB Treatment
     excel_row   column         value                            issue status
             8 district Atlantis City Value not in allowed_values list  noted
                                                                                                                                                               note
     Confirmed with the country lead: Atlantis City is a real, if not-yet-catalogued, locality -- flagging for the schema maintainer to add it to the allowed list.

    ✔ DQ report (1 flag · 0 open) written to '.../dq-report-atlantis-202608-2026-07-12.html'.

A quick console eyeball first – a long `note` doesn’t truncate, it just
pushes the table wide, as it does here – then the handback file.
[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
calls
[`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md)
for you here – see the [QC/feedback
guide](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.html#export)
for what that function does on its own. Open the file: a self-contained
page, organised by sheet, with the `noted` status shown as a chip and
the note text in its own column – exactly what you’d forward to the
country or paste into Teams, with zero reformatting.

### Approve

Back at the same “Nothing outstanding” menu (print report loops back to
it, it doesn’t exit), choose **“Approve”**:

    ✔ Catalog: registered '202608_atlantis_demo_fixed_rb_treatment.parquet'.
    ✔ Approved: '202608_atlantis_demo_fixed_rb_treatment.parquet'
    ✔ Approval log: 'atlantis/oncho/programmatic/treatment/processed/202608_approval_log.yaml'
    ── ✔ Approved "202608" ─────────────────────────────────────────────────────────
    Dataset: atlantis / oncho / programmatic / treatment
    Files: 1 moved to processed
    Approver: NishantKishore (unverified)
    Location: atlantis/oncho/programmatic/treatment/processed
    ℹ Operation log: 'atlantis/oncho/programmatic/treatment/logs/20260712_014108_eri_approve_202608.yaml'
    ℹ Operation log: 'atlantis/rblf/cmr/logs/20260712_014108_eri_approve_cmr_202608.yaml'
    ✔ Approved 1 measure for "atlantis" / "202608".

> `Approver` shows as “(unverified)” here because this sandbox session
> has no `ERI_ANALYST_ID` set – on a normal analyst machine it carries
> your verified identity instead (see the [onboarding
> guide](https://thecartercenter.github.io/erifunctions/articles/onboarding.md)).

That’s the whole session: two flags, two different resolutions, a
handback file, one approval – without calling
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md),
or
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md)
yourself even once.

## Cleaning up

Everything above lives under `atlantis`’s own namespace, so it’s safe to
leave – but if you were following along and want to tidy up the sandbox
behind you, three things were created: the Azure-side
staged/log/processed files, the local practice workbook (`path`) and its
`_fixed` working copy (forked in [Flag 1](#fix-in-source)), and the
exported HTML report
([`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md)
writes to your working directory by default, not a temp folder – see the
[QC/feedback
guide](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.html#export)
– so it won’t clean itself up):

``` r

con <- get_azure_storage_connection(storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", "data"))
eri_catalog_remove(
  "atlantis/oncho/programmatic/treatment/processed/202608_atlantis_demo_fixed_rb_treatment.parquet",
  data_con = con
)
all_files <- AzureStor::list_storage_files(con, "atlantis", recursive = TRUE)
mine      <- all_files$name[!all_files$isdir & grepl("202608", all_files$name)]
for (f in mine) AzureStor::delete_storage_file(con, f, confirm = FALSE)

unlink(path)                                                    # the original practice workbook
unlink(sub("\\.xlsx$", "_fixed.xlsx", path))                     # its "fix in source" working copy
unlink(list.files(getwd(), pattern = "^dq-report-atlantis-202608-.*\\.html$", full.names = TRUE))
```

Real submissions are not disposable like this practice run – never
delete a real country’s staged, processed, or log files this way.

## What’s next

- [`eri_dq_export()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_export.md)
  on its own, and its markdown output, in the [QC/feedback
  guide](https://thecartercenter.github.io/erifunctions/articles/da-qc-feedback-guide.html#export).
- The scriptable core this orchestrates, and a worked multi-measure
  example, in the [CMR
  guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html#dq-check).
- Scanning the *logged* state of the whole team’s backlog (not just one
  session’s tibble) with
  [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md),
  the [log-triage
  guide](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md).
- Submitting a schema fix for a maintainer to fold in permanently
  (rather than a one-off note) via
  [`eri_dq_schema_submit()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_schema_submit.md)
  – offered automatically at the end of a session if you used “Adjust
  the schema” on any flag.
