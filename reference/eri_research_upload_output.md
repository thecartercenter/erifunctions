# Upload an R object to the research project outputs in Azure

Serializes an R object to a `.qs2` file and uploads it to
`research/{project_name}/outputs/` in the `data/` Azure blob. Records
the upload in `research.yaml`.

## Usage

``` r
eri_research_upload_output(obj, filename, path = getwd(), data_con = NULL)
```

## Arguments

- obj:

  R object to serialize and upload.

- filename:

  `chr` Name for the output file (include `.qs2` extension, e.g.
  `"its_model.qs2"`).

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Azure path the object was uploaded to (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_upload_output(model_fit, "its_model.qs2")
} # }
```
