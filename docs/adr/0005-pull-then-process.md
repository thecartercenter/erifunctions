# ADR-0005 — Pull-then-process with provenance

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

When an analyst works with data, the helpers could either (a) require the analyst to pull the
data down once and then operate on the local copy, or (b) have each helper pull and process
the data itself. Option (b) means every function re-downloads, often the same file many times
in a session.

The research workflow already follows (a): `eri_research_pull()` downloads canonical processed
data (or any Azure path) into the local project and records the pull in `research.yaml`.

## Decision

**Standardise on pull-then-process.** The analyst pulls data into a local project once;
helpers operate on local objects/paths. Make the **pull entry points the single place
provenance is recorded**:

- `eri_research_pull()` — canonical processed data and arbitrary Azure paths.
- `eri_artifact_pull()` — non-standard reference files registered via `eri_artifact_upload()`.

Both already append to `research.yaml`; keep that the contract and do not scatter implicit
downloads through analytic helpers.

## Consequences

- **Easier:** no repeated downloads; a single, inspectable record of exactly what entered an
  analysis and when; reproducible because the manifest pins the inputs.
- **Harder:** the analyst must remember to pull before processing — mitigated by the workflow
  templates and `eri_research_resume()` prompting at session start.
- **Not doing:** auto-fetching inside analytic functions, which would obscure provenance and
  thrash the network.
