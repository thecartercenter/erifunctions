# ADR-0009 — Research-data lifecycle: Azure is the source, the project is the versioned working copy

- **Status:** Accepted
- **Date:** 2026-06-16

## Context

Driving the `dr_irs` study end-to-end (the package's first real Epi research workflow) exposed gaps
in how a research project tracks its inputs:

- Re-pulling a dataset **appended a duplicate** `pulled_data` record instead of updating it, with no
  way to see a project's data state at a glance.
- There was **no update-with-archival**: overwriting an input lost the prior version, so an analysis
  could not be rolled back or compared across a data refresh.
- `eri_spatial_pop()` **re-downloaded** the ~100 MB LandScan raster on every call (twice for adm3 +
  adm4) and recorded no provenance for the year used.
- Canonical reference data in `/spatial` could be **overwritten** by a casual `eri_spatial_upload()`,
  with no deliberate "promote" gate (per the maintainer, `/spatial` is shared cleaned data many users
  pull for figures and must not be clobbered).

## Decision

Treat **Azure stores as the upstream source and the research project as the tracked, versioned
working copy** — the approval-gate philosophy applied to research inputs.

- **Update + archival, at the pull entry point.** `eri_research_pull()` (ADR-0005) archives any prior
  local version into `data/_archive/<timestamp>/` before overwriting, and **dedups** the
  `pulled_data` record (replace-in-place, carrying `first_pulled_at` + `update_count`). Because
  `eri_spatial_load(cache=TRUE)` and `eri_spatial_pop()` route through `eri_research_pull()`, spatial
  inputs inherit this.
- **No needless re-fetch.** Downloads reuse a project-cached copy when present (`eri_spatial_pop()`
  caches and reuses the LandScan raster; provenance recorded).
- **A project-state manifest.** `eri_research_status()` lists every tracked input (source, pulled_at,
  update count, whether a prior version was archived) and optionally flags inputs whose Azure source
  is newer (`check_remote = TRUE`). It also reports any boundary **promotions** the project has made
  to canonical (these are outbound, so they are summarised separately from the inbound input table).
- **Canonical writes are gated and archived.** `/spatial` is protected: a project boundary reaches
  canonical only via an explicit `eri_spatial_promote()`, and `eri_spatial_upload()` becomes
  overwrite-safe. A deliberate overwrite of an existing canonical boundary (via either entry point
  with `overwrite = TRUE`) **archives the prior canonical version to `spatial/_archive/<timestamp>/`
  first**, so even the highest-stakes write — replacing shared reference data many users pull — is
  reversible. The promotion (including the archive location) is recorded in `research.yaml`. "Bring
  your own / a subset" data stays in the project and is never pushed to canonical implicitly.

## Consequences

- **Easier:** updating a dataset is safe and visible — re-pull archives the old version, `status`
  shows what changed, and `eri_research_tag()` can still freeze the superseded inputs, so a refreshed
  analysis is reproducible and the prior tag still reproduces. Repeated runs stop re-downloading.
- **Harder / accepted:** cached rasters and `_archive/` live under `data/`, so `eri_research_snapshot()`
  captures them; a large cached raster inflates snapshots. Acceptable for reproducibility; revisit
  with a snapshot exclude-list (`_archive/`, large caches) if size becomes a problem.
- **Not doing:** a separate database or VCS for data (ADR-0002 keeps metadata in YAML); auto-promoting
  project data to canonical (promotion is always explicit).
