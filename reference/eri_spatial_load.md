# Load admin boundary from Azure

Reads an admin boundary `sf` object from
`data/spatial/{country}/adm{level}.rds` in the `data/` Azure blob.
Returns it ready for mapping or spatial joins.

## Usage

``` r
eri_spatial_load(country, level, data_con = NULL)
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

## Value

An `sf` object with the admin boundary geometries.

## Examples

``` r
if (FALSE) { # \dontrun{
haiti_communes <- eri_spatial_load("ht", level = 2)
dr_provinces   <- eri_spatial_load("dr", level = 2)
} # }
```
