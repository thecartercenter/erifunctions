# Upload a LandScan population raster to Azure

Validates and uploads a local LandScan `.tif` raster to
`data/spatial/landscan/landscan-global-{year}.tif` in the `data/` Azure
blob. Only the plain raster file should be uploaded (not the colorized
version).

## Usage

``` r
eri_landscan_upload(local_path, year, data_con = NULL)
```

## Arguments

- local_path:

  `chr` Local path to the LandScan `.tif` file, e.g.
  `"data/LandScan/landscan-global-2024/landscan-global-2024.tif"`.

- year:

  `int` The LandScan dataset year (e.g. `2024`).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The Azure blob path (invisibly).

## Details

LandScan rasters are ~100 MB. Upload only the latest year; older years
are automatically kept and accessible via
[`eri_landscan_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_landscan_list.md).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_landscan_upload(
  local_path = "data/LandScan/landscan-global-2024/landscan-global-2024.tif",
  year       = 2024
)
} # }
```
