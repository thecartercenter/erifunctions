# Architecture Decision Records

An **Architecture Decision Record (ADR)** captures a single significant decision: the
context that forced it, the decision taken, and the consequences. The point is durability —
so that six months or one long session later, anyone (teammate or AI assistant) can see
*why* the system is the way it is, instead of re-litigating it or inventing a local
workaround. This is the per-decision counterpart to the higher-level
[`roadmap.md`](../roadmap.md).

## Format

Each record is a numbered file, `NNNN-short-title.md`, with these sections:

```markdown
# ADR-NNNN — Title

- **Status:** Proposed | Accepted | Superseded by ADR-XXXX
- **Date:** YYYY-MM-DD

## Context
What problem or force prompted the decision? Reference concrete code where relevant.

## Decision
The position taken, stated plainly.

## Consequences
What becomes easier, what becomes harder, and what we are explicitly *not* doing.
```

## Conventions

- One decision per file. Keep it short.
- ADRs are append-only: don't rewrite an accepted ADR to change its meaning — add a new ADR
  that supersedes it and update the old one's status.
- Link the ADR from the roadmap when it shapes a phase.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-single-package-with-pkgdown.md) | Stay a single package; discoverability via pkgdown | Accepted |
| [0002](0002-concurrency-safe-metadata.md) | Concurrency-safe, rebuildable metadata stores | Accepted |
| [0003](0003-token-derived-identity.md) | Approver identity from the auth token | Accepted |
| [0004](0004-duckdb-query-layer.md) | Blob as system-of-record + serverless DuckDB query layer | Accepted |
| [0005](0005-pull-then-process.md) | Pull-then-process with provenance | Accepted |
| [0006](0006-research-projects-as-repos.md) | Research projects as separate template-generated repos | Accepted |
| [0007](0007-research-aware-spatial-sourcing.md) | Research-aware spatial sourcing via a `cache` flag | Accepted |
| [0008](0008-baked-azure-auth-defaults.md) | Baked-in Azure auth defaults; interactive AAD as the zero-config default | Accepted |
| [0009](0009-research-data-lifecycle.md) | Research-data lifecycle: Azure is the source, the project is the versioned working copy | Accepted |
| [0010](0010-odk-repeat-group-tables.md) | ODK repeat groups land as a relational set of tables, approved together | Accepted |
| [0011](0011-unified-schema-naming.md) | One vocabulary for addressing data and schemas (unified schema naming) | Superseded by ADR-0012 |
| [0012](0012-source-measure-data-model.md) | Data is addressed by source *and* measure (the 5-axis path model) | Accepted |
