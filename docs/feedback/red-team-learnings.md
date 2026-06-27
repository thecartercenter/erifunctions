# Red-team learnings (cumulative)

Persistent memory for the fresh-user red-team agents ([`da-fresh-user`](../../.claude/agents/da-fresh-user.md)
and [`epi-fresh-user`](../../.claude/agents/epi-fresh-user.md)). Each run **reads this first** to avoid
re-reporting known items, and we append the durable lessons here after each round so future runs build
on prior findings rather than starting cold.

How to use this file:
- **Before a run:** the agent reads the "Known findings" table and skips/cross-references anything
  already captured; it still re-confirms whether prior items are fixed.
- **After a run:** the orchestrator appends new durable learnings (patterns, recurring confusions,
  decisions made) — not every one-off nit, just what should shape the next run and the docs/API
  direction.

## Run log

| Date | Persona | Report | Headline result |
|------|---------|--------|-----------------|
| 2026-06-26 | Dana (DA) | [da-feedback-2026-06-26](da-feedback-2026-06-26.md) | A fresh DA *can* do the whole job on erifunctions; friction is narrow — cleanup, identity, scary output. |
| 2026-06-26 | Eli (Epi) | [epi-feedback-2026-06-26](epi-feedback-2026-06-26.md) | An epi *would* use reconcile + anomaly QC; the wall is vocabulary drift + stale README, not the analysis machinery. |

## Known findings (de-dup index)

Status legend: ⬜ open · 🔧 in progress · ✅ fixed. Update when a fix lands.

| # | Severity | Area | Finding | Persona | Status |
|---|----------|------|---------|---------|--------|
| F1 | major | docs | Guide Clean-up sections use raw `AzureStor::delete_storage_dir/file` instead of the exported, audited `eri_dir_delete()`/`eri_delete()` (6 vignettes). The one place docs steer users out of the package. | Dana | ⬜ |
| F2 | major | code | `ERI_ANALYST_ID` silently falls back to the OS username when unset; governed approval/access logs get stamped with an arbitrary machine login, no warning. | Dana | ⬜ |
| F3 | major | code | `eri_spatial_reconcile()` returns `geocoded_review` + coords but not the admin unit the point fell in (computed internally, discarded) — forces a manual `sf::st_join`. | Eli | ⬜ |
| F4 | major | docs+code | "data_type" vocabulary diverges: schema side uses `malaria_case` (`load_dq_schema`), layer/catalog side accepts only `surveillance\|cmr\|odk` (`eri_data_path`/`eri_catalog_query`), no crosswalk. Blocks QC'd→approved sourcing path. | Eli | ⬜ |
| F5 | major | docs | README "Supported countries" lists DR/HT program as `malaria`, but the loader needs `malaria_case` (`load_dq_schema("dr","malaria")` errors). Schema files also double-named (`dominican_republic_malaria.yaml` + `dr_malaria_case.yaml`). "No schema" error doesn't enumerate valid keys. | Eli | ⬜ |
| F6 | minor | code | `eri_read()` CSV path leaks `readr` column-spec dump mid-pipeline (no `show_col_types = FALSE`). | Dana | ⬜ |
| F7 | minor | code | Side-effecting writers (`eri_dir_create`/`eri_write`/`eri_upload`) auto-print `NULL` in scripts (no `invisible()`). | Dana | ⬜ |
| F8 | minor | code | Success/info `cli` messages render bold-red under Rscript+PowerShell on Windows — green ✔ reads as failure. | Dana | ⬜ |
| F9 | minor | code | `eri_catalog_query()` prints "Catalog is empty" for a no-match *filter*, implying the shared catalog was wiped. | Dana | ⬜ |
| F10 | minor | docs | README research-lifecycle reference stale: omits `eri_research_scaffold/_tag/_status`; `init` vs `scaffold` entry point ambiguous. | Eli | ⬜ |
| F11 | minor | docs | `load_dq_schema()` examples pass `"malaria_case"` positionally as `disease` while prose frames it as a data_type — name the arg + one clarifying sentence. | Eli | ⬜ |
| F12 | minor | docs | ODK & CMR guides don't flag non-sandboxable steps up front (ODK form upload = web-only; CMR stage→approve = registered countries only). | Dana | ⬜ |
| F13 | polish | code | `dq_report()` summary says "1 row [species]" without the offending value/row; detail in `result$flags` but nothing points there. | Eli | ⬜ |
| F14 | polish | docs | `eri_list()` returns full paths in `name` (documented `full_names=TRUE` default) while guide example outputs read as leaf names. | Dana | ⬜ |

## Issues filed (2026-06-26 run)

14 findings → 9 deduped issues:

| Issue | Findings | Title |
|-------|----------|-------|
| [#170](https://github.com/thecartercenter/erifunctions/issues/170) | F1 | Guides use raw `AzureStor::delete_*` instead of `eri_dir_delete()`/`eri_delete()` |
| [#171](https://github.com/thecartercenter/erifunctions/issues/171) | F2 | Warn when `ERI_ANALYST_ID` is unset before stamping governed logs |
| [#172](https://github.com/thecartercenter/erifunctions/issues/172) | F6,F7,F8 | Fresh-user output hygiene (`eri_read` readr dump, `NULL` auto-print, red success) |
| [#173](https://github.com/thecartercenter/erifunctions/issues/173) | F9 | `eri_catalog_query()` "no match" vs "Catalog is empty" |
| [#174](https://github.com/thecartercenter/erifunctions/issues/174) | F3 | `eri_spatial_reconcile()` return geocoded admin unit for review rows |
| [#175](https://github.com/thecartercenter/erifunctions/issues/175) | F4 | Unify/document the `data_type` vocabulary crosswalk |
| [#176](https://github.com/thecartercenter/erifunctions/issues/176) | F5,F10,F11 | README/doc vocabulary drift; enumerate valid schema keys |
| [#177](https://github.com/thecartercenter/erifunctions/issues/177) | F12,F14 | Guides flag non-sandboxable/web-only steps; `eri_list()` output |
| [#178](https://github.com/thecartercenter/erifunctions/issues/178) | F13 | `dq_report()` surface offending value/row |

### Resolution (all shipped 2026-06-27)

Every issue from the first run was fixed and merged — findings F1–F14 are **resolved** (future runs
should treat them as closed and only re-flag a regression):

| Issue | PR | Outcome |
|-------|----|---------|
| #170 | #180 | Guides clean up via `eri_dir_delete()`/`eri_delete()` (6 vignettes) |
| #172 | #181 | `eri_read()` quietened; side-effecting writers `invisible()`; red-✔ confirmed an stderr artifact, not a bug |
| #173 | #182 | `eri_catalog_query()` "no match" vs "empty catalog" |
| #178 | #183 | `dq_report()` shows example offending values + `result$flags` pointer |
| #176 | #184 | `load_dq_schema()` enumerates valid keys; README research reference synced |
| #177 | #185 | ODK/CMR non-sandboxable steps flagged; `eri_list()` `full_names` noted |
| #171 | #186 | One-time `ERI_ANALYST_ID`-unset warning; identity centralised in `.eri_analyst_id()` |
| #174 | #187 | `eri_spatial_reconcile()` returns `geocoded_*` admin units for review rows |
| #175 | #188 | **Phase 1** (docs + `eri_data_path` error + ADR-0011); **Phase 2** schema-naming rename still open under #175 |

Every PR passed the `review-agent` and CI; review nits were folded in before merge. The only
carried-forward item is the **#175 Phase 2** schema-naming migration (ADR-0011).

## Durable lessons / patterns

- **The API and guides are strong; the friction is at the edges.** Both fresh users completed their
  core jobs first-try on synthetic data with guides that ran verbatim. Neither wanted to hand-roll the
  *core* machinery (DQ engine, anomaly detectors, ODK sync, geocode trust guard). Future runs should
  push harder on the *seams* — cleanup, identity, sourcing/vocabulary, output legibility — not the
  happy paths, which are solid.
- **The #1 "bail out of the package" trigger is the docs themselves** (F1: cleanup teaches AzureStor).
  When auditing for the "rely on erifunctions, not AzureStor/base R" goal, grep the guides for
  `AzureStor::`/`sf::`/`readr::` calls that have an `eri_*` equivalent — doc-level leaks matter as much
  as missing functions.
- **Vocabulary drift is the epi's main wall** (F4/F5/F11): the same concept ("kind of data") is spelled
  three ways across README / `load_dq_schema` / `eri_data_path`. Worth a single source-of-truth pass.
- **"Looks broken" ≠ "is broken"** (F6/F8): cosmetic output (red ✔, readr dumps, stray `NULL`) erodes
  a non-developer's trust even when nothing failed. Cheap to fix, high trust payoff.
- **Functions that compute an answer then discard it** are a recurring "bail to sf/base-R" source (F3:
  reconcile does point-in-polygon then drops the polygon; F13: DQ knows the bad value then hides it).
  Surfacing already-computed detail is high-value and low-cost.
