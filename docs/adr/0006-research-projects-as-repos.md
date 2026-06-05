# ADR-0006 — Research projects as separate template-generated repos

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

Epidemiologists develop analysis code per study (e.g. the DR IRS interrupted-time-series
analysis, today living as `dr_irs.R` in a gitignored `sandbox/one_off_analyses` folder).
There needs to be a consistent way to organise this code so analyses are reproducible,
reviewable, and not entangled with the package itself. The open question was whether analysis
code should live *inside* `erifunctions` or *outside* it.

## Decision

**Each research project is its own version-controlled repository that depends on
`erifunctions`** — analysis code does not go into the package. Ship a project-repo template,
pulled via `eri_template_pull()`, that scaffolds:

- a `renv` lockfile pinning the `erifunctions` version (reproducibility),
- a `research.yaml` manifest (provenance, lab notebook — see `R/research.R`),
- an `analysis/` directory for the study code,
- a README and a minimal `.github/` CI.

The existing `eri_research_workflow.qmd` template is extended into this full repo skeleton.
Per-study design intent lives in that repo's README/notebook, mirroring at the study level
what `roadmap.md` + ADRs do for the package.

Implemented in **Phase 1**, with `dr_irs` as the reference example.

## Consequences

- **Easier:** the package stays a clean, testable API; studies are independently versioned and
  reproducible; a study can be archived, shared, or published without touching `erifunctions`.
- **Harder:** a new study is a new repo rather than a new file — mitigated by the template
  making setup one command.
- **Not doing:** accumulating one-off analysis scripts inside the package source tree.
