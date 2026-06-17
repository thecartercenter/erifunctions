# Pull data from Azure into a research project

Downloads files from Azure into a local destination and records every
pull in `research.yaml` for provenance. Two modes:

## Usage

``` r
eri_research_pull(
  country = NULL,
  disease = NULL,
  data_type = NULL,
  path = NULL,
  dest = NULL,
  data_con = NULL,
  progress = FALSE
)
```

## Arguments

- country:

  `chr` or `NULL` Country code (e.g. `"dr"`). Used with `disease` and
  `data_type`.

- disease:

  `chr` or `NULL` Disease name (e.g. `"malaria"`). Used with `country`
  and `data_type`.

- data_type:

  `chr` or `NULL` Data type (`"surveillance"`, `"cmr"`, `"odk"`). Used
  with `country` and `disease`.

- path:

  `chr` or `NULL` Explicit Azure blob path to download from. Mutually
  exclusive with canonical args.

- dest:

  `chr` or `NULL` Local directory to download files into. Defaults to
  `data/` inside [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- progress:

  `lgl` If `TRUE`, show a per-file byte progress bar (use for a few
  large files, e.g. a LandScan raster). Default `FALSE` uses one compact
  progress bar across all files.

## Value

Character vector of local file paths downloaded (invisibly).

## Details

- **Canonical**: supply `country`, `disease`, and `data_type` to pull
  from the standard processed layer
  (`{country}/{disease}/{data_type}/processed/`).

- **Path**: supply `path` to pull any Azure location (e.g.
  `"data/spatial/dom_admin_boundaries/"`).

For non-standard external files not yet in Azure, upload them first with
[`eri_artifact_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_upload.md),
then pull with
[`eri_artifact_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_artifact_pull.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Pull canonical processed surveillance data
eri_research_pull(country = "dr", disease = "malaria", data_type = "surveillance")

# Pull standard spatial reference files
eri_research_pull(path = "spatial/dom_admin_boundaries")
} # }
```
