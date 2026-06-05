# Contributing to erifunctions

## Workflow

1.  **Open an issue first.** Every change starts with a GitHub issue
    scoped to ~1-2 hours of work.
2.  **Branch from `dev`** as `{issue-number}-{short-slug}`
    (e.g. `54-quarto-template`).
3.  **PR targets `dev`**, not `main`. `main` only receives
    version-bumped phase releases.
4.  **`devtools::check()` must be 0 errors, 0 warnings** before
    requesting review.
5.  Issues are closed manually after the PR merges.

## Adding a new country schema

Schemas live in `inst/schemas/` (surveillance) and `inst/schemas/cmr/`
(CMR).

1.  Run
    [`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md)
    or
    [`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md)
    to generate a template in your working directory.
2.  Fill in the TODO sections.
3.  Run `eri_schema_validate("your_schema.yaml")` — fix any issues it
    reports.
4.  Copy the finished file into `inst/schemas/` (or `inst/schemas/cmr/`)
    and open a PR.

## Code conventions

- All exported functions are named `eri_*()` — verb-first,
  tab-completable.
- Internal helpers are prefixed with `.` and documented with
  `#' @keywords internal`.
- Use
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html) /
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)
  /
  [`cli::cli_alert_success()`](https://cli.r-lib.org/reference/cli_alert.html)
  for all user-facing messages — no
  [`message()`](https://rdrr.io/r/base/message.html),
  [`warning()`](https://rdrr.io/r/base/warning.html), or
  [`stop()`](https://rdrr.io/r/base/stop.html).
- No non-ASCII characters in R source files (no em dashes, smart quotes,
  tab literals).
- No `withr::local_mocked_bindings` — use
  [`testthat::local_mocked_bindings()`](https://testthat.r-lib.org/reference/local_mocked_bindings.html).
- Temp files cleaned up with `withr::defer(unlink(tmp))`.

## Phase releases

When all issues in a phase are closed: 1. Update `NEWS.md` and
`README.md`. 2. Bump `Version:` in `DESCRIPTION`. 3. Merge `dev` →
`main` via a squash PR. 4. Create a GitHub release tagged `v{version}`.
