# Initialise a new research project

Creates the local project scaffold (`data/`, `figs/`, `outputs/`
directories plus a `research.yaml` manifest) and the corresponding
`research/{project_name}/` directory in the `data/` Azure blob. Run once
at the start of a new study.

## Usage

``` r
eri_research_init(
  project_name,
  country,
  disease,
  description,
  path = getwd(),
  data_con = NULL,
  dry_run = FALSE
)
```

## Arguments

- project_name:

  `chr` Short identifier for the project (e.g. `"dr_irs_2024"`). Used as
  the Azure directory name and the primary key in the manifest.

- country:

  `chr` Country code (e.g. `"dr"`).

- disease:

  `chr` Disease name (e.g. `"malaria"`).

- description:

  `chr` Human-readable description of the research question.

- path:

  `chr` Local directory in which to scaffold the project. Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- dry_run:

  `lgl` If `TRUE`, print what would be created without writing anything.
  Default `FALSE`.

## Value

Path to the `research.yaml` file (invisibly), or `NULL` for `dry_run`.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_init(
  project_name = "dr_irs_2024",
  country      = "dr",
  disease      = "malaria",
  description  = "ITS analysis of IRS impact on malaria incidence in Dominican Republic"
)
} # }
```
