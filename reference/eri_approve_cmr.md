# Approve every disease/measure one CMR workbook routed to, in one call

**\[experimental\]**

[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
promotes one `(disease, data_type)` at a time, but one CMR workbook fans
out into many of them via
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md).
This looks up what got routed for `country`/`period` (via
[`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md)
if `plan` isn't supplied), checks every measure's DQ-flag log, and only
if **none** have an outstanding item – either unresolved flags or never
having been DQ-checked at all for this period – approves every measure
in one call.

If anything is outstanding, **nothing is approved**. This is the
explicit human-review gate for CMR data; the point is that a DA can't
accidentally approve past an unreviewed measure by looping blindly.
Instead you get back a task list: one row per measure still needing
attention. Review each, close it out with
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
(passing what you did/decided via its `note` argument), and re-run this
function – it re-checks from scratch each time.

**A stale flag keeps blocking until it's explicitly resolved.** This
checks every `dq_flags` log entry for the period, not just the most
recent one: if an earlier
[`eri_dq_log()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_log.md)
run had unresolved flags and a later rerun for the same period came back
`"clean"`, the earlier entry still blocks approval until you
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
it. This is deliberate (an unreviewed flag shouldn't be silently
superseded by a fresh "clean" run), but it does mean a truly
stale/superseded flag needs an explicit note to clear, not just a clean
recheck.

**`force = TRUE` approves anyway**, for the rare case a DA needs to
promote data despite an outstanding measure (e.g. a genuine template
quirk that will never resolve cleanly, under a deadline). It requires a
non-empty `justification` – no confirmation prompt here, since this
scriptable core has to work unattended in scripts/CI; an interactive
wrapper is the right place for extra human friction (e.g. "type the
period to confirm"), not this function. Every bypassed measure's
`dq_flags` entry (when one exists) is annotated `handled` via
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md)
with `forced = TRUE` and a note pointing back at this approval's own log
– so the open backlog stays clean without pretending the flag was ever
actually reviewed, and
[`eri_audit()`](https://thecartercenter.github.io/erifunctions/reference/eri_audit.md)
renders the whole thing prominently rather than folding it in as an
ordinary approval.

## Usage

``` r
eri_approve_cmr(
  country,
  period,
  plan = NULL,
  data_con = NULL,
  force = FALSE,
  justification = NULL
)
```

## Arguments

- country:

  `str` Country code (e.g. `"sdn"`).

- period:

  `str` Reporting period (e.g. `"202605"`).

- plan:

  `tibble` or `NULL` The plan from
  [`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md)
  /
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).
  `NULL` (default) looks it up via
  [`eri_cmr_last_plan()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_last_plan.md).

- data_con:

  Azure container for the `data/` blob. If `NULL`, connects
  automatically.

- force:

  `lgl` Approve even if some measures are outstanding. Default `FALSE`.
  Requires `justification`.

- justification:

  `chr` or `NULL` Required (non-empty) when `force = TRUE`: why this
  approval is going through despite what's outstanding. Recorded on the
  approval's own log and ignored when `force = FALSE`.

## Value

Invisibly, a tibble: if everything was clean (or `force = TRUE`), one
row per `(disease, data_type)` that got approved; if anything was
outstanding and `force = FALSE`, one row per `(disease, data_type)`
still needing attention (with `log_path`/`issue`) and **nothing was
approved**.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_approve_cmr("sdn", "202605")

# Only if you genuinely mean to promote past an outstanding measure:
eri_approve_cmr("sdn", "202605", force = TRUE,
                 justification = "Known template quirk in RB Treatment; confirmed with country lead.")
} # }
```
