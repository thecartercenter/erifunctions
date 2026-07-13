# Design consult: a unified interactive pipeline wizard for Data Analysts

> **Consult type:** outside design/architecture review, commissioned as a course correction.
> **Author's posture:** I read the code, not just the brief. Where the brief and the code disagree,
> the code wins and I say so.
> **One-line recommendation:** build a single `eri_do()` console wizard that carries a Data Analyst
> from "here is this month's Excel on my laptop" to "it's approved" without them typing one function
> name or one Azure path — by *stitching together functions that already exist*, absorbing
> `eri_dq_review()` as its final stage and demoting `eri_guide()` to a thin reference lookup. This is
> a small build, not a big one, because most of the machinery is already written.

---

## 1. Executive summary

The maintainer's verdict is correct, and the code backs it up. The last redesign optimised
*discoverability* — can a DA find the right guide faster — when the real ask was *execution
simplicity* — can a DA do the job without learning the tool. Those are different problems, and the
work that shipped (a reorganised reference index, per-guide metadata strips, a generated task-index
article, `eri_guide()`, next-step epilogues) mostly served the first. A DA who wants to get a monthly
report into the system still has to know that the sequence is upload → stage → split → DQ → approve,
still has to hand-construct an Azure blob path from a folder convention, and still has to decide a
`mirror_pipeline` flag they have no basis to decide. `eri_guide()` doesn't fix this: I confirmed in
`R/guide.R` that it is a *browser* — of ~32 registered tasks it can actually run exactly 4 (the
zero-argument ones), and for everything else it can only show you the call and open the vignette.
It is one more menu on top of the same 25 guides, which is precisely the complaint.

**The good news is that the hard part is already built and the remaining work is small.** The brief
frames this as replacing a "9-function" ordeal, but that count is inflated. Reading the actual code:
two of those nine (`load_cmr_schema()`, `eri_ingest_cmr()` per sheet) are read-only *inspection*, not
required mutations — `eri_split_cmr()` reads the workbook and does the parse-and-route itself — and
the last four (DQ report → flag resolve → logs resolve → approve) are **already collapsed into one
interactive session** by `eri_dq_review()` (`R/dq_review.R`), which is genuinely excellent: pure
orchestration, every decision written through immediately, safe to interrupt and resume, built on two
tiny prompt primitives. So the genuinely *new* wizard surface is only the front half — get the file
in and split it — after which control hands off to the `eri_dq_review()` loop that already works.

My recommendation is therefore concrete and bounded:

1. **Build one front door, `eri_do()`** (a new `R/wizard.R`), whose top menu is "what are you trying
   to do?" — bring in a monthly report / a surveillance file / ODK submissions / onboard a new
   program. It collects a handful of *names and decisions* and calls the existing scriptable-core
   functions in order. It never reimplements pipeline logic and never becomes the only way in.
2. **Absorb `eri_dq_review()` as the CMR flow's final stage** by extracting its main loop into an
   internal `.eri_dq_review_loop()` that both `eri_do()` and the still-exported `eri_dq_review()` call.
   Nothing about the scriptable core changes.
3. **Auto-detect `mirror_pipeline`** from `eri_cutover_status()$eligible` — I verified the return
   shape; this is a clean boolean the wizard can read itself. The DA never sees the flag.
4. **Derive every Azure path** from the pipeline registry (`.eri_pipeline_registry`) + country +
   period + the picked filename. The DA picks a *local* file with `file.choose()` /
   `rstudioapi::selectFile()` and answers "which country / which month"; the wizard builds
   `{project_folder}/{raw_dir}/{country}/{period}/{file}` itself.
5. **Demote `eri_guide()` to a reference lookup** (or retire it outright) and **cut the guide set from
   26 vignettes to ~10**, because once the wizard teaches the task by doing it, a 25-minute
   copy-paste-these-chunks walkthrough is redundant.

The single biggest change in direction: **stop adding surfaces that help a DA find instructions, and
build the one surface that makes instructions unnecessary.** Everything below is how.

---

## 2. Assessment of current state: what's reusable vs. what should retire

I read `R/dq_review.R`, `R/guide.R`, `R/task_registry.R`, `inst/registry/task_map.yaml`,
`vignettes/da-cmr-guide.Rmd`, and the signatures of every pipeline function the wizard would call
(`eri_upload`, `eri_stage_cmr`, `eri_split_cmr`, `eri_cmr_dq_report`, `eri_approve_cmr`,
`eri_cmr_last_plan`, `eri_ingest`, `eri_stage`, `eri_approve`, `eri_odk_register`, `eri_odk_sync`,
`eri_onboard_country`, `eri_onboard_cmr`, `eri_cutover_status`). Findings:

### Genuinely reusable — build on these, do not touch their behavior

- **`eri_dq_review()` and its helpers (`R/dq_review.R`).** The brief's claim that this is "the pattern
  to generalize" is exactly right, and stronger than the brief states. Every helper
  (`.eri_dq_review_walk_flags`, `.eri_dq_review_rerun`, `.eri_dq_review_force_approve`,
  `.eri_dq_review_report`) is already factored as a standalone internal — the loop is *already* one
  extraction away from being embeddable in a larger wizard. The in-memory-only path cache and
  "write through every decision immediately" discipline are exactly the interrupt-safety the brief
  demands. **Reuse wholesale.**
- **`.eri_prompt_menu()` / `.eri_prompt_line()` (`R/dq_review.R`).** Two-line primitives
  (`cli::cli_h3()` + `utils::menu()`; `readline()` with re-ask-on-blank). The brief says "don't invent
  a second prompt mechanism" — agreed. These are the foundation. I'd add exactly **two** siblings
  (`.eri_prompt_pick_country()`, `.eri_prompt_pick_file()`) built *on* them, not beside them.
- **`.eri_open_file()` (`R/dq_review.R`).** RStudio-aware file open with an OSC-8 clickable fallback.
  Reused as-is for "open the workbook to fix a value."
- **`.eri_pipeline_registry` (`R/dal.R`).** Holds `project_folder` / `raw_dir` / `country_map` per
  pipeline. This is the key to *deriving* the Azure path instead of asking for it — the wizard reads
  the same registry `eri_stage_cmr()` reads. **Reuse.**
- **`eri_cutover_status()` (`R/cutover.R`).** Returns `list(eligible, streak, n, periods)`. `eligible`
  is the exact boolean needed for silent mirror auto-detection. **Reuse.**
- **The scriptable core, all of it.** `eri_upload`, `eri_stage_cmr`, `eri_split_cmr`,
  `eri_cmr_dq_report`, `eri_approve_cmr`, `eri_ingest`, `eri_approve`, `eri_odk_register`,
  `eri_odk_sync`, `eri_onboard_*`. These stay the things that actually run. The wizard is a caller.

### Repurpose — keep the data, drop the tool

- **`inst/registry/task_map.yaml` + `R/task_registry.R`.** The *registry* is a reasonable backbone —
  it already encodes the branch/leaf tree, roles, representative calls, guide slugs, and `next:` links,
  and `test-task-map.R` keeps it honest. But it was built for a *browser*. For an *executor* it is the
  wrong shape: a leaf's `call:` is an illustrative one-liner (`eri_stage_cmr(country, period)`), not an
  executable plan. The wizard needs, per flow, an ordered list of **steps** with typed inputs
  (country = pick-from-list, period = derived, file = file-picker). I recommend keeping the tree as the
  **top-level menu source** (its 8 categories map almost 1:1 to the wizard's top menu) and adding a new
  per-flow `steps:` structure (see §3.7). Do not try to make the existing flat `call:` strings
  executable — that's the dead end `eri_guide()` already hit.
- **`eri_task_map()` (exported console printer).** Keep as a static "what can this package do" dump for
  script authors. Cheap, harmless, occasionally useful. Low priority either way.

### Retire or demote — these did not serve the goal

- **`eri_guide()` (`R/guide.R`).** This is the honest casualty. It can run 4 of 32 tasks; the other 28
  it can only *describe*, which is what the vignettes already do. Once `eri_do()` exists, `eri_guide()`
  is a strictly worse front door. **Recommendation: retire the interactive wizard, and either delete it
  or narrow it to `eri_guide(task_id)` as a pure "show me the call and open the guide for task X"
  reference lookup** (no menus, no "run it now"). I lean delete: `eri_task_map()` + the task-index
  article already cover static lookup, and keeping a second, menu-driven-but-can't-actually-do-anything
  entry point is exactly the surface-area bloat the maintainer is objecting to. If kept, it must not be
  advertised as a peer of `eri_do()`.
- **Next-step epilogues (`.eri_task_epilogue()`, the `epilogue_after:` fields).** These print a "Next:
  call `eri_dq_review(...)`" hint after `eri_split_cmr()` etc. Inside the wizard they are *noise* — the
  wizard *is* the next step; it doesn't need to tell a DA to type the call it's about to make for them.
  They retain marginal value for a script author calling the core directly. **Recommendation: keep them
  gated at "full" verbosity (already are), but suppress them while the wizard is driving** (a session
  option the wizard sets). Low urgency; not worth a dedicated PR.
- **Per-guide metadata strips + prev/next path footers.** Docs cosmetics. Not wrong, but they decorate
  a guide set that is about to shrink by 60%. Re-evaluate after the doc cut (§5), don't invest more in
  them now.

### Where the brief is wrong or incomplete (verified against code)

1. **"the CMR upload guide now no longer has the mirroring."** Not quite. `vignettes/da-cmr-guide.Rmd`
   §4 (lines ~250–254) *does* still mention it — as an inline comment on the `eri_split_cmr()` call:
   `# add mirror_pipeline = "rb-expansion" if this country needs it`. The maintainer's *spirit* is
   right (it's buried in a comment a DA will skate past, and it's opt-in), but the literal claim that
   it was removed is inaccurate. This matters because the fix isn't "put mirroring back in the guide" —
   it's "take the decision away from the human entirely" (§3.6).
2. **"Nine distinct functions."** Inflated. `load_cmr_schema()` (step 3) and `eri_ingest_cmr()` per
   sheet (step 4) are read-only inspection; `eri_split_cmr()` re-reads the workbook and parses/routes
   independently, so neither is a required mutation. And steps 6–9 are **already one function**
   (`eri_dq_review()`). The real required mutation sequence is **five** calls — upload, stage, split,
   (interactive DQ loop), approve — of which the last two are already unified. The genuinely-new build
   is the first three. Stating this honestly makes the project much smaller than the brief implies.
3. **`mirror_pipeline` value.** For CMR it's `"rb-expansion"` (the source pipeline registry key), not
   `"hsp-mal"` — that's the *surveillance* (`eri_ingest`) mirror value. The wizard must pick the right
   key per flow; it reads the registry, so this is automatic, but the design must not hardcode one.
4. **Vignette count.** 26, not ~25 (`vignettes/*.Rmd`, including the generated `task-index.Rmd`).
5. **`eri_stage_cmr()` already does two of the things the wizard needs.** It auto-selects the most
   recent period when `period = NULL`, and it validates the country against `reg$country_map`, aborting
   with the list of registered countries. So "wrong country code" and "which month" are *partly* solved
   in the core already — the wizard's job is to surface them as a **pick-list** so the DA never types a
   code or a period at all.

---

## 3. The wizard architecture

### 3.0 Name and entry

One exported function: **`eri_do()`**. Rationale: the top menu question is literally "what do you want
to do?", and `eri_do()` reads as a verb a non-developer will remember. (Alternatives considered:
`eri_start()` — collides conceptually with onboarding; `eri_wizard()` — jargon; `eri_run()` — too
close to `run_dq_checks()`. If the maintainer prefers, `eri_go()` is fine.) It refuses to run
non-interactively (same guard as `eri_dq_review()`), pointing script authors at the core functions.

```r
eri_do()            # top menu
eri_do("cmr")       # deep-link straight into the CMR flow (optional convenience)
```

### 3.1 Top-level menu / routing

```
> eri_do()

── What are you trying to do? ─────────────────────────────
1: Bring this month's country report (CMR Excel) into the system
2: Bring in a surveillance dataset (a CSV/Excel line-list)
3: Pull in ODK survey submissions
4: Set up a new country, disease, or report type
5: Review & approve something already staged (jump to DQ review)
6: I just want to look something up (guides & reference)
0: Exit
```

Items 1–4 are the four pipelines the brief names. Item 5 is the pure-DQ entry (what `eri_dq_review()`
is today) preserved as a shortcut for "I already staged it, I just need to finish review." Item 6 is
the *only* thing `eri_guide()`/the task index survives as — a reference escape hatch. This menu is
sourced from a new `steps:`-bearing registry (§3.7); the top branches mirror `task_map.yaml`'s
existing categories so we reuse that structure.

Routing is a `switch()` to one flow function per branch: `.eri_flow_cmr()`, `.eri_flow_ingest()`,
`.eri_flow_odk()`, `.eri_flow_onboard()`. Each flow is a linear sequence of **stages**; each stage
collects inputs (via the prompt primitives) and calls exactly one core function. All four share the
same helper vocabulary — country pick-list, period derivation, file picker, confirm-before-write,
try-catch-and-recover — so "one framework drives all four," per the brief.

### 3.2 The CMR flow, worked end to end (the concrete example)

This is the whole point, so here it is turn by turn — actual prompts, actual DA inputs (`>>`), actual
internal calls (`# calls:`). Compare against the brief's 9-function slog.

```
> eri_do()
── What are you trying to do? ──
>> 1   (Bring this month's country report into the system)

── Which country filed the report? ──
1: Ethiopia (eth)      4: South Sudan (ssd)
2: Nigeria (nga)       5: Uganda (uga)
3: Sudan (sdn)         6: Chad (tcd)      7: Madagascar (mad)
>> 5
# no typing "uga" — the list IS reg$country_map from .eri_pipeline_registry[["rb-expansion"]]

── Where is the filled Excel on your computer? ──
i A file picker will open. Choose this month's report.
# calls: .eri_prompt_pick_file()  ->  file.choose() / rstudioapi::selectFile()
>> [DA picks C:/Users/dana/Downloads/uga_cmr_2024_06.xlsx in the OS dialog]

i I read the period as 202406 from the file. Is that the reporting month?
1: Yes, 202406
2: No, let me pick a different month
>> 1
# period auto-parsed from filename (YYYYMM / YYYY_MM); DA confirms, never types it.
# Destination path DERIVED, never asked:
#   health-rb-country-expansion-dev/raw/filled_templates/uga/202406/uga_cmr_2024_06.xlsx

── Ready to bring this in ──
* Country:  Uganda (uga)
* Month:    June 2024 (202406)
* File:     uga_cmr_2024_06.xlsx
i I'll upload it, stage it, and split it into per-disease measures. Then we'll review data quality.
1: Go ahead
2: Cancel
>> 1

# calls, in order, each with a spinner + one-line success:
#   eri_upload(local, "<derived projects path>", azcontainer = projects_con)
✔ Uploaded to the reports blob.
#   eri_stage_cmr("uga", "202406")
✔ Staged uga_cmr_2024_06.xlsx.
#   mirror? .eri_wizard_should_mirror("uga", plan)  -> checks eri_cutover_status per measure
i This country is still in the parallel run, so I'll also send the raw file to the legacy pipeline.
#   eri_split_cmr(local, "uga", period = "202406", mirror_pipeline = "rb-expansion")
✔ Routed 2 measures: oncho/treatment, sch/treatment.

── Now let's check data quality ──
# HANDS OFF to the existing eri_dq_review loop, extracted as .eri_dq_review_loop():
── DQ review: uga / 202406 ──
✖ 1 of 2 sheets have open flags (1 flag total)
── RB Treatment (oncho/treatment) — 1 open ──
 excel_row column value issue
         4 target  0    out of range

── What do you want to do with this flag? ──
1: Fix in source (open/copy the workbook)
2: Adjust the schema (alias, allowed value, range...)
3: Mark not important
4: Mark noted
5: Skip to the next flag
>> 3
Note (optional): >> confirmed with country: target genuinely 0 this period
✔ Flag marked not important.

── Nothing outstanding. What next? ──
1: Approve
2: Print report
3: Exit
>> 1
#   eri_approve_cmr("uga", "202406", plan = plan)
✔ Approved 2 measures for uga / 202406.

🎉 Done. This month's Uganda report is approved and in the catalog.
   (You can query it with eri_query() or see it in eri_catalog_query(country = "uga").)
```

Every one of the brief's nine steps happened. The DA typed: one menu number, one menu number, picked a
file in a dialog, confirmed a month, confirmed "go ahead", triaged one flag with a one-line note, and
confirmed "approve." **No function names. No Azure path. No `mirror_pipeline` decision.** The DQ half is
not reimplemented — it is literally the `eri_dq_review()` loop, entered as a stage.

### 3.3 File selection and path derivation (no hand-typed Azure path)

Two new helpers, both built on the existing primitives:

- **`.eri_prompt_pick_file(prompt)`** — `rstudioapi::selectFile()` when available (RStudio), else
  `file.choose()` (works in a bare console; opens the OS dialog on Windows/macOS). Falls back to
  `.eri_prompt_line()` only if both are unavailable (headless server) — the same graceful-degradation
  posture `.eri_open_file()` already takes. Returns a validated local path; re-asks if the file doesn't
  exist (reusing the `eri_dq_review()` fix-in-source validation pattern).
- **`.eri_derive_cmr_destination(country, period, filename)`** — reads
  `.eri_pipeline_registry[["rb-expansion"]]` for `project_folder` / `raw_dir` and returns
  `{project_folder}/{raw_dir}/{country}/{period}/{filename}`. This is the *same construction*
  `eri_stage_cmr()` uses internally (`src_base <- paste(c(reg$project_folder, reg$raw_dir, country), …)`),
  so the wizard and the core can't drift.

Period is auto-parsed from the filename (`\d{4}[_-]?\d{2}` → `YYYYMM`) and **confirmed, not typed**. If
parsing fails or the DA rejects it, fall back to a pick-list of the last 12 `YYYYMM` values, or a
typed-with-validation `.eri_prompt_line()` that re-asks until it matches `^\d{6}$`.

### 3.4 How the DQ-triage stage is entered and exited

Refactor `eri_dq_review()` so its `repeat { … }` body becomes an internal
**`.eri_dq_review_loop(country, period, plan, data_con)`**. Then:

- `eri_dq_review()` (still exported, unchanged signature/behavior) = connect + fetch plan +
  `.eri_dq_review_loop()`. Backward compatible; the item-5 shortcut and every existing caller keep
  working.
- The CMR flow, after a successful split, calls `.eri_dq_review_loop()` with the *plan it just built*
  (no `eri_cmr_last_plan()` round-trip needed — it has the plan in hand). The loop already offers
  Approve when clean and Force-approve when not, so **the flow needs no approve stage of its own** — the
  loop owns the exit. The wizard prints the closing "🎉 Done" only if the loop exited via an approval
  (the loop should return an invisible status — `"approved"` / `"exited"` / `"force_approved"` — a
  one-line change to its `break` points).

This is the cleanest possible absorption: no logic moves, one loop body gets a name, two callers share
it. The brief's "DQ triage becomes an internal stage, not a separate thing to reach for" is satisfied
literally.

### 3.5 How ingest / ODK / onboarding fit the same framework

Same skeleton — *collect identifying values → confirm → call core in order → (DQ loop if one exists) →
approve gate* — differing only in which values and which calls:

- **Surveillance ingest (`.eri_flow_ingest()`):** country pick-list (from the broader registered-country
  set, not just RB-expansion) → disease pick-list → `data_source`/`data_type` pick-lists (defaulting to
  `surveillance`/`aggregate`, the function defaults) → file picker → confirm →
  `eri_ingest(path, country, disease, data_source, data_type, mirror_pipeline = <auto>)`. `eri_ingest()`
  already persists DQ flags into the `eri_logs()` backlog, so the DQ stage here is
  `eri_logs()`-driven triage (a lighter loop than CMR's per-sheet one — reuse `.eri_dq_review_loop()`'s
  flag-walk helper against the ingest log) → `eri_approve(country, disease, data_source, period,
  data_type)`.
- **ODK (`.eri_flow_odk()`):** is this form already registered? → if not, collect
  `project_id`/`form_id`/`country`/`disease`/`server_url` (server_url from a small known-servers
  pick-list) and `eri_odk_register(...)`; if yes, pick from `eri_odk_list_registered()` → confirm →
  `eri_odk_sync(project_id, form_id)` → DQ/cleaning review → `eri_approve()`. ODK has no `mirror_pipeline`.
- **Onboarding (`.eri_flow_onboard()`):** "new surveillance country / new disease / new CMR-reporting
  country" sub-menu → collect `country_code`/`country_name`/`disease`/`language` (language from a
  pick-list) → **always dry-run first** (`dry_run = TRUE`, show what would be created) → confirm → real
  run (`eri_onboard_country(...)` or `eri_onboard_cmr(..., create_dirs = TRUE)`). Onboarding has no DQ
  or approve gate; it ends by pointing the DA back to `eri_do()` → "bring in a report" for the country
  they just created.

The shared helpers (`.eri_prompt_pick_country`, `.eri_prompt_pick_file`, `.eri_wizard_confirm`,
`.eri_wizard_step` — a wrapper that runs one core call inside a `tryCatch` with a spinner and standard
error recovery) mean each flow function is ~40–60 lines of "ask, confirm, call," not a reimplementation.

### 3.6 `mirror_pipeline` auto-detection (never asked)

`eri_cutover_status(country, disease, data_source, data_type)` returns `list(eligible, streak, n,
periods)`. A stream that is **not yet `eligible`** (streak < N) still needs the legacy dual-write; an
`eligible` stream is ready to retire it. So:

```r
.eri_wizard_should_mirror <- function(country, plan) {
  # CMR fans out to several disease/measure streams; mirror if ANY constituent
  # stream hasn't yet proven parity (eligible == FALSE). Conservative on purpose:
  # keep mirroring until every stream this workbook feeds is provably cut-over-ready.
  any(vapply(seq_len(nrow(plan)), function(i) {
    st <- tryCatch(
      eri_cutover_status(country, plan$disease[i], "programmatic", plan$data_type[i]),
      error = function(e) list(eligible = FALSE)   # unknown -> mirror (safe default)
    )
    !isTRUE(st$eligible)
  }, logical(1)))
}
```

If it returns `TRUE`, the wizard passes `mirror_pipeline = "rb-expansion"` (CMR) / `"hsp-mal"`
(surveillance) and prints one honest line ("this country is still in the parallel run, so I'll also
send it to the legacy pipeline"). If `FALSE`, it mirrors nothing and says nothing. The DA never decides.
Unknown/unrecorded streams default to mirroring — the safe direction (an extra legacy copy never loses
data; a *missing* one breaks the parallel run). This is exactly the "automatable from data already in
the system" call the brief asks for, and it's a ~12-line helper.

### 3.7 The registry restructure

Add a `steps:` block to each executable branch in `task_map.yaml` (or a sibling `flow_map.yaml` if we
don't want to overload the browse registry — I lean sibling, to keep the test-checked browse registry
stable). Each step declares its input `kind` so the wizard knows how to collect it:

```yaml
- id: cmr
  flow:
    - call: eri_upload
      inputs:
        local:  {kind: file_pick,  prompt: "Where is the filled Excel on your computer?"}
        country: {kind: country_pick, source: rb-expansion}
        period:  {kind: period_derive, from: local}
        file_loc: {kind: derive, using: cmr_destination}
    - call: eri_stage_cmr        # inputs: country, period (already collected)
    - call: eri_split_cmr        # inputs: local, country, period; mirror_pipeline: {kind: auto_mirror}
    - stage: dq_review           # hands to .eri_dq_review_loop()
```

`kind` values (`file_pick`, `country_pick`, `period_derive`, `derive`, `auto_mirror`, `menu`, `line`)
each map to one collector helper. This is the schema `eri_guide()` *couldn't* have because it stored
only a flat illustrative `call:` — and it's the reason the wizard can execute where `eri_guide()` could
only display. A `test-flow-map.R` mirrors `test-task-map.R`: every `call:` is a real exported function,
every declared input is a real parameter of that function, every `kind` is known. Keeps the flow
definitions honest the same way the task map is kept honest today.

### 3.8 Error handling and recovery (the realistic failures)

Every core call runs inside `.eri_wizard_step()`, a `tryCatch` wrapper that turns an abort into a menu,
never a stack trace dumped at a non-developer:

- **Wrong country code:** can't happen — country is a pick-list, not typed. (If a deep-link
  `eri_do("cmr", country = "uzz")` is ever added, it validates against `reg$country_map` and falls back
  to the pick-list, reusing `eri_stage_cmr()`'s existing abort message as the source of truth.)
- **File not found / wrong file:** the picker validates existence and re-asks; if the DA picks a
  non-`.xlsx`, warn and re-offer the picker. If `eri_split_cmr()` later aborts "No routable sheets"
  (schema doesn't route this country yet), catch it and show: *"This looks like Uganda's template but no
  sheets are set up to route yet. This usually means the country's CMR schema needs finishing — want me
  to (1) show you what's missing, (2) file a feedback ticket, (3) stop here?"* — turning a raw abort
  into a decision.
- **A DQ flag the DA doesn't understand:** the DQ loop already offers "Mark noted" and "Skip to the
  next flag," and "Fix in source" opens the workbook with the exact cell called out
  (`.eri_dq_review_fix_in_source` already does this). Add one menu item to the flag walk: **"I'm not
  sure — flag this for someone else"**, which calls `eri_feedback()` with the flag context attached (the
  `context`/`attachment` params already exist per ADR-0014) and marks the flag `noted`, so the DA is
  never stuck. This is a ~10-line addition to the existing walk helper.
- **Mid-pipeline failure (upload OK, stage fails):** because every step writes through immediately and
  the core is idempotent-friendly (`eri_stage_cmr(overwrite=…)`, `eri_split_cmr(supersede_staged=…)`,
  approval re-checks), the recovery is "re-run `eri_do()` → same flow → it detects what's already done."
  The wizard should, at each stage, *detect prior progress* (does the staged file already exist? does
  `eri_cmr_last_plan()` return a plan?) and offer **"Looks like you already staged/split this month —
  (1) continue from DQ review, (2) start over"**. This is the interrupt-safety the brief demands, and it
  falls out of the core's existing statelessness — the wizard reads state from Azure, holds none itself.
- **Auth/network errors:** caught by `.eri_wizard_step()`, shown as "Couldn't reach Azure — check your
  connection and sign-in, then choose Retry," with Retry/Skip/Exit. No traceback.

### 3.9 What becomes of `eri_guide()`'s task registry

The **tree structure and the 8 categories survive** as the top-menu backbone and the browse/reference
surface. The **`eri_guide()` interactive wizard is retired** (delete `R/guide.R`, or reduce it to a
non-menu `eri_guide(task_id)` lookup — see §2). The registry gains the `steps:`/`flow:` block (§3.7) for
the four executable flows. `eri_task_map()` and the task-index article stay as static reference. Net:
one interactive front door (`eri_do()`), one static reference (`eri_task_map()`/task-index), zero
menu-that-can't-do-anything.

---

## 4. Implementation plan

Bounded and phased. The heavy lifting (DQ loop, prompt primitives, path derivation, cutover status) all
already exists; this is mostly orchestration and glue.

### New files / functions

- **`R/wizard.R`** (new): `eri_do()` (exported) + `.eri_flow_cmr()`, `.eri_flow_ingest()`,
  `.eri_flow_odk()`, `.eri_flow_onboard()` + shared helpers `.eri_prompt_pick_country()`,
  `.eri_prompt_pick_file()`, `.eri_wizard_confirm()`, `.eri_wizard_step()`,
  `.eri_wizard_should_mirror()`, `.eri_derive_cmr_destination()`, `.eri_wizard_detect_progress()`.
- **`R/dq_review.R`** (edit): extract the `repeat { … }` body into `.eri_dq_review_loop()`; have both
  `eri_dq_review()` and `.eri_flow_cmr()` call it; make the loop return an invisible exit-status. No
  behavior change to the exported function.
- **`inst/registry/flow_map.yaml`** (new, or a `flow:` block in `task_map.yaml`): the per-flow step
  definitions (§3.7).
- **`R/flow_registry.R`** (new, small): loader + the `kind`→collector dispatch, mirroring
  `R/task_registry.R`'s convention.
- **`tests/testthat/test-wizard.R`** (new): scripted-`.eri_prompt_menu()` mocking exactly like
  `test-dq_review.R`/`test-guide.R` — drive a full CMR flow with a stubbed core, assert the right core
  functions are called in the right order with the derived path/period/mirror flag. **Note the
  `test-guide.R` near-miss in the roadmap** (a mock closure that never advanced hit live Azure in a
  runaway loop) — the wizard tests must use the fixed mocking pattern and never fall through to a real
  connection.
- **`tests/testthat/test-flow-map.R`** (new): integrity checks on the flow definitions (every `call:` a
  real function, every input a real parameter, every `kind` known).
- **`vignettes/da-cmr-guide.Rmd`** and friends: rewritten/cut per §5.

### Reused unchanged (no edits)

The entire scriptable core: `eri_upload`, `eri_stage_cmr`, `eri_split_cmr`, `eri_cmr_dq_report`,
`eri_dq_flag_resolve`, `eri_logs_resolve`, `eri_approve_cmr`, `eri_ingest`, `eri_stage`, `eri_approve`,
`eri_odk_register`, `eri_odk_sync`, `eri_onboard_country`, `eri_onboard_cmr`, `eri_cutover_status`,
`eri_cmr_last_plan`. The prompt primitives and `.eri_open_file()`. **This is the "pure orchestration,
not reimplementation" and "never the only way in" constraint, satisfied by construction.**

### Deprecated / deleted

- **`eri_guide()` (`R/guide.R`):** delete the interactive wizard (or narrow to a non-menu lookup). Update
  `NAMESPACE`, `_pkgdown.yml`, `pkgdown/index.md`, `README.md` cross-links. If deleting, add a
  `.Deprecated()`-style shim for one release pointing at `eri_do()`.
- **`.eri_guide_*` helpers:** delete with `eri_guide()`.
- **Next-step epilogues:** keep the functions, suppress under the wizard (a session option); do not
  invest further.

### Phasing

- **Phase A (the spine, ships the win):** `R/wizard.R` with `eri_do()` + `.eri_flow_cmr()` +
  `.eri_dq_review_loop()` extraction + the CMR `flow_map` + tests. This alone delivers the maintainer's
  headline ask (one-command CMR upload) and proves the framework. Everything else is replication.
- **Phase B:** `.eri_flow_ingest()` + `.eri_flow_odk()` on the same helpers.
- **Phase C:** `.eri_flow_onboard()` + retire/narrow `eri_guide()` + the documentation cut (§5).
- **Phase D (optional):** progress-detection polish, `eri_do("cmr")` deep-links, feedback-on-confusing-flag.

Phase A is the only one that needs to ship to declare the correction made; B–D are follow-ons that don't
block it.

---

## 5. Documentation-cutting plan

There are **26 vignettes**. The wizard teaches each task *by doing it*, so the long "copy-paste these 10
chunks in order" walkthroughs are the redundancy. Target: **~10 docs**, in three tiers.

### Cut / merge (10 vignettes → folded into a short "How the pipelines work" reference or deleted)

- **`da-cmr-guide.Rmd`** — the 25-minute, 9-step walkthrough is exactly what `eri_do()` replaces.
  **Cut to a 1-page "CMR reference"**: the `raw → staged → processed` diagram, the `rblf`/per-disease
  note, and one line — "To do this, run `eri_do()` and pick 'monthly country report.'" Keep the
  field-code explanation (it's genuine domain knowledge, not tool mechanics).
- **`da-ingest-guide.Rmd`, `da-odk-guide.Rmd`, `da-onboard-guide.Rmd`, `da-dq-review-guide.Rmd`** —
  same treatment: each becomes a short "what this pipeline does + `eri_do()` covers it" reference, or
  merges into a single **`pipelines-reference.Rmd`**. `da-dq-review-guide` largely disappears into the
  `eri_do()` walkthrough.
- **`da-logs-guide.Rmd`, `da-qc-feedback-guide.Rmd`** — backlog/QC triage is now inside the wizard's DQ
  stage and the "flag for someone else" path; demote to short reference or fold into
  `pipelines-reference.Rmd`.
- **`onboarding.Rmd`** — the paced new-analyst checklist is *replaced by the wizard itself* as the
  onboarding path. Keep a **much shorter "first day"** doc: install, sign in, run `eri_do()`. Delete the
  step-by-step checklist.
- **`task-index.Rmd`** — keep (it's generated and cheap), but it's now a reference-tier lookup, not a
  primary path.

### Keep as-is (genuine deep-dives / domain knowledge the wizard doesn't teach)

- **`connections-guide.Rmd`** (auth/setup — pre-wizard), **`data-model-card.Rmd`** (the 5-axis
  vocabulary), **`epi-research-guide.Rmd` / `epi-reconcile-guide.Rmd` / `epi-analytics.Rmd`**
  (Epi analysis, out of the DA-pipeline wizard's scope), **`spatial-workflow.Rmd`**,
  **`adding-a-program.Rmd`** (schema authoring — a maintainer/power-user task),
  **`troubleshooting.Rmd`**, **`getting-started.Rmd`** (trimmed to point at `eri_do()`).

### The new, smaller guide set (~10)

1. `getting-started` (install → sign in → `eri_do()`), 2. `connections-guide`, 3. `data-model-card`,
4. `pipelines-reference` (CMR + ingest + ODK + onboard, one page each, "run `eri_do()`"),
5. `epi-research-guide`, 6. `epi-reconcile-guide`, 7. `epi-analytics`, 8. `spatial-workflow`,
9. `adding-a-program`, 10. `troubleshooting`. Plus the generated `task-index` as reference.

That's 26 → ~11, and the DA-facing "how do I upload data" surface collapses from six walkthroughs to one
reference page plus the wizard. **The doc set stops being the product; the wizard is the product.**

---

## 6. The open question: swirl-style vs. execute-on-behalf

**Recommendation: fully menu-driven, execute-on-behalf. Not swirl.** Decisively.

`swirl` teaches R by checking a learner's *own typed R code* against an expected pattern — its whole
value is that the learner leaves able to write that code. That is the wrong goal here, by the
maintainer's own words: *"they're not going to learn a whole new set of tools just to do the same job
they're doing."* The DAs are not trying to become R programmers; they are trying to get a monthly report
approved. A swirl-style wizard would make them type `eri_split_cmr(report, "uga")` correctly — which is
exactly the memorization burden this consult exists to remove. It would also be *more* fragile: it has
to parse and validate free-typed R, handle every near-miss, and it still leaves the DA constructing
Azure paths.

The execute-on-behalf model (what `eri_dq_review()` already proves) is right because:

- It matches the actual user model — domain experts who "call functions, do not read source."
- It's the only model where "the DA never has to type an Azure path" is achievable — a teaching tool
  by definition makes them type the thing being taught.
- It's *safer*: menu choices + pick-lists + file dialogs can't be typo'd into a wrong country or a
  malformed path the way free-typed code can.
- It's already validated in this codebase. `eri_dq_review()` is the proof of concept; `eri_do()` is
  that pattern applied to the whole pipeline.

The one legitimate thing swirl offers — *the DA learns something* — is preserved cheaply by the wizard
narrating what it's doing ("I'll upload it, stage it, and split it into per-disease measures") and, for
the curious, an optional **"show me the commands you ran"** at the end that prints the equivalent
scriptable calls. That gives a motivated DA a path to graduate to scripting *without* making learning a
precondition for doing the job. Best of both, at almost no cost.

---

## 7. Candor: what from the last redesign to walk back

The brief asks for this plainly, so here it is plainly. The 7-phase docs/guidance redesign was
competent work — clean tests, clean CI, real bugs caught. But most of it optimised the wrong axis, and
some of it should now be walked back:

- **`eri_guide()` (the interactive wizard) should be retired.** This is the clearest one. It was built
  as a *browser* of the task registry, and by its own design it can run 4 of 32 tasks — the other 28 it
  can only describe, which the vignettes already do. It is a menu that mostly can't act, which is
  precisely the "more surface, still can't do the job" the maintainer is reacting to. `eri_do()`
  supersedes it entirely. Keep the registry *data*; delete the wizard (or narrow it to a non-menu
  lookup). Do not design `eri_do()` around preserving it.
- **The task-index article + per-guide metadata strips + prev/next footers were solving
  discoverability, which was not the problem.** They're not harmful and I wouldn't spend a PR ripping
  them out — but they should not be *extended*, and they'll partly evaporate when the guide set drops
  from 26 to ~11 (§5). Re-evaluate the strips/footers after the cut; several of the guides they
  decorate are about to disappear.
- **Next-step epilogues are redundant inside the wizard** and marginal outside it. Keep, suppress under
  `eri_do()`, don't extend.
- **The honest meta-lesson:** the DQ workflow redesign got this exactly right (it *collapsed* N
  functions into one guided session, `eri_dq_review()`), and then the follow-on docs consult
  generalised the *wrong half* of that lesson — it generalised "help people find the guide" instead of
  "collapse the functions." The reference reorg (Phase 1) and the front-door `pkgdown/index.md` (Phase
  4) are worth keeping; they're good navigation for a site visitor. But navigation was never the ask.
  Execution was. `eri_do()` generalises the *right* half of the DQ lesson — the collapse — to the whole
  pipeline. That's the correction.

What **not** to walk back: `eri_dq_review()` and its scriptable core (keep and build on), the
concurrency-safe metadata and cutover tooling (load-bearing for the mirror auto-detect), the reference
reorg, and the pkgdown front door. The problem was never that the last work was bad. It's that it
answered a question nobody was asking. Answer the real one.

---

### Appendix: the one-paragraph pitch for the maintainer

Today a DA memorises five-to-nine functions and hand-builds an Azure path to upload a monthly report.
Tomorrow they type `eri_do()`, pick their country from a list, pick the file from a dialog, confirm the
month, watch it upload/stage/split, triage any DQ flags in the same menu they already have, and hit
Approve. No function names, no paths, no `mirror_pipeline` decision — the wizard reads all of that from
data already in the system. It's built entirely on functions that already exist and are already tested;
the DQ half is literally the `eri_dq_review()` loop you already shipped. And it lets us delete more than
half the guides, because the tool now teaches the task by doing it.
