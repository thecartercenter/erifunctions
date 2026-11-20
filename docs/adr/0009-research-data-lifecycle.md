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

## Addendum (issue #377, 2026-11-20): outputs are archived on re-upload, and tags freeze them

**Context.** The archive-before-overwrite rule above covered inputs (`eri_research_pull()`) and canonical
spatial data, but not outputs. `eri_research_upload_figure()` wrote to `outputs/figs/<basename>` and both
upload functions overwrote any existing blob, while `eri_research_tag()` recorded only the output paths.
In `dr_irs_2026` that meant figures with the same name in different folders replaced each other, and
uploading the v3 decks replaced the files the `dr-irs-its-v2` tag pointed at: the tag still reproduced the
data and code, but its outputs were gone.

**Decision.**
- **Paths.** A figure's Azure path keeps its folder relative to the project root, minus a leading `figs/` (or `outputs/figs/`)
  (`figs/deck/es/forest.png` -> `outputs/figs/deck/es/forest.png`; a flat `figs/x.png` is unchanged). A
  file outside the project falls back to its name, with a warning.
- **Archive on re-upload.** Both upload functions go through one helper that, if a blob already exists at
  the destination, copies it to `outputs/_archive/<timestamp>/<same relative path>` before uploading. In
  `research.yaml`, every earlier current entry for that path gets `superseded_at`; the most recent gets
  `archived_to`; the new entry gets `archived_prev`. Entries overwritten before this change have no
  archive and are marked superseded only.
- **Tags freeze outputs.** `eri_research_tag()` copies each current output (the latest non-superseded
  entry per path) to `tags/<label>/outputs/<path relative to outputs/>` before writing `_tag.yaml`, and
  records `frozen_path` on each output in the tag. An output that can't be copied is recorded without a
  `frozen_path`, with a warning, rather than blocking the tag. So a tag now freezes data (snapshot), code (SHA) **and**
  outputs.

Copies are download-then-upload through the existing blob helpers (`.eri_blob_read()` /
`.eri_blob_write()`), not a server-side copy; research outputs are small figures, decks and model
objects, so the extra transfer is minor.

**Upgrading.** Before this change every figure went to `outputs/figs/<name>`. A figure in a subfolder now
goes to a new path, so its old flat entry is not superseded by a re-upload; it isn't superseded
automatically either, since that flat entry may be a different figure with the same name. The upload
prints a note instead. Two re-uploads in the same second get separate archive folders
(`<timestamp>`, `<timestamp>-2`, ...).

**Consequences.** Re-uploading an output is reversible, and a tag's outputs survive later uploads. Storage
grows by one copy per re-upload and per tagged output. Nothing already lost can be recovered by this
change.
