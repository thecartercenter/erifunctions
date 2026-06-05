# Resume a research project session

Reads `research.yaml` from the project root, re-establishes the Azure
connection, and prints a session summary (last pull, last log entry,
snapshot count). Call this at the top of each work session instead of
re-typing project context.

## Usage

``` r
eri_research_resume(path = getwd(), data_con = NULL)
```

## Arguments

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The manifest list (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_resume()
} # }
```
