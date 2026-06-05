# Scaffold a new research-project repository

Creates a standalone analysis-project skeleton (ADR-0006) at
`dest/name/`: a README, an `analysis/` directory seeded with the
research-workflow template, a data-safe `.gitignore`, a minimal
reproducibility CI workflow, and the standard research scaffold
(`data/`, `figs/`, `outputs/`, `research.yaml`) via
[`eri_research_init()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_init.md).

## Usage

``` r
eri_research_scaffold(
  name,
  country,
  disease,
  description,
  dest = getwd(),
  data_con = NULL
)
```

## Arguments

- name:

  `chr` Project name; also the new directory name (e.g.
  `"dr_irs_2024"`).

- country:

  `chr` Country code (e.g. `"dr"`).

- disease:

  `chr` Disease name (e.g. `"malaria"`).

- description:

  `chr` One-line description of the research question.

- dest:

  `chr` Parent directory in which to create `name/`. Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Path to the created project directory (invisibly).

## Details

Each research project is its own git repository that depends on
`erifunctions` – analysis code does not live in the package. After
scaffolding, the analyst initialises version control and `renv` (see the
generated README), sources data with provenance
([`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md)
/
[`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)),
and freezes citable versions with
[`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_research_scaffold(
  "dr_irs_2024", country = "dr", disease = "malaria",
  description = "ITS analysis of IRS impact on malaria incidence in the DR",
  dest = "~/studies"
)
} # }
```
