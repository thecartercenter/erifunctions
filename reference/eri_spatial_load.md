# Load admin boundary from Azure

Reads an admin boundary `sf` object from
`data/spatial/{country}/adm{level}.rds` in the `data/` Azure blob.
Returns it ready for mapping or spatial joins.

## Usage

``` r
eri_spatial_load(country, level, data_con = NULL, cache = FALSE, dest = NULL)
```

## Arguments

- country:

  `chr` Country code (e.g. `"dr"`, `"ht"`).

- level:

  `int` Admin level (0 = country, 1 = region/department, 2 =
  province/commune, 3 = municipality/locality, 4 = sub-locality).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- cache:

  `lgl` If `TRUE`, cache the boundary into the local research project
  and read it from there instead of reading directly from Azure. Caching
  delegates to
  [`eri_research_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_pull.md),
  which downloads into `dest` and records the pull in `research.yaml`
  when present – so a study's spatial inputs are reproducible and frozen
  by
  [`eri_research_tag()`](https://thecartercenter.github.io/erifunctions/reference/eri_research_tag.md).
  Default `FALSE` (read directly from Azure). See ADR-0007.

- dest:

  `chr` Directory to cache into when `cache = TRUE`. Defaults to the
  project `data/` directory.

## Value

An `sf` object with the admin boundary geometries.

## Examples

``` r
if (FALSE) { # \dontrun{
haiti_communes <- eri_spatial_load("ht", level = 2)
dr_provinces   <- eri_spatial_load("dr", level = 2)

# Inside a research project: cache the boundary and record its provenance.
dr_loc <- eri_spatial_load("dr", level = 4, cache = TRUE)
} # }
```
