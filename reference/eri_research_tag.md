# Tag a reproducible, citable version of a research project

Binds a frozen data snapshot, the analysis code commit (the research
project's git SHA), the recorded input provenance, and the output
manifest into a single immutable **tag** at
`research/{project_name}/tags/{label}/_tag.yaml` in the `data/` Azure
blob, and records it in `research.yaml`.

## Usage

``` r
eri_research_tag(
  label,
  description = NULL,
  snapshot = NULL,
  path = getwd(),
  data_con = NULL
)
```

## Arguments

- label:

  `chr` Short, unique tag name (e.g. `"lancet-2026-submission"`).

- description:

  `chr` or `NULL` Optional note describing this version.

- snapshot:

  `chr` or `NULL` Which snapshot to bind: a snapshot label or timestamp
  already in `research.yaml`. If `NULL`, the most recent snapshot is
  used, or a fresh one is created if none exist.

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The Azure path of the tag file (invisibly).

## Details

A tag answers "what produced this published result?" – which data
([`eri_research_snapshot()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_snapshot.md)),
which code (git commit), which inputs
([`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
/
[`eri_artifact_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_pull.md)
provenance), and which outputs. Because data is bound by a snapshot and
code by a commit SHA, a tagged analysis can be reproduced from a
citation – including across data updates, by tagging again after
re-pulling refreshed data.

If no snapshot exists yet, one is created automatically. Tags are
immutable: tagging an already-used label is an error.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_snapshot(label = "final-data")
eri_research_tag("lancet-2026-submission", description = "Figures 1-3, Table 2")
} # }
```
