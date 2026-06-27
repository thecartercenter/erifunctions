# ADR-0011 — One vocabulary for addressing data and schemas

- **Status:** Accepted (phased — interim docs shipped; rename to follow)
- **Date:** 2026-06-27

## Context

A fresh-user red-team run (the Epidemiologist persona) got stuck going from "I quality-checked a
`malaria_case` extract" to "now pull the approved version for analysis." The root cause is **vocabulary
drift across three independent axes that share words**:

- `eri_data_path(country, disease, data_type, layer)` builds `{country}/{disease}/{data_type}/{layer}`,
  where `data_type ∈ {surveillance, cmr, odk}` is the *storage-layer category* and `disease` is the
  *program* (`malaria`). (`R/dal.R:838`)
- `load_dq_schema(country, disease)` takes a **schema key** in its `disease` slot — e.g.
  `"malaria_case"` — which is finer-grained than the program and is **not** a `data_type`.
  (`R/dq.R`)

So `eri_data_path("dr", "malaria", "malaria_case", …)` errors (`malaria_case` is not a `data_type`),
and there is no documented or machine-readable link saying "the `malaria_case` schema validates
`dr/malaria/surveillance/…`."

The bundled schema files make this worse by mixing **four** naming conventions at once
(`inst/schemas/`):

- country **code** prefixes — `dr_malaria_case.yaml`, `ht_lf_tas.yaml`, `ug_rb_mda.yaml`;
- **full country name** prefixes — `dominican_republic_malaria.yaml`, `haiti_malaria.yaml`
  (so `load_dq_schema("dr", "malaria")` fails but `load_dq_schema("haiti", "malaria")` works);
- **disease in the country slot** — `schisto_mda.yaml`, `sth_prevalence.yaml` (no country at all);
- survey-type **suffixes** — `_case`, `_mda`, `_tas`, `_prevalence` — that are a fourth concept
  again (the validation variant), distinct from both `disease` and `data_type`.

Only `R/dal.R` and `R/dq.R` call `load_dq_schema()` internally, and the system holds very little real
`processed/` data yet, so the cost of fixing this is near its lifetime minimum **now**.

## Decision

Adopt **one consistent vocabulary** for addressing both data and schemas, in two phases.

**Phase 1 — clarity, no behavior change (shipped with this ADR).**
- Document the four path axes and the separate schema-key concept (README "How data is addressed").
- `eri_data_path()`'s error now states that `data_type` is the storage-layer category, not a schema
  key, and that the program belongs in `disease`.
- `load_dq_schema()` already lists every available schema key when one is not found (ADR-precursor
  work, #176).

**Phase 2 — the unified convention (planned; tracked by #175).**
1. **Country is always the ERI country code** (`dr`, `ht`, `uga`, …) — retire full-name files and the
   disease-in-country-slot files; dedup the resulting collisions (e.g. `dominican_republic_malaria` and
   `dr_malaria_case` reconcile to one canonical schema).
2. **Schema keys follow one pattern** — `{disease}[_{variant}]` (variant ∈ `case`/`mda`/`tas`/
   `prevalence`/…) — so a key is always "program, optionally narrowed to a survey type."
3. **Each schema declares what it validates** via a machine-readable `data_type:` (and `disease:`)
   field in its YAML, so the schema↔`data_type` link is real, not folklore. A small accessor exposes
   it, letting tooling bridge a schema to its `eri_data_path()` location automatically.
4. **Deprecation, not breakage:** old filenames keep working for one release via thin shims that load
   the renamed file and emit a one-time deprecation warning; the guides and any internal callers move
   to the new keys in the same cycle.

The detailed key list and the exact `load_dq_schema()` signature (keep two-arg vs. add an explicit
`variant`/`data_type` arg) are settled at implementation time, against this ADR.

## Consequences

- **Easier:** one mental model — `country / disease / data_type / layer` for paths, and a predictable
  schema **filename** `{country_code}_{disease}[_{variant}].yaml` (the country code comes from the
  separate `country` argument; the key slot is `{disease}[_{variant}]`) whose contents *declare* their
  `data_type`. A fresh analyst can go from a QC'd extract to its approved location without insider
  knowledge, which is the exact gap that motivated this ADR.
- **Harder / accepted:** Phase 2 is a breaking rename of bundled assets. We accept a one-release
  deprecation window and the churn of updating guides + the two internal callers. Doing it now (little
  real data, two callers) is deliberately cheaper than doing it later.
- **Not doing:** collapsing `data_type` and the schema variant into a single field — they are genuinely
  different (`surveillance` is *how data arrives*; `case` is *which validation applies*). The unified
  convention keeps them distinct but consistently named, and links them with the new `data_type:`
  field rather than overloading one token.

## References

- #175 — the umbrella issue (Phase 2 migration tracker).
- #176 — `load_dq_schema()` now enumerates valid keys (Phase 1 discoverability precursor).
- CLAUDE.md "Core model" and "Guardrail: global vs local" — this is the canonical "solve the general
  problem and record the decision" case.
- `docs/roadmap.md` — Phase 5 DA-breadth / onboarding work consumes this vocabulary.
