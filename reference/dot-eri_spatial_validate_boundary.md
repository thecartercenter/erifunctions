# Validate a local admin boundary before it reaches the canonical store.

Reads `local_path` as an `sf` object and checks it has a defined CRS, no
empty geometries, and the required `adm{level}_name` column. Aborts with
a clear, actionable error if any check fails. Shared by
[`eri_spatial_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_upload.md)
and
[`eri_spatial_promote()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_promote.md).

## Usage

``` r
.eri_spatial_validate_boundary(local_path, level, fn = "eri_spatial_upload")
```
