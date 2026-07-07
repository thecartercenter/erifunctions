# ADR-0016 — Conditional metadata writes go through the blob endpoint

- **Status:** Accepted
- **Date:** 2026-07-07

## Context

The concurrency-safe metadata stores (ADR-0002) — the data catalog, the ODK registry, the artifact
registry, and the feedback log — are single YAML blobs updated by an optimistic-concurrency
read-modify-write. `.eri_yaml_update()` reads the blob with its ETag, applies the caller's mutate, and
writes back **conditionally**: `If-None-Match: *` to create, `If-Match: <etag>` to update, re-reading and
retrying on the `HTTP 412` a losing race produces.

That conditional write was implemented as a single blob-API `PUT` — `x-ms-blob-type: BlockBlob` plus the
`If-*` header and the whole body — issued through `AzureStor::do_container_op()` against the container the
rest of the package uses. That container is an **ADLS Gen2 filesystem on the `dfs` endpoint**
(`https://eridev.dfs.core.windows.net/`, the baked default — see `R/dal.R`). The `dfs` endpoint does not
serve the blob `Put Blob` API; it rejects that request shape with `HTTP 400 ("An HTTP header that's
mandatory for this request is not specified")` and writes nothing.

The bug was latent because the unit tests mock `do_container_op`, and the file/Parquet write path
(`storage_upload`, which AzureStor maps to the correct DataLake create/append/flush sequence) works fine —
so data landed while the *metadata* write silently failed. It surfaced in the Phase-3 pilot when a live
`eri_odk_sync()` wrote all its Parquet tables to `raw/` and then errored on the final `last_synced`
registry update. Every conditional metadata write was affected on the default endpoint, `eri_feedback()`
included.

An ADLS Gen2 storage account is multi-protocol: the same files are reachable, with the same AAD token, via
the account's **blob** endpoint (`https://eridev.blob.core.windows.net/`), which *does* support `Put Blob`
with conditional `If-Match`/`If-None-Match` and returns `412` on a stale ETag. Verified live against the
`eridev` account: create → `201`, conditional update → `201`, stale-ETag update → `412`.

## Decision

The ADR-0002 conditional **read and write** (`.eri_yaml_read_versioned()` / `.eri_yaml_write_conditional()`
in `R/metadata.R`) route through the same account's **blob** endpoint, derived in-place from the passed
container by `.eri_blob_metadata_con()`: swap the `dfs` host for the `blob` host, reuse the token / key /
SAS and the filesystem name. A container that is already blob-backed — or any test double that is not a real
`adls_filesystem` — is returned unchanged, so callers and the mocked test seam are unaffected.

- **Scope is deliberately narrow.** Only the small, conditional metadata ops move to the blob endpoint.
  Bulk data I/O (`eri_read`/`eri_write`, snapshots, artifacts) keeps using the `dfs`/ADLS container and its
  `storage_upload` path, which works and gives ADLS the hierarchical-namespace semantics the data layout
  relies on. The parent-directory ensure still runs on the ADLS container.
- **Reuse, don't reinvent** (per the CLAUDE.md guardrail): the routing is one helper shared by both metadata
  ops, not a per-store fix.

## Consequences

- **Easier:** every metadata store (catalog, ODK registry, artifact registry, feedback) writes correctly on
  the default ADLS Gen2 endpoint, with the optimistic-concurrency guarantee intact. No configuration change
  for users.
- **Harder:** the metadata path now assumes the account exposes its blob endpoint (true for any ADLS Gen2
  account) and that the `dfs`↔`blob` host substitution holds. Both are standard, but they are now an
  implicit dependency of ADR-0002.
- **Not doing:** implementing conditional writes via the native DataLake create/append/**flush** sequence
  (which also supports `If-Match`). It is a three-call dance for a small blob; the blob endpoint is one call
  and the exact semantics the code already expresses.
