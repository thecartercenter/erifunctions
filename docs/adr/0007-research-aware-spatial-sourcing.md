# ADR-0007 — Research-aware spatial sourcing via a `cache` flag

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

Spatial layers (admin boundaries, LandScan) live in the Azure `spatial/` blob and are read by
`eri_spatial_load()` / `eri_spatial_pop()`, which return objects **directly from Azure** with no
local cache and no provenance record. But research reproducibility (ADR-0005, ADR-0006) requires
that a study's inputs be cached into the project and recorded in `research.yaml`, so a tagged
analysis (`eri_research_tag()`, ADR — Phase 1) freezes the exact spatial inputs it used.

`eri_research_pull()` already caches arbitrary Azure paths and records provenance at the single
pull entry point (ADR-0005) — but it isn't wired to the spatial path convention
(`spatial/{country}/adm{level}.rds`), and analysts (non-developers) shouldn't have to know it.
The maintainer's requirement: "source spatial from Azure via the package, but keep a cached copy
in the research folder for reproducibility."

## Decision

Add a `cache` flag to `eri_spatial_load(country, level, cache = TRUE, dest = NULL)`. When set, it
sources the boundary by **delegating to `eri_research_pull()`** (which downloads into the project
`data/` and records the pull in `research.yaml` when present), then reads and returns the local
copy. Provenance therefore still flows through the one pull entry point (ADR-0005); the flag is a
convenience over that machinery, not a parallel download path. `cache = FALSE` (the default)
keeps the direct-from-Azure read.

We chose this over a separate `eri_research_pull_spatial()` so there is **one obvious entry
point** for loading a boundary, with reproducibility a single argument away.

## Consequences

- **Easier:** one call sources a boundary reproducibly; the study's spatial inputs are cached and
  appear in `research.yaml`, so `eri_research_tag()` freezes them. Non-developer users get an
  obvious, low-ceremony path to reproducible spatial sourcing.
- **Harder:** `eri_spatial_load()` now optionally depends on the research module; and a cached
  file keeps its basename (`adm{level}.rds`), so a single project mixing two countries' same-level
  boundaries would collide on disk. Acceptable for the one-country pilots (`dr_irs`); revisit with
  country-qualified local names if multi-country projects appear.
- **Not doing:** scattering implicit downloads through every spatial helper, or auto-fetching
  inside analytic functions (ADR-0005 rejects that). LandScan (`eri_spatial_pop()`) can grow the
  same flag later if the need arises.
