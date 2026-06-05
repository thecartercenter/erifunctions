# Snapshot the full research project data directory to Azure

Uploads every file in the local `data/` directory to
`research/{project_name}/snapshots/{timestamp}/` in the `data/` Azure
blob, writes a `_manifest.yaml` alongside listing what was included, and
records the snapshot in `research.yaml`.

## Usage

``` r
eri_research_snapshot(label = NULL, path = getwd(), data_con = NULL)
```

## Arguments

- label:

  `chr` or `NULL` Optional short label for this snapshot (e.g.
  `"pre-ITS-run"`).

- path:

  `chr` Local project root (must contain `research.yaml` and `data/`).
  Defaults to [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Azure snapshot path (invisibly).

## Details

Use this to freeze a reproducible checkpoint of all input data before a
major analysis run or before sharing results.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_snapshot(label = "pre-ITS-run")
} # }
```
