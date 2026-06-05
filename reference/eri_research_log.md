# Add an entry to the research lab notebook

Appends a timestamped free-text note to the `log` section of
`research.yaml`. Use this to record decisions, observations, or status
updates during analysis.

## Usage

``` r
eri_research_log(note, path = getwd())
```

## Arguments

- note:

  `chr` The text to log.

- path:

  `chr` Local project root (must contain `research.yaml`). Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

## Value

`NULL` invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_log("Ran ITS model -- negative binomial converged. Saving output.")
} # }
```
