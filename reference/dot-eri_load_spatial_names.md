# Download shapefile components from Azure and return canonical name vector

Downloads the `.shp`, `.dbf`, `.shx`, and (optionally) `.prj` components
to a temp directory, reads with
[`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html),
and returns the unique values of `name_field`. Returns `NULL` on any
failure.

## Usage

``` r
.eri_load_spatial_names(spatial_path, name_field, azcontainer)
```
