# ADR-0012 — Data is addressed by source *and* measure (the 5-axis model)

- **Status:** Accepted — supersedes [ADR-0011](0011-unified-schema-naming.md)
- **Date:** 2026-06-27

## Context

ADR-0011 set out to untangle DQ-schema *naming*. Working through it with the maintainer — and checking
the claim against real data **structure** (never values) — revealed the naming mess is a symptom of a
deeper modelling error: **the path's third axis is overloaded.**

Today a canonical path is `data/{country}/{disease}/{data_type}/{layer}/` with
`data_type ∈ {surveillance, cmr, odk}` (`eri_data_path()` `R/dal.R:838`). But those values describe
**how the data arrives — its source/channel** — which is *orthogonal* to **what the data measures**.
Two pieces of evidence settle it:

- **One source fans out to many measures across diseases.** A single CMR
  (`inst/schemas/cmr/uga.yaml`) has seven sheets that map to ~four measures — `treatment` (RB and SCH),
  `mmdp` (LF), `training` (CDD/CS/MMDP), and `survey` — spanning oncho, SCH and LF.
- **The same source + disease yields a different measure per country.** DR malaria *surveillance* is a
  **case-level line-list** (one row per patient); Haiti malaria *surveillance* is **aggregate** facility
  counts. So the measure is **not** derivable from `(source, disease)`.

Maintainer-clarified domain reality:

- **`surveillance`** — DR/Haiti, a direct Ministry-of-Health feed of a disease's own output:
  `case` or `aggregate`.
- **`programmatic`** — activity/coverage data: `treatment`, `mmdp`, `training`, `survey`; **spans
  diseases** (split per disease on ingest). A country-team **CMR** is one *input format* of this source;
  Haiti's MoH LF-MDA feed lands here too **without** being a CMR. The input format is recorded, not the
  axis.
- **`research`** — research surveys/studies (household or community level), collected via ODK or other
  tools — so **ODK is a `format`, not the lane**. Launched and live-monitored off raw, then the DA
  cleans them into a **final analytic dataset in the central store** (processed) that the Epi sources for
  studies. Research **is** in the governed pipeline; its `data_type` measure is **optional/flexible** (a
  DA tags `tas` / `prevalence` / `household_survey` / … or omits it), since these don't emit a fixed
  measure the way surveillance and programmatic do.

> **Refinement (same day, during Phase-2 implementation):** the third lane was first written as `odk`.
> Working the real schemas with the maintainer showed it is better modelled as **`research`** (the
> nature) with **`odk` a collection `format`** (the tool) — exactly parallel to `programmatic` + `cmr` —
> and with an optional/flexible measure. The decision below reads in those terms.

The overloaded axis is also why the bundled schemas are tangled (four naming conventions), why
`eri_ingest()` is hard-coupled to a legacy pipeline registry and a `projects`-blob dual-write (so it
can't run on sandbox data), and why a multi-disease CMR is crammed under a combined `rblf` code.

## Decision

Address governed data by **five orthogonal axes**, separating **source** from **measure**:

```
data/{country}/{disease}/{data_source}/{data_type}/{layer}/
        dr    /  malaria /  surveillance /   case    / processed
        ht    /   lf     /  programmatic /  treatment/ staged
        dr    /   lf     /    research   /    tas    / raw
```

| Axis | Meaning | Examples |
|---|---|---|
| `country` | country code | dr, ht, eth, uga |
| `disease` | the disease | malaria, oncho, lf, sch, sth |
| `data_source` | **channel / nature** | surveillance, programmatic, research |
| `data_type` | **the measure** | case, aggregate, treatment, mmdp, training, survey, tas, prevalence, entomology |
| `layer` | pipeline stage | raw, staged, processed |

1. **`data_source` is the channel**, with a `format` field recording the input shape
   (`cmr`, a direct MoH feed, …). `programmatic` covers both a country-team CMR and a non-CMR MoH MDA
   feed. `format` is **recorded metadata validated against the same registry** as the axes (not
   free-text), so it cannot become a fourth drift axis; its exact contract is settled at implementation.
2. **`data_type` is the measure**, first-class and in the path. One `(country, disease, data_source)`
   may hold several measures. For **`research`** the measure is **optional and flexible** — the path
   may be `…/research/{layer}/` (no measure) or `…/research/{tag}/{layer}/`; the registry warns rather
   than errors on a new tag so DAs are never blocked managing heterogeneous surveys.
3. **Schema identity = `(country, disease, data_source, data_type)`**; the YAML carries
   `country`/`disease`/`data_source`/`data_type`/`format`.
4. **All sources flow `raw → staged → processed`.** A CMR ingest **splits** each sheet to its
   `disease`+`measure` (`RB Treatment` → `uga/oncho/programmatic/treatment`). A `research` form's full
   relational set (parent + repeat tables, [ADR-0010](0010-odk-repeat-group-tables.md)) lives under a
   single `…/{disease}/research/{data_type?}/` namespace (`format: odk`), with the **measure assigned at
   the form (parent) level** (or omitted); `raw`/`staged` preserve ADR-0010's lossless table set and
   joins stay **downstream, never on
   ingest**, so the DA's cleaned `processed` analytic dataset is exactly that deliberate downstream
   join. The combined `rblf` code and `.eri_schema_country_map` are retired.
5. **`data_source` and `data_type` are extensible by data, not code.** Validation is driven by a small
   registry / the schema set, so onboarding a new source or measure is a **data** change — not a core
   edit (roadmap Phase 5; CLAUDE.md global-vs-local guardrail). "This country/disease/source/measure
   doesn't exist yet" is a normal, expected gap.
6. **General primitives; legacy/production specifics are thin adapters.** Every core operation works
   over the five axes on *any* data, including a sandbox. `eri_ingest()` becomes the single general
   ingest core; the `projects`-blob **dual-write** becomes an opt-in `mirror_pipeline = NULL` parameter
   (default off, sandbox-safe); the `.eri_pipeline_registry`, `.eri_schema_country_map`, and
   registered-country gates are **transitional adapters** removed at the Phase-3 hsp-mal cutover.
   Source-specific entry points (CMR sheet-splitting, ODK) are thin adapters that prep input and call
   the one core — none re-bakes a special case.

## Consequences

- **Easier:** one coherent addressing model where a measure is first-class; new sources/measures arrive
  as data; the *real* `eri_ingest()` runs on sandbox data, so the guides can finally teach it; a
  multi-disease CMR resolves to clean per-disease/measure outputs; ODK's analytic dataset is an ordinary
  processed artifact the Epi can source.
- **Harder / accepted:** this is a **breaking** change to the core path model — `eri_data_path()` gains
  the `data_type` axis and renames the third slot to `data_source`, and every path-builder
  (`eri_approve`, `eri_stage`, `eri_stage_cmr`, `eri_catalog_*`, `eri_odk_sync`, logs) threads the new
  axis. Concretely: the **catalog entry schema** (`R/catalog.R`) splits its single `data_type` field
  into `data_source` + `data_type`, `eri_catalog_query()`'s filter arguments change, and the op-log
  path `{country}/{disease}/{data_type}/logs/` gains a segment. Per ADR-0002 the catalog is rebuildable,
  so `eri_catalog_rebuild()` (and the migration) must read **both** the old 4-axis and new 5-axis
  layouts during the cutover. The bundled schemas are restructured. We accept a large, **phased**
  migration with deprecation shims because it is far cheaper now (little real `processed/` data, only
  `dal.R`/`dq.R` call `load_dq_schema()` internally) than later.
- **Not doing:** collapsing `data_source` and `data_type` back into one token; hard-coded source/measure
  enums; keeping the `rblf` combined code or the `projects` dual-write inside the core.

## Supersedes ADR-0011

ADR-0011 correctly diagnosed the *naming* drift but modelled `data_type` as a single axis. Its **Phase 1
docs** (the README "How data is addressed" section and the `eri_data_path()` error from PR #188) are
partially right but must be updated to the source/measure split as part of the migration. ADR-0011's
status is set to *Superseded by ADR-0012*.

## References

- #175 — the originating issue (now the migration tracker).
- PR #188 — ADR-0011 Phase 1 (vocabulary docs to be updated).
- `inst/schemas/cmr/uga.yaml` — the multi-measure CMR evidence.
- `docs/roadmap.md` — Phase 3 (hsp-mal cutover, which retires the legacy adapters) and Phase 5
  (onboarding without core edits, which the extensible registry serves).
- [ADR-0010](0010-odk-repeat-group-tables.md) — the ODK relational-table set this model files under one
  `odk/{measure}/` namespace (lossless set preserved; joins downstream).
- CLAUDE.md "Core model" + "Guardrail: global vs local"; ADR-0002 (YAML metadata, rebuildable catalog),
  ADR-0006 (research projects / the ODK study lifecycle).
