# Red-team learnings

Durable notes from the fresh-user red-team persona runs (`da-fresh-user` "Dana",
`epi-fresh-user` "Eli"). Each run plays a brand-new Data Analyst or Epidemiologist trying to do
their real job end-to-end using only `eri_*` functions, and reports where the docs or API let them
down. **Future runs should read this first and dedupe against it** — confirm whether a prior finding
is fixed before re-reporting it, and append new structural learnings here.

This file is for *learnings* (durable facts about the system and how to test it), not the full
reports. The detailed, severity-tagged findings live in the PRs/issues that act on them.

---

## Run 1 — 2026-06-27 (post-ADR-0012 migration)

First paired run, right after the source ≠ measure data-model migration (#175 / ADR-0012) landed the
5-axis path `data/{country}/{disease}/{data_source}/{data_type}/{layer}/` across the code.

### The headline learning: the split was code-vs-docs, not code-vs-code

Both personas independently concluded the **code is uniformly ADR-0012-correct** (`eri_data_path`,
`eri_approve`, `eri_catalog_*`, `eri_logs`/`eri_dq_log`, the bundled schemas, `load_dq_schema`,
`eri_data_model`), and the back-compat shims genuinely work on sandbox data. The friction was the
**docs lagging in the old four-axis vocabulary**. So a future run right after a model change should
**weight guide/README audits over code audits**.

### What both personas could do end-to-end, live, with only `eri_*` (don't re-test exhaustively)

- **DA:** onboard (dry-run + real) → ingest (clean + flagged extracts) → DQ → stage → `eri_approve`
  → catalog → the full `eri_dq_log`/`eri_logs`/`eri_logs_resolve` triage loop → `eri_dir_delete`
  cleanup. CMR offline parse on the bundled `cmr-example.xlsx`. **Never needed AzureStor / Storage
  Explorer** — every GUI temptation had a working `eri_*` equivalent.
- **Epi:** `eri_spatial_reconcile` (string-match + live keyless OSM geocode + the trust guard) and all
  four `add_anomaly_*` detectors, live on synthetic data. The spatial detector skips cleanly offline
  (`azcontainer = NULL`) instead of erroring.

### Things to test first next time (the seams, not the happy paths)

1. **Has the doc sweep landed?** Run 1 found the README "Data layers" diagram, `da-ingest`, `da-odk`,
   and `da-onboard §3` still teaching `surveillance/cmr/odk` as `data_type` (now `data_source`), and
   no role-scoped "start here" path. Check whether these are fixed before re-reporting.
2. **`eri_research_pull`** was the one un-migrated function (fixed in PR #195 — verify it stays 5-axis).
3. **Silent four-axis entries:** the legacy (no-measure) path does not warn at runtime, so a guide that
   teaches it produces `data_type = NA` catalog rows with no signal. Watch for whether a `cli_inform`
   signpost was added.

> **Resolved after Run 1 (verify, don't re-report):** the doc sweep landed — README five-axis
> consistency + reference rows + transitional callouts (#196); `eri_research_pull` → 5-axis (#195);
> a once-per-session `eri_approve` no-measure signpost (#197); the full `da-ingest-guide` 5-axis
> rewrite (#198); and the role-scoped "New here? Do these in order" path in README + `docs/guides.md`
> (#199). The **remaining** Run-1 items still open: the CMR guide leads with Storage Explorer for
> upload (should lead with `eri_upload()`), and `ERI_ANALYST_ID` is not promoted to a required Day-1
> step. Confirm these before re-reporting; treat everything above as fixed unless proven otherwise.

### Delighters worth protecting (regressions here would hurt most)

- `eri_data_model()` — the single best orientation tool; prints the whole 5-axis vocabulary with the
  transitional `cmr`/`odk` tokens flagged. Future personas should **call it first** to anchor vocab.
- The schema-not-found error lists every bundled schema + the ADR-0012 identity + an example call.
- `eri_dir_delete()` recursive cleanup is *the* function that keeps users out of Storage Explorer.
- The `da-odk-guide` repeat-group section (parent/child tables, `PARENT_KEY`→`KEY` join).
- `eri_spatial_reconcile`'s trust guard (keeps coordinates, refuses to overwrite a mismatched admin
  name) — the Epi's favorite; does the one judgment call they'd otherwise agonize over by hand.

### Run mechanics (save time next run)

- Invoke R via PowerShell with a **`.R` script file** (`Rscript script.R > out.txt 2>&1`), **not**
  inline `-e` — inline quoting (`$`, `\`) causes spurious aborts under PowerShell. R is at
  `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`.
- The cached Azure token loads non-interactively ("Loading cached token"); no browser needed in-session.
- `devtools::load_all()` prints a harmless renv "out-of-sync" notice — ignore it.
- The keyless OSM geocode path works for a reader with no API key (~3.5s for 3 addresses).
- **Data policy:** synthetic/sandbox only; never read real country/research data; secrets stay in
  `.Renviron`. Both runs verified their sandboxes left no trace (catalog empty, namespace gone).

### The one durable conceptual risk

The fault line is **mental-model formation**, not broken functions. A newcomer who reads a stale guide
forms the wrong `channel` vs `measure` model, or hits a signature that lags the data model and never
comes back to `eri_*`. **Sourcing/onboarding is the weak link; the pipeline, reconcile, and QC are
strengths.** Future runs should probe the *first* thing each role does (find/onboard data) hardest.
