# Epi fresh-user red-team feedback — "Eli" — 2026-06-26

Persona: brand-new ERI epidemiologist, R-for-analysis, not a data engineer. Ran live, hands-on,
on synthetic/in-memory data only (no real country/research data pulled). R 4.5.2,
`devtools::load_all('.')`. Live keyless OSM geocode used. No Azure namespace created; temp scripts
removed; no package file edited.

---

## Headline

**Yes — I'd actually use `erifunctions` for the two core epi jobs (reconcile + anomaly QC).** Both
worked first try, matched the guides exactly, and did things I'd otherwise hand-roll badly: the
offline string-match (case/accent/typo) and the geocode **trust guard** (`geocoded_review` when the
geocoded point disagrees with my claimed parent) are genuinely better than my usual `fuzzyjoin` +
hand `st_join`. The anomaly detectors (`pct_change`, `gaps`) are framed in epi terms and gave clear,
named errors. **What would make me bail isn't the analysis machinery — it's the vocabulary.** The
single biggest wall is that the *same concept* ("what kind of data is this?") is spelled three
different ways across the README country table, `load_dq_schema()`, and `eri_data_path()` /
`eri_catalog_query()`. The moment I try to go from "I QC'd a malaria extract" to "now pull the
approved version for analysis," I'm guessing magic strings with no error message to guide me. Fix the
vocabulary and the stale README reference, surface the review-resolving details the functions already
compute, and I'd never hand-roll a geocode or QC script again.

---

## The do-it-myself-instead log (priority section)

Every moment I felt the pull to drop out of `erifunctions`:

1. **Resolving a `geocoded_review` row.** The function tells me MIT is `geocoded_review` and gives me
   coordinates, but **not which admin unit the point actually landed in.** To decide "is MIT really
   across the county line, or was the county mis-entered?" I have to take the lon/lat and run my own
   `sf::st_join` against the boundary. That is the exact "bail to sf" the team wants to prevent — and
   the function already did the point-in-polygon internally to set the status; it just doesn't return
   the answer. → *no `eri_*` surfacing exists for this; it's discarded.*
2. **Going from a QC'd extract to the approved data for analysis.** I QC'd `data_type="malaria_case"`,
   but `eri_data_path()` / `eri_catalog_query()` only accept `data_type ∈ {surveillance, cmr, odk}`.
   I had no way to know `malaria_case` maps to `surveillance`. My instinct: forget the catalog, ask a
   colleague for the blob path and `eri_read()` it directly (or just get a CSV). → *`eri_catalog_query`
   exists but the vocabulary mismatch makes it unusable without insider knowledge.*
3. **Loading the right schema.** README says DR's program is `malaria`; `load_dq_schema("dr","malaria")`
   **errors**. I only got the working call (`"malaria_case"`) by copying the guide verbatim. If I'd
   typed the disease from the README table, I'd have given up on `load_dq_schema()` and eyeballed the
   data. → *function exists; the disease string the README documents doesn't work.*
4. **Acting on a `run_dq_checks` flag.** The printed report says "1 flag … 1 row [species]" but not
   *which* value or row. My reflex was `filter(cases, species != "P. vivax")` by hand. (The detail
   *is* in `result$flags`, but nothing in the printed output tells a fresh user to look there.) →
   *data exists; not surfaced in the report.*

The good news: I never once wanted to hand-roll the geocoder itself or the gap/spike detection — those
are compelling enough to keep me in the package.

---

## Findings

### [major] Geocode review status doesn't tell me what to review
- **Doing:** Pass-2 OSM reconcile; `MIT` came back `geocoded_review` (parent mismatch).
- **Happened:** Result columns are `longitude, latitude, reconcile_status` only. My supplied (wrong)
  `county = "Suffolk"` is kept; the geocoder's *opinion* (the point fell in Cambridge/Middlesex) — the
  very reason the row was flagged — is not returned.
- **Expected:** A column with the admin unit(s) the geocoded point fell into (e.g.
  `geocoded_adm3`/`geocoded_adm2`), so I can confirm/fix without re-doing the point-in-polygon myself.
- **Where:** `eri_spatial_reconcile()`; guide `epi-reconcile-guide.Rmd` §3–4. The guide *narrates* the
  Cambridge/Middlesex answer but the output doesn't expose it.
- **Fix:** Return the matched-polygon admin columns (prefixed, e.g. `geocoded_*`) for geocoded rows,
  at least for `geocoded_review`. The function already computes this internally.

### [major] "data_type" vocabulary is inconsistent across the system
- **Doing:** Light sourcing reasoning — from a QC'd `malaria_case` extract to pulling approved data.
- **Happened:** `eri_data_path("dr","malaria","malaria_case","national","processed")` →
  `` `data_type` must be one of "surveillance", "cmr", and "odk", not "malaria_case" ``. So the
  layer-path/catalog `data_type` vocabulary (`surveillance|cmr|odk`) is different from the schema-side
  vocabulary (`malaria_case`), with no documented crosswalk.
- **Expected:** One consistent notion of "data type," or an explicit, documented mapping
  (`malaria_case → surveillance`) right where an epi would need it (the sourcing section / catalog
  help).
- **Where:** `eri_data_path()`, `eri_catalog_query()` vs `load_dq_schema()`; README "Core concepts"
  and function reference.
- **Fix:** Document the crosswalk prominently and accept the schema-level type where users naturally
  have it, or have the error list the valid values *and* hint the mapping.

### [major] README disease vocabulary doesn't match what `load_dq_schema()` accepts
- **Doing:** Trying to load the DR malaria schema using the disease name from the README country table.
- **Happened:** README "Supported countries" lists DR program = **`malaria`**, but
  `load_dq_schema("dr","malaria")` → `No schema found for "dr"/"malaria"`. The working string is
  `"malaria_case"`, discoverable only by copying the guide.
- **Expected:** The disease name documented in the README works, or the error lists the valid
  disease keys for that country.
- **Where:** README "Supported countries"; `load_dq_schema()` error path; `inst/schemas/`.
- **Fix:** Align the documented disease vocabulary with schema keys, and make the "no schema" error
  enumerate available `country/disease` pairs.

### [minor] README function reference is stale for the research lifecycle
- **Doing:** Orienting from the README before opening the flagship epi-research guide.
- **Happened:** README "Research projects" table lists `eri_research_init` and `eri_research_resume`
  but **not** `eri_research_scaffold`, `eri_research_tag`, or `eri_research_status` — all of which
  exist and are the ones the epi-research guide actually uses. As a fresh user I couldn't tell whether
  `init` or `scaffold` is the real entry point, or that tagging/status exist at all.
- **Expected:** README reference matches the guide and the exported namespace.
- **Where:** README §"Research projects"; vignette `epi-research-guide.Rmd` §1, §7, §10.
- **Fix:** Regenerate/sync the README table from the exported `eri_research_*` set; pick one entry
  point (`init` vs `scaffold`) as canonical and note the relationship.

### [minor] `load_dq_schema()` example reads as if "malaria_case" is a data_type, but it's the `disease` arg
- **Doing:** Reading the DQ guide call `load_dq_schema("dr", "malaria_case", azcontainer = NULL)`.
- **Happened:** The signature is `load_dq_schema(country, disease, azcontainer)` — so `"malaria_case"`
  is positionally the **disease**. The surrounding prose (and the README's path model) frames
  `malaria_case` as a *data type*. Conceptually whiplash; compounds the vocabulary findings above.
- **Where:** `epi-dq-guide.Rmd` §1; README "Core concepts".
- **Fix:** Name the argument in examples (`disease = "malaria_case"`) and add one sentence clarifying
  that the schema key is a `disease`, distinct from the layer-path `data_type`.

### [polish] `dq_report()` summary doesn't surface the offending value / row
- **Doing:** Reading `run_dq_checks()` output to act on the species typo.
- **Happened:** Printed report says `1 row [species]` — no value, no row index. The detail is in
  `result$flags` (row 4, "P.vivax"), but nothing tells a fresh user to look there.
- **Expected:** Either show the bad value(s) inline (e.g. `P.vivax (row 4)`) or a one-line pointer:
  "see `result$flags` for row-level detail."
- **Where:** `dq_report()` / the print method; `epi-dq-guide.Rmd` §2.
- **Fix:** Print a few example offending values, or add the `result$flags` pointer.

---

## Epi-meaningfulness

Mostly strong. Where it landed in my terms:
- `reconcile_status` values (`matched` / `geocoded` / `geocoded_review` / `unresolved`) map cleanly to
  an epi decision: *trust and roll up* vs *call someone before using*. The §4 status table is exactly
  how I'd want it framed. The trust guard ("kept your names, didn't silently correct") respects that
  *I* own the judgement call — excellent.
- `structural_gap` for a missing reporting week is the right concept: it correctly distinguishes
  "no report" from "zero cases," which is the difference between a fake dip and a real one in a curve.
- `pct_change` reporting the spike *and* its rebound (week 5 up, week 6 down) is honest and matched
  how I'd reason about a double-entry vs a real cluster.

Where I had to translate (engineering leaking through):
- "`data_type`" means two different things (schema key vs layer token) — pure package-internals
  vocabulary I had to reverse-engineer (see majors above).
- A `geocoded_review` row gives me a status but withholds the admin unit it disagreed with — I have to
  translate coordinates back into "which county" myself.
- "1 flag for review" is engineer-terse; an epi wants the value to fix.

---

## What worked / delighted

- **Offline string match** fixed `boston`→`Boston` and the typo `Cambrige`→`Cambridge`, and rewrote
  the *whole* hierarchy to canonical spelling. Zero network, instant, correct.
- **The geocode trust guard.** `geocoded_review` firing on the MIT parent mismatch — and *not*
  silently overwriting my county — is the single best design choice I saw. It earns trust.
- **Clear, named errors.** `` `value_col` "cases" not found in data `` told me exactly what I did
  wrong. Optional `year_col` degraded gracefully instead of erroring. This is what keeps me in the
  package instead of bailing.
- **Guides are runnable as written.** Every command in the reconcile and DQ guides produced the
  documented output verbatim, on synthetic data, offline (plus one live geocode). That is rare and
  builds confidence fast.
- **`result$flags`** carries proper row-level detail once you know it's there.

---

## Top 5 changes that would most improve my day (ranked)

1. **Unify the "data_type"/disease vocabulary** (or document the crosswalk loudly) so I can get from a
   QC'd extract to the approved data without guessing magic strings. *(majors #2, #3)*
2. **Return the geocoder's admin unit on `geocoded_review` rows** so I can resolve a review without
   hand-rolling `st_join`. *(major #1)*
3. **Fix the README "No schema" / disease-name mismatch** and make the error enumerate valid
   `country/disease` keys. *(major #3)*
4. **Sync the README research-lifecycle reference** with the real `eri_research_*` functions. *(minor)*
5. **Surface the offending value in `dq_report()`** (or point to `result$flags`). *(polish)*

---

## Issue-ready list

- **`eri_spatial_reconcile()`: return geocoded admin unit for review rows** — Add `geocoded_*` admin
  columns so users can resolve `geocoded_review` without a manual point-in-polygon.
- **Unify or document the `data_type` vocabulary** — Schema key (`malaria_case`) vs layer/catalog
  token (`surveillance`) diverge with no crosswalk; document the mapping in catalog/sourcing help and
  improve the `eri_data_path()` error.
- **`load_dq_schema()` disease vocabulary mismatch** — README lists DR program `malaria` but loader
  needs `malaria_case`; align docs and make the "No schema found" error list valid keys.
- **README research-lifecycle reference is stale** — Add `eri_research_scaffold/_tag/_status`; clarify
  `init` vs `scaffold` as the entry point.
- **DQ guide: name the `disease` arg in `load_dq_schema()` examples** — Use `disease = "malaria_case"`
  and a sentence distinguishing schema `disease` from layer `data_type`.
- **`dq_report()`: surface offending values/rows** — Print example bad values or a pointer to
  `result$flags` so a fresh user knows where the actionable detail lives.

---

### Prior-learnings check

Read `docs/feedback/red-team-learnings.md` — it is the empty template (no prior runs). Nothing to
re-confirm or dedup; this run is among the first. All findings above are new.
