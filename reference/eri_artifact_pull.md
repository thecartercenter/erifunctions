# Download an artifact from the registry to a local destination

Downloads the registered artifact file to `dest`. If a `research.yaml`
is found in the current working directory (placed there by
[`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md)),
the pull is recorded in the manifest's `artifacts_used` list.

## Usage

``` r
eri_artifact_pull(name, dest = getwd(), data_con = NULL)
```

## Arguments

- name:

  `chr` Artifact name as registered (e.g. `"dr_irs_2024"`).

- dest:

  `chr` Local directory to download the file into. Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Local path to the downloaded file (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_artifact_pull("dr_irs_2024", dest = "data/raw")
} # }
```
