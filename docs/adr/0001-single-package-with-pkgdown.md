# ADR-0001 — Stay a single package; solve discoverability with pkgdown

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

`erifunctions` exports ~110 functions in one package. There is a recurring instinct to split
it into interdependent packages (`eriauth`, `eriresearch`, `erianalyst`, …) on the theory
that the sheer number of functions is overwhelming for users.

The package's users are **Data Analysts and Epidemiologists, not software developers**. They
install via `install_github()` and pin with `renv`. Internal helpers such as `azure_io()`
and `.eri_log_session()` are used throughout (I/O, pipeline, research, reporting all depend
on them).

## Decision

**Keep `erifunctions` as a single package.** Address the discoverability problem with
documentation, not package boundaries:

- A **pkgdown site** with a **grouped function reference** (Connections / Data I/O / Pipeline
  / Data quality / Catalog / ODK / Spatial / Epi analytics / Reporting / Research / Onboarding).
- roxygen `@family` tags so related functions cross-link.
- The two **role-based onboarding templates** (`eri_daily_workflow` for DAs,
  `eri_research_workflow` for Epis), bundled in `inst/templates/` and pulled via
  `eri_template_pull()`, plus the task-oriented **workflow vignettes** (`vignettes/*.Rmd`,
  surfaced as pkgdown articles) as the front door.

## Consequences

- **Easier:** one install, one version to pin, one release to cut, one CI matrix. Internal
  helpers stay internal. Users get a curated, role-oriented entry point instead of a flat
  function list.
- **Harder / not doing:** no independent versioning of sub-domains; a consumer who wanted
  *only* the auth layer still installs the whole package.
- **Revisit when:** a separate repository genuinely needs the auth layer standalone — at that
  point extract `eriauth` and depend on it. Until then this is YAGNI.
