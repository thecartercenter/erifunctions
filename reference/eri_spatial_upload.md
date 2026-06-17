# Upload a new admin boundary shapefile to Azure

Validates and uploads a local shapefile (or any sf-readable format) to
the canonical `data/spatial/{country}/adm{level}.rds` in the `data/`
Azure blob.

## Usage

``` r
eri_spatial_upload(
  local_path,
  country,
  level,
  data_con = NULL,
  overwrite = FALSE
)
```

## Arguments

- local_path:

  `chr` Path to the local shapefile (`.shp`, `.gpkg`, `.geojson`, etc.).

- country:

  `chr` Country code (e.g. `"dr"`, `"ht"`).

- level:

  `int` Admin level (0–4).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

- overwrite:

  `lgl` If `TRUE`, replace an existing canonical boundary. Default
  `FALSE` (refuse to overwrite shared data). Prefer
  [`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md)
  for deliberate replacement.

## Value

The Azure blob path (invisibly).

## Details

The file is validated before upload:

- Must have a defined CRS.

- Must have no empty geometries.

- Must contain a column named `adm{level}_name` holding the canonical
  admin unit names.

If validation fails the upload is blocked with a clear error explaining
what to fix.

The canonical `spatial/` store is **shared cleaned reference data** that
many users pull for figures, so this function is **overwrite-safe**: it
refuses to clobber a boundary that already exists. Use this for a
brand-new boundary. To deliberately *replace* an existing canonical
boundary from a vetted research-project copy, use
[`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md)
(which records who promoted what, when). A deliberate `overwrite = TRUE`
archives the prior canonical version to `spatial/_archive/<timestamp>/`
first, so the replacement is reversible. See ADR-0009.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_spatial_upload("data/dom_admin_boundaries/dom_admin3.shp", country = "dr", level = 3)
eri_spatial_upload("data/hti_admin_boundaries/hti_admin2.shp", country = "ht", level = 2)
} # }
```
