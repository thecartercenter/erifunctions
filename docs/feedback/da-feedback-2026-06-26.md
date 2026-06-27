# DA fresh-user red-team feedback — "Dana" — 2026-06-26

Persona: brand-new ERI Data Analyst, competent R *user* (tidyverse, reads CSV/Excel), **not** a
package developer. Today she moves blob files in **Azure Storage Explorer (the GUI)**. The point of
this exercise: find every moment she'd reach for Storage Explorer or base R instead of an `eri_*`
function. Run was live and hands-on against the real Azure `data` blob and the live ODK Central server
(`rblf.tccodk.org`), on sandboxes only (`atlantis/malaria`, `uga/demo`) with synthetic data. Everything
created was cleaned up and verified gone. No package file was edited.

This is the **first** red-team run; `docs/feedback/red-team-learnings.md` was empty, so nothing was
de-duplicated against prior findings.

---

## Headline

**Yes — a fresh DA can do the whole job relying on `erifunctions`, and it's genuinely good.** I ran the
full arc end-to-end (connect → onboard → ingest two surveillance extracts → CMR parse → ODK simple +
repeat forms → logs triage → cleanup) and every core step worked on the first try, matched its guide
almost exactly, and produced the audit trail it promised. The friction is real but narrow: it is
concentrated in **cleanup** (the guides teach me to drop out of `erifunctions` into raw `AzureStor` to
delete things, even though `eri_delete()`/`eri_dir_delete()` exist), in **identity** (my approval logs
were stamped with my Windows username, silently, because nothing told me `ERI_ANALYST_ID` was unset),
and in a few **cosmetic-but-scary** output issues (success messages and routine info print in alarming
red; a `readr` column-spec dump erupts in the middle of a clean DQ run). None of these blocked me, but
the cleanup one is the difference between "I trust erifunctions for the whole lifecycle" and "I delete
in Storage Explorer because the docs told me to."

---

## The Storage-Explorer-temptation log

Every moment I (Dana) wanted to drop out of `erifunctions`, and whether an `eri_*` path actually exists.

| # | What I wanted to do | Did I reach for SE / base R? | Does an `eri_*` function exist? | Verdict |
|---|---|---|---|---|
| 1 | **Delete my sandbox** (`atlantis`, `uga/demo`) at cleanup | **Yes — the guides told me to.** Every cleanup section uses `AzureStor::delete_storage_dir(...)` / `delete_storage_file(...)` | **YES — `eri_dir_delete()` and `eri_delete()` are exported** and even write a session log | **Worst offender.** The docs actively push me out of the package for the one operation Storage Explorer is *best* at. If the guides used `eri_dir_delete()`, I'd never open SE. |
| 2 | Upload the practice ODK form and submit 2–3 fake entries (ODK guide §1) | Yes — went to the ODK Central **web UI** (Enketo) | No (and correctly so — that's ODK Central's job) | Acceptable, but a brand-new DA with *no* forms is stuck at step 1 of the ODK guide before touching R. Worth a one-line "this part is web-only" flag up top. |
| 3 | Practice the **CMR stage→approve** loop on my sandbox | Tempted to just upload to the `projects` blob via SE and poke around | `eri_stage_cmr()` exists but **refuses sandbox countries** ("atlantis is not registered for CMR staging") | The guide is honest that these steps are "illustrations," but it means the *most consequential* CMR steps can't be rehearsed safely. I could only `eri_ingest_cmr()` (parse). |
| 4 | Confirm a file actually landed in `staged/` / `raw/` after a write | Briefly wanted to "just look in SE" | `eri_list()` exists and worked | Resolved by the package. No real pull. |
| 5 | Inspect the approval log / operation log YAML after approving | Wanted to open the `.yaml` in SE to read who-approved-what | Partial: `eri_logs()` surfaces operation logs; the per-period `*_approval_log.yaml` is named in output but there's no `eri_*` to *print* it | Minor pull. `eri_logs()` covered 90%; reading the actual approval-log contents still implies SE/`eri_read`. |
| 6 | Move the messy raw file around / re-stage after fixing flags | None — `eri_write()` to the staged path was obvious | `eri_write()` + `eri_data_path()` | Delightfully in-package. |

**Net:** only #1 is a case where an `eri_*` function exists *and the docs steer me away from it*. That
is the highest-value fix in this report.

---

## Findings

### [major] Cleanup guides teach raw `AzureStor::delete_storage_dir()` instead of `eri_dir_delete()`
- **Doing:** Cleaning up sandboxes at the end of every guide.
- **Happened:** Every "Clean up" section calls `AzureStor::delete_storage_dir(con, "atlantis", recursive = TRUE, confirm = FALSE)` and `AzureStor::delete_storage_file(...)`.
- **Expected:** An `eri_*` function for the most basic file-and-folder operation a DA does. There **is** one: `eri_dir_delete()` and `eri_delete()` are exported (`R/dal.R`, `NAMESPACE`), and they call `.eri_log_session()` so the delete is **audited** — unlike the raw AzureStor calls, which leave no erifunctions trail.
- **Where:** `vignettes/da-onboard-guide.Rmd` §6, `da-ingest-guide.Rmd` §8, `da-odk-guide.Rmd` §5, `da-logs-guide.Rmd` §5 (all "Clean up").
- **Fix (doc):** Replace the `AzureStor::` cleanup calls with `eri_dir_delete("atlantis", azcontainer = data_con)` / `eri_delete("schemas/atlantis_malaria.yaml", azcontainer = data_con)`. This keeps a DA inside `erifunctions` for the single operation she's most tempted to do in Storage Explorer, and gains an audit log for free.
- **Fix (feature, optional):** If `eri_dir_delete()` needs a `recursive`/`confirm` arg to match `delete_storage_dir`, surface it; verify it deletes non-empty namespaces in one call.

### [major] Analyst identity silently falls back to the OS username in approval/audit logs
- **Doing:** Approving extracts and CMR; reading the approval banner.
- **Happened:** Every approval printed `Approver: NishantKishore` (my Windows login), not a `firstname.lastname` analyst id. `ERI_ANALYST_ID` was never set, and nothing warned me.
- **Expected:** The README and connections guide both bill `ERI_ANALYST_ID` as the identity that "appears in approval and access logs." A fresh DA who doesn't set it will silently stamp the shared, governed audit trail with an arbitrary machine username — and never know.
- **Where:** `R/dal.R`, `R/catalog.R`, `R/cmr.R`, `R/logs.R`, `R/odk*.R` all use `Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])`. Surfaced in `eri_approve()` output.
- **Fix (feature):** On the first governed write of a session, if `ERI_ANALYST_ID` is unset, emit a one-time `cli::cli_warn()`: *"ERI_ANALYST_ID is not set; approvals will be logged as '<osuser>'. Set it in .Renviron."* Cheap, and it protects the integrity of the audit trail.
- **Fix (doc):** The connections guide's "confirm it works" section could include a `Sys.getenv("ERI_ANALYST_ID")` check alongside the Azure/ODK checks.

### [minor] Success and routine-info messages render in alarming red (ANSI bold-red)
- **Doing:** Every step.
- **Happened:** `✔ Connected…`, `✔ Approved…`, `ℹ Operation log:…`, and even the DQ report all printed in **bold red** in my terminal. As a fresh user my first instinct on seeing red was "something broke."
- **Expected:** Green/blue for success/info, red reserved for warnings/errors. This is almost certainly a `cli`/terminal theme interaction (Rscript on Windows PowerShell), but it materially undermines the "narration that reassures" design — a green ✔ that prints red reads as a failure.
- **Where:** all `cli::cli_*` output; observed running `Rscript.exe` under PowerShell 7.
- **Fix:** Confirm `cli` theme/`crayon` colour detection under non-RStudio Windows terminals; document the expected colours (or note that colour may be absent/odd in some terminals so users don't misread red ✔ as failure).

### [minor] `readr` column-spec dump erupts in the middle of a clean DQ run
- **Doing:** `eri_read()` of a CSV from `raw/`, then `run_dq_checks()`.
- **Happened:** Between my steps, a full `Rows: 10 Columns: 5 / ── Column specification ── / Delimiter: "," / chr (2)… / ℹ Use spec()…` block printed (in red, per above). It looks like a problem; it's just `readr` being chatty.
- **Expected:** `erifunctions` "renders its own output" — this raw `readr` noise breaks that. A DA can't tell it apart from a real message.
- **Where:** `eri_read()` CSV path (`R/dal.R`); whatever calls `readr::read_csv()` without `show_col_types = FALSE`.
- **Fix:** Pass `show_col_types = FALSE` (or wrap in `suppressMessages`) inside `eri_read()`'s CSV branch.

### [minor] Top-level auto-printed `NULL`s clutter scripted output
- **Doing:** Running guide steps as a script (not interactively).
- **Happened:** `eri_dir_create()`, `eri_write()`, etc. auto-print `NULL` at top level, so my console had stray `NULL` lines between real output.
- **Expected:** Invisible return for side-effecting writers. Interactive RStudio users won't see this; scripted/CI users (and `Rscript`) do.
- **Where:** `eri_dir_create()`, `eri_write()`, `eri_upload()` return values.
- **Fix:** `return(invisible(...))` on the side-effecting helpers.

### [minor] CMR stage→approve loop cannot be rehearsed on a sandbox
- **Doing:** Trying to run the *whole* CMR guide on `atlantis`, like I could for surveillance/ODK.
- **Happened:** `eri_stage_cmr("atlantis", "202406")` errors: *"Country 'atlantis' is not registered for CMR staging."* (clean, well-worded error — good). Only `eri_ingest_cmr()` (offline parse) is runnable on a sandbox.
- **Expected:** The surveillance and ODK guides let me practice the full gate end-to-end on a throwaway namespace; the CMR guide can only *show* me stage/approve. So the riskiest CMR steps are the ones I never get to rehearse.
- **Where:** `vignettes/da-cmr-guide.Rmd` §2/§4; `eri_stage_cmr()` country allow-list.
- **Fix (doc):** Add a short "you can't sandbox the stage/approve steps — here's a dry-run or a read-only walkthrough instead" note, OR (feature) let `eri_ingest_cmr()` → `eri_write(staged)` → `eri_approve(country,"rblf","cmr",period)` be demoed against a sandbox country the way surveillance is, decoupling the gate from the `projects`-blob fetch.

### [minor] "Catalog is empty" message prints even for a *filtered* query that simply has no matches
- **Doing:** Verifying cleanup with `eri_catalog_query(country = "atlantis", ...)`.
- **Happened:** Output said **"Catalog is empty."** — but the catalog is *not* empty system-wide; my *filter* just matched nothing. A fresh DA might think they nuked the whole team catalog.
- **Where:** `eri_catalog_query()` empty-result message (`R/catalog.R`).
- **Fix:** Distinguish "no entries match your filter" from "the catalog is empty."

### [polish] `eri_list()` returns full paths in `name`, not leaf filenames
- **Doing:** Listing `uga/demo/odk/raw` after sync.
- **Happened:** The `name` column was `uga/demo/odk/raw/eri_test_river_repeat.parquet` (full path), whereas the guides' example outputs read like leaf names. Not wrong — `full_names = TRUE` is the documented default — just a small mismatch with the guide's illustrative output.
- **Fix (doc):** Make the guide outputs match, or mention `full_names = FALSE` for leaf names.

### [polish] `renv` "project is out-of-sync" warning greets every command
- **Doing:** Every single `Rscript` invocation.
- **Happened:** `- The project is out-of-sync -- use 'renv::status()' for details.` printed before all my output. As a fresh user told to use `renv`, this nags me to "fix" something that isn't my problem.
- **Note:** This is a dev-checkout artifact (I ran `devtools::load_all()` in the repo), not what an installed-package user sees, so it's low priority — but a brand-new DA following the install-with-renv instructions could hit a cousin of it and worry.

---

## What worked / delighted (don't regress these)

- **Azure was genuinely zero-config.** Cached token, browser-free, `eri_list("")` returned a tibble first try. The "nothing to configure" promise held.
- **The onboarding dry-run is exactly right.** `dry_run = TRUE` printed the *entire* footprint (one local file + three folders) before touching anything. That's the confidence a non-developer needs.
- **The schema validate loop is a joy.** Empty tibble = valid; fat-fingering `numeric`→`numbr` produced a precise per-row tibble *and* a readable warning. I knew exactly what to fix.
- **The DQ flags table is the star of the show.** `result$flags` told me *row, column, value, issue* for the age-250 and unknown-district cases. The corrections-vs-flags distinction ("we fixed what's safe; you decide the rest") is the right mental model and it's taught well.
- **The ODK repeat-group story is excellent.** `download_odk_form(tables = TRUE)` returned both parent and child tables, `eri_odk_sync()` wrote one parquet each, and the `PARENT_KEY`→`KEY` join worked verbatim from the guide. Nothing was silently dropped, exactly as promised.
- **`eri_logs()` is a real shared backlog.** I made a DQ-flag log and a deliberate approve-failure; `eri_logs()` listed both, `status = "error"` filtered, `eri_logs_resolve()` dropped the "needs attention" count from 2→1 while keeping the record. This is the feature that would actually let me cover for an out-of-office teammate.
- **Error messages are humane.** "Country 'atlantis' is not registered for CMR staging. ℹ Registered countries: …" and "No staged files found matching '2024-09'…" both told me what was wrong *and* what's valid. That's better than most production R packages.
- **Cleanup verified clean.** After teardown, `atlantis` was gone from the top level, only the real `uga/LF` remained under `uga` (my `uga/demo` removed), no `demo` form was active in the registry, and the soft-delete (deregister) correctly preserved an inactive registry record.

---

## Top 5 changes that would most improve my day (ranked)

1. **Use `eri_dir_delete()` / `eri_delete()` in every guide's cleanup section** instead of raw `AzureStor::`. This is the only place the docs send me to Storage Explorer for something the package already does — and it loses the audit log. (major, doc-only, trivial)
2. **Warn once when `ERI_ANALYST_ID` is unset** before stamping a governed approval with my OS username. Protects the shared audit trail. (major, small feature)
3. **Tame the scary output:** suppress `readr`'s column-spec dump inside `eri_read()`, and verify success ✔ messages aren't rendering as bold red in non-RStudio terminals. (minor, makes the whole package *feel* trustworthy)
4. **Tell me up front which steps can't be sandboxed** — ODK form upload/submission (web-only) and the CMR stage→approve loop (registered countries only) — so I'm not stuck wondering. (minor, doc)
5. **Fix the "Catalog is empty" message** to distinguish a no-match filter from a truly empty catalog. (minor, prevents a panic)

---

## Issue-ready list

- **Guides delete sandboxes with raw AzureStor instead of `eri_dir_delete()`** — Replace `AzureStor::delete_storage_dir/file` in all four DA guides' Clean-up sections with `eri_dir_delete()`/`eri_delete()`; keeps DAs in-package and audited.
- **Warn when `ERI_ANALYST_ID` is unset** — Governed writes silently fall back to the OS username (e.g. `NishantKishore`) in approval/access logs; emit a one-time `cli_warn` on first governed write of a session.
- **Suppress `readr` column-spec output in `eri_read()`** — A CSV read prints a full `readr` spec dump mid-pipeline, looking like an error during a clean DQ run; pass `show_col_types = FALSE`.
- **Success/info `cli` messages render bold-red under Windows/PowerShell** — Verify `cli`/crayon colour detection so green ✔ doesn't read as a failure to fresh users; document expected colours.
- **Side-effecting helpers auto-print `NULL` in scripts** — `eri_dir_create()`/`eri_write()`/`eri_upload()` should `invisible()` their return to avoid stray `NULL` lines in scripted/CI runs.
- **CMR stage→approve can't be rehearsed on a sandbox** — `eri_stage_cmr()` rejects non-registered countries, so the riskiest CMR steps are undemonstrable on `atlantis`; add a doc note or a sandbox-friendly demo path.
- **`eri_catalog_query()` says "Catalog is empty" for a no-match filter** — Distinguish "no entries match your filter" from "the catalog is empty" to avoid implying the shared catalog was wiped.
- **ODK & CMR guides should flag web-only/registered-only steps up front** — Brand-new DAs hit "upload the form in the web UI" (ODK §1) and "registered countries only" (CMR) with no warning; call these out before the steps.
- **`eri_list()` full-path vs leaf-name mismatch with guide outputs** — Either align the guide example outputs or mention `full_names = FALSE`.

---

## Prior learnings re-confirmed / fixed

None — this is the first red-team run; `docs/feedback/red-team-learnings.md` was empty. This report
should seed its "Known findings" index. The durable pattern worth carrying forward: **the API is
strong and the guides are good; the remaining friction is (a) docs steering users out of the package
for delete, (b) silent identity fallback, and (c) cosmetic output that reads as failure.**
