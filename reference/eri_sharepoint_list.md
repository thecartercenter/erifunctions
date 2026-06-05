# List files in a SharePoint document library folder

Returns a tibble of files and folders at the specified path within the
site's default document library.

## Usage

``` r
eri_sharepoint_list(site, folder_path = "/")
```

## Arguments

- site:

  A `ms_site` object from
  [`eri_sharepoint_connect()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_connect.md).

- folder_path:

  `chr` Folder path within the document library (e.g.
  `"Shared Documents/Malaria/2024"`). Defaults to `"/"` (root).

## Value

A tibble with columns `name`, `size` (bytes), `modified` (`POSIXct`),
`is_folder` (logical), and `path`.

## Examples

``` r
if (FALSE) { # \dontrun{
site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
eri_sharepoint_list(site, "Shared Documents/Malaria/2024")
} # }
```
