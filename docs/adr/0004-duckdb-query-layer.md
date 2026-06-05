# ADR-0004 — Blob as system-of-record + serverless DuckDB query layer

- **Status:** Accepted
- **Date:** 2026-06-05

## Context

Two related questions: "should the final datasets live in a formal database?" and "what else
could we do with Azure storage?" Final datasets are currently parquet files in the `data/`
blob, indexed by the YAML catalog. Analysts increasingly need cross-dataset queries
(cross-country/disease roll-ups, ad-hoc requests) that are awkward to express as a series of
per-file reads.

## Decision

**Keep the Azure blob as the system of record** — parquet remains the canonical storage
format, which also keeps the data directly consumable by ArcGIS, Power BI, and dashboards.
Do **not** stand up a database server.

Add a **serverless query layer**: `eri_query()` attaches the relevant processed parquet files
into an in-process **DuckDB** session and runs SQL across them, with zero operational
overhead. The catalog (ADR-0002) is the metadata index that tells `eri_query()` which files
to attach for a given country/disease/data_type.

Implemented in **Phase 2**; consumed by ad-hoc helpers in **Phase 5**.

## Consequences

- **Easier:** SQL joins/aggregations across datasets without a server, without moving data
  out of the blob, and without a second copy to keep in sync.
- **Harder:** adds a DuckDB dependency; very large cross-dataset scans are bounded by local
  memory/download.
- **Not doing:** Postgres or any managed relational DB — rejected for operational burden on a
  non-developer team.
