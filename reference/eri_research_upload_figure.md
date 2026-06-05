# Upload a figure to the research project outputs in Azure

Uploads a local figure file to `research/{project_name}/outputs/figs/`
in the `data/` Azure blob and records the upload in `research.yaml`.

## Usage

``` r
eri_research_upload_figure(
  local_path,
  caption = NULL,
  path = getwd(),
  data_con = NULL
)
```

## Arguments

- local_path:

  `chr` Path to the local figure file (e.g. `"figs/its_model.png"`).

- caption:

  `chr` or `NULL` Optional caption describing the figure.

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Azure path the figure was uploaded to (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_upload_figure("figs/its_model.png", caption = "ITS model -- DR malaria 2024")
} # }
```
