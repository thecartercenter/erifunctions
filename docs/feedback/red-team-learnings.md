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

---

## Run 2 — 2026-06-28 (Eli, epi-fresh-user, second pass)

Second epi pass, verifying the post-Run-1 fixes and re-probing the sourcing seam. Ran everything live:
offline reconcile + DQ detectors, a live keyless OSM geocode, a catalog read against the real (empty)
catalog, and a full **synthetic** discover→pull round-trip in a self-built `lemuria/malaria` namespace
(written, registered, queried, pulled, torn down — left no trace). Headline: **the sourcing path now
reads coherently; the friction has moved from "wrong vocabulary" to "small lifecycle gaps."**

### Run-1 items re-checked (status)

- **FIXED & confirmed — `eri_research_pull` is 5-axis (Run-1 #1).** `eri_catalog_query` and
  `eri_research_pull` now share the *same four discovery tokens* (`country, disease, data_source,
  data_type`). I queried a synthetic entry and pulled it back with the identical tokens the query
  reported — `✔ Pulled 1 file from 'lemuria/malaria/research/case/processed'`. The union signature
  (5-axis **or** legacy `path=`/`dest=`) means the epi-research-guide's `path=` examples *also* still
  work. This is the single biggest improvement since Run 1; the discover→pull loop now reads like one
  coherent story.
- **FIXED & confirmed — README is uniformly 5-axis** with the role-scoped "New here? Do these in order"
  paths and the `eri_data_model()`-first instruction. The Epi path (connections → research → reconcile
  → dq) is coherent and not overwhelming.
- **FIXED & confirmed — `load_dq_schema(country, disease, data_source, data_type)`** 4-arg form is what
  both epi guides teach; ran live, schema loaded offline with `azcontainer = NULL`.
- **STILL OPEN — CMR guide leads with Storage Explorer.** `da-cmr-guide.Rmd:72` still reads "Often this
  upload happens through Azure Storage Explorer or SharePoint, but you can also do it from R." Run-1
  asked for this to **lead with `eri_upload()`**; it still names the GUI first. (Epi-adjacent: an epi
  sourcing programmatic/treatment data would read this guide.)
- **STILL OPEN — `ERI_ANALYST_ID` not promoted to Day-1.** It appears only inside the
  "One `.Renviron` for everything" block (connections-guide:222), never as a required first step.
  Confirmed the live cost: with it unset, `eri_catalog_register` / `eri_research_pull` emit
  `! ERI_ANALYST_ID is not set; governed actions will be logged as "NishantKishore"` and silently log
  governed actions under the OS username. An epi doing a governed pull hits this on day one.

### New Run-2 findings (not in Run 1)

1. **[Major] `eri_dir_delete()` does not deregister catalog entries — cleanup leaves a dangling row.**
   In my round-trip, after `eri_dir_delete("lemuria")` removed the blob files, `eri_catalog_query
   (country="lemuria")` still returned the row, and `eri_catalog_verify()` then warned
   `1 catalog entry not found in Azure`. The fix was `eri_catalog_remove(path)` — which **works
   cleanly** but (a) is **absent from the README reference table** (only register/query/verify are
   listed) and (b) is **never mentioned in the epi-research-guide §12 "Clean up"**, which teaches only
   `eri_dir_delete()`. A fresh user who follows the cleanup guide leaves a phantom catalog entry behind.
   Fix: add `eri_catalog_remove` to the README catalog table; either have `eri_dir_delete` offer to
   deregister overlapping catalog paths (or warn), and mention `eri_catalog_remove` in §12.

2. **[Minor] Catalog discovery is fine but invisible to a fresh epi until data exists.** The live
   catalog is empty, so a brand-new epi running the README's example queries gets
   `The data catalog has no entries yet` / `No catalog entries match` and has nothing to pull. The
   discover→pull story is only *shown* end-to-end if you seed data yourself. A worked, copy-paste
   "discover what exists, then pull it" example in the epi-research-guide (the one place an epi learns
   sourcing) would make the round-trip legible without needing populated infrastructure. Right now §4
   pulls by *artifact path*, never by catalog coordinates — so the 5-axis pull (the headline fix) is
   not actually demonstrated in the epi guide.

### Delighters re-confirmed (protect these)

- `eri_data_model()` is still the best orientation tool — printed the full channel/measure/format/layer
  vocabulary with the transitional `cmr`/`odk` tokens flagged. Call it first.
- `eri_spatial_reconcile()` trust guard: live OSM run reproduced the guide exactly — MIT geocoded into
  Cambridge/Middlesex while the row claimed Suffolk, fired `geocoded_review`, kept the coordinates,
  left the county untouched, and surfaced the conflict in `geocoded_adm2_name`. As an epi I would trust
  this over hand-geocoding. ~3.1s Nominatim query for 3 addresses.
- The four `add_anomaly_*` detectors chained cleanly; spike (+400% then -73%), missing-week structural
  gap, consistency pass, and spatial **skip-clean** (`No admin block in schema; skipping`) all matched
  the guide output. Flags are framed in epi terms ("real cluster vs double-entry", "no report vs lost
  in transfer"), not engineering terms.

### Run mechanics (unchanged, still true)

- `.R` script file via `Rscript`, not inline `-e`. Cached Azure token loads non-interactively. Keyless
  OSM path works with no key. The renv "out-of-sync" notice is harmless.
- A self-built `lemuria/malaria` synthetic namespace is a clean way to demonstrate the governed
  discover→pull→teardown loop without touching real data — but **remember to `eri_catalog_remove()`**,
  not just `eri_dir_delete()`, or the catalog keeps the row (see finding #1).

### The durable conceptual risk (updated)

Run 1 said the weak link was vocabulary; Run 2 says the vocabulary is now right and the weak link is
**lifecycle completeness in the sourcing story** — the 5-axis pull is implemented and coherent but not
*demonstrated* in the epi guide (which still pulls by artifact path), and the cleanup/catalog lifecycle
has one un-closed loop (`eri_dir_delete` vs `eri_catalog_remove`). Sourcing is no longer broken; it is
*under-shown*.

## Run 2 — 2026-06-28 (Dana, da-fresh-user, second pass)

Second DA pass, paired with Eli above. Ran the **entire DA arc live** on a self-built `atlantis/malaria`
sandbox: `eri_data_model` → onboard (dry-run + real, schema validated clean out of the box) → hand-author
+ upload a `case` DQ schema → ingest two extracts (clean + flagged) → DQ → stage → `eri_approve` (×2) →
catalog query → the full `eri_dq_log`/`eri_logs`/`eri_logs_resolve` triage loop → `eri_split_cmr` offline
on the bundled `cmr-example.xlsx` → an ODK **registry** round-trip → teardown (`eri_catalog_remove` ×2,
`eri_delete` schema, `eri_dir_delete("atlantis")`). Verified `atlantis` gone from catalog **and** the
top-level listing. **Never needed Storage Explorer or raw AzureStor for a single step.** Headline: the
ADR-0012 surface (`data_source` vs `data_type`, catalog/logs columns, the CMR split, ODK→research) is
**code-correct and reads cleanly in the README, ingest, ODK, and CMR guides** — the remaining friction is
two stale guide sections and a couple of small lifecycle gaps, not the model.

### Run-1 items re-checked (DA side)

- **PARTIALLY FIXED — `ERI_ANALYST_ID` now warns at runtime (Run-1 still-open item).** A runtime signpost
  *has been added*: the first governed write in a session prints `! ERI_ANALYST_ID is not set; governed
  actions will be logged as "NishantKishore"` + `ℹ Set it in your '.Renviron' so approvals and logs carry
  your analyst identity.` That is a real improvement over Run 1 (silent fallback). **Still open:** it is
  not promoted to a Day-1 step in the connections guide (buried in the `.Renviron` block as just
  "identity"), and the approval log + `eri_logs` `analyst` column still recorded the **OS username**
  (`Approver: NishantKishore`) — an un-attributable identity in a governed audit log. Confirmed live in
  `eri_approve`, `eri_dir_create`, `eri_dq_log`, `eri_odk_register`.
- **STILL OPEN — CMR guide leads with Storage Explorer in prose** (`da-cmr-guide.Rmd:72`), independently
  re-confirmed (Eli noted the same line). `eri_upload()` *is* now shown immediately after, so the fix is
  half-done; just reorder the sentence to lead with `eri_upload()` and relegate the GUI to an aside.

### New Run-2 findings (DA, not in Run 1 or Eli's section)

1. **[Major] `da-onboard-guide §3` contradicts the now-shipped CMR split — actively teaches the wrong
   model.** Lines 199–203 still say *"Until that split ships, keep using `rblf`/`cmr` as shown here —
   don't adopt them as the canonical addressing model."* But `eri_split_cmr()` **has shipped** (exported,
   has a man page, ran offline against `cmr-example.xlsx` and routed `RB Treatment → oncho`,
   `SCH Treatment → sch`), and `da-cmr-guide` teaches the per-disease split + per-measure approval as the
   canonical flow. A newcomer who reads onboard before CMR is told the opposite of what's true. Fix:
   rewrite the §3 callout to "the split *has* shipped — `rblf/cmr` is now a transitional **staging
   archive** that `eri_split_cmr()` routes per-disease; see the CMR guide," matching `da-cmr-guide`'s own
   framing.

2. **[Major] `da-logs-guide` documents the wrong logs path and an `eri_dq_log` call that splits logs
   across two directories.** §1 line 60 says logs live in `{country}/{disease}/{data_type}/logs/` — that
   is **doubly wrong** under ADR-0012: it omits `data_source` and labels `surveillance` (a `data_source`)
   as `data_type`. Live reality is *split*: `eri_approve(data_type="case")` writes its op log to
   `atlantis/malaria/surveillance/case/logs/`, but the guide's `eri_dq_log(result, "atlantis","malaria",
   "surveillance", period=...)` call (no `data_type`) writes to `atlantis/malaria/surveillance/logs/` —
   one level shallower. So for one dataset, DQ logs and approval logs land in **different** `logs/` dirs.
   `eri_logs()` *scans* and finds both (so the workflow works), but the documented path is incorrect and
   the guide never passes `data_type` to `eri_dq_log` even though it explicitly "picks up from the ingest
   guide" which approved at `case` level. Fix: correct line 60 to
   `{country}/{disease}/{data_source}/[{data_type}/]logs/`, and pass `data_type = "case"` in the
   `eri_dq_log` example so it co-locates with the approval log.

3. **[Minor] `eri_split_cmr` is missing from the README function-reference table.** The README "CMR
   monthly reports" table (README:226-233) lists only `eri_ingest_cmr` / `load_cmr_schema` /
   `eri_stage_cmr`. The headline new function of the CMR migration isn't discoverable from the README at
   all (it *is* in `_pkgdown.yml` reference and the CMR guide). Add a row.

4. **[Minor] The ODK registry has no sandbox isolation.** A practice `eri_odk_register()` (even with a
   throwaway `project_id=99999`, `country="uga"`, `disease="demo"`) writes into the **same production
   `odk/registry.yaml`** that holds real registered Uganda LF TAS forms — `eri_odk_list_registered()`
   returned the four real forms alongside my test row. The guide's documented cleanup
   (`eri_odk_deregister`) is a **soft-delete** (`active:false`), so a practice entry persists invisibly in
   the production registry forever. Two asks: (a) note in `da-odk-guide` that registration writes to the
   shared registry (so practice runs are visible to teammates until deregistered), and (b) consider a
   hard-delete / purge option for synthetic test rows, or a `_sandbox` registry namespace.

5. **[Nit] `eri_split_cmr` rolls skipped-sheet warnings into "There were 12 warnings (use warnings() to
   see them)".** The CMR guide §4 shows them inline (`Warning: Sheet "LF MMDP" not found ... skipping`),
   but live they're deferred — a fresh DA might not realize the 12 are benign without calling
   `warnings()`. Consider a single `cli_inform` summary ("10 schema sheets not present in this workbook;
   skipped") instead of raw deferred warnings. The dry-run routing tibble is excellent and offsets this.

6. **[Nit] Catalog `row_count` is `NA`** for parquet files approved through `eri_approve` (seen on both
   atlantis entries). Not load-bearing, but a populated row count would make `eri_catalog_query` more
   useful at a glance.

### Storage-Explorer-temptation log (DA, Run 2)

Worked the entire arc and **never once needed to drop to Storage Explorer or AzureStor.** Every instinct
had a working `eri_*` path: upload schema (`eri_upload`), make folders (`eri_dir_create`), write/read
(`eri_write`/`eri_read`), promote (`eri_approve`), discover (`eri_catalog_query`/`eri_list`), de-list
(`eri_catalog_remove`), delete recursively (`eri_dir_delete`), delete a single blob (`eri_delete`). The
only place a *guide* still nudges toward the GUI is `da-cmr-guide.Rmd:72` (prose leads with Storage
Explorer for the CMR upload) — already flagged. `eri_dir_delete` remains *the* reason a DA stays in the
package for cleanup.

### Delighters re-confirmed (DA side)

- The onboard **dry-run/real parity** is exact, and the scaffolded `aggregate` schema **validates clean
  out of the box** (`eri_schema_validate` → empty tibble) — a confidence-builder for a non-developer.
- The two-extract ingest story (clean → 0 flags; messy → 2 flags with row-level `$flags`, then fix +
  re-check → 0) is the single clearest teaching moment in the whole doc set; ran live, matched verbatim.
- `eri_logs`/`eri_logs_resolve` shared-backlog loop ran live, the tibble carries `data_source` +
  `data_type` columns (ADR-0012 correct), and resolve cleanly dropped the error from the open backlog.
- `eri_split_cmr(dry_run=TRUE)` returns a tidy routing tibble (sheet → disease → data_type → dest →
  n_rows) — exactly the "show me before you touch anything" affordance a cautious DA wants.

### The durable conceptual risk (DA view, agreeing with Eli)

The model is right; the **docs have two stale islands** that teach a newcomer the wrong thing before the
correct guide can correct them: onboard §3 ("until the split ships") and logs §1 (wrong path axis). Both
are *upstream* of the guides that get it right, so a sequential reader forms the wrong model first. The
weak link is no longer vocabulary or the pipeline — it is **cross-guide consistency at the seams the
migration touched** (CMR split, logs path). Audit every guide that mentions `cmr`/`rblf` or a `logs/`
path against the shipped behavior.
