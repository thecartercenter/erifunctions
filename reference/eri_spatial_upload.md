# Upload an admin boundary shapefile to Azure

Validates and uploads a local shapefile (or any sf-readable format) to
`data/spatial/{country}/adm{level}.rds` in the `data/` Azure blob.

## Usage

``` r
eri_spatial_upload(local_path, country, level, data_con = NULL)
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

## Examples

``` r
if (FALSE) { # \dontrun{
eri_spatial_upload("data/dom_admin_boundaries/dom_admin3.shp", country = "dr", level = 3)
eri_spatial_upload("data/hti_admin_boundaries/hti_admin2.shp", country = "ht", level = 2)
} # }
```
