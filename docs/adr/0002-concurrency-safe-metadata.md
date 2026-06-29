# ADR-0002 — Concurrency-safe, rebuildable metadata stores

- **Status:** Accepted — **implemented in Phase 2 (2026-06-29, #235)**
- **Date:** 2026-06-05

## Context

Several metadata stores are single YAML blobs updated with a full read-modify-write cycle:

- the data catalog — `eri_catalog_register()` reads `_catalog/data_catalog.yaml`, mutates the
  list, and writes the whole thing back (`R/catalog.R`).
- the ODK form registry (`R/odk_registry.R`).
- the artifact registry (`R/artifacts.R`).

If two analysts act at the same time (e.g. both approve data, which auto-registers a catalog
entry), their writes race: the second overwrites the first and an entry is silently lost.
This is the real concern behind "should we move to a formal database?" — the issue is
**atomicity**, not SQL.

## Decision

1. **Optimistic concurrency on every metadata write.** Read the blob together with its ETag,
   and write back conditionally (`If-Match` / AzureStor conditional upload). On a `412`
   conflict, re-read, re-apply the change, and retry with small backoff.
2. **Make the index rebuildable.** Add `eri_catalog_rebuild()` that reconstructs the catalog
   by scanning the `processed/` directories of the `data/` blob. The catalog becomes a cache
   of derivable truth, not an irreplaceable system of record.

Implemented in **Phase 2** (architecture hardening), before concurrent surveillance approval
becomes load-bearing. The read-with-ETag / conditional-write / retry loop is the internal
`.eri_yaml_update()` (`R/metadata.R`); the catalog, ODK registry and artifact registry writers
all route through it, and `eri_catalog_rebuild()` provides the rebuild path.

## Consequences

- **Easier:** concurrent analysts no longer lose updates; a corrupted or stale catalog can be
  regenerated rather than hand-repaired.
- **Harder:** writes gain a retry loop and must thread the ETag through; a tiny amount of
  added complexity in the metadata helpers.
- **Not doing:** standing up a database server (Postgres). The blob remains the store of
  record (see ADR-0004 for the query layer).
