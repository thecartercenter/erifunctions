# Report the data state of a research project

Summarises every input the project depends on – pulls (with update
counts and whether a prior version was archived) and artifacts – plus
the output/snapshot/tag counts and any boundary promotions the project
has made to the canonical `/spatial` store, from `research.yaml`. One
place to answer "what does this study depend on, and is any of it
stale?". With `check_remote = TRUE`, flags inputs whose Azure source is
newer than the local copy.

## Usage

``` r
eri_research_status(path = getwd(), check_remote = FALSE, data_con = NULL)
```

## Arguments

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- check_remote:

  `lgl` If `TRUE`, compare each pulled input against its Azure source
  and flag newer upstream versions (best-effort; needs a connection).
  Default `FALSE`.

- data_con:

  Azure container for the `data/` blob; used only when `check_remote`.
  If `NULL`, connects automatically.

## Value

A tibble of tracked inputs (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_status()
eri_research_status(check_remote = TRUE)
} # }
```
