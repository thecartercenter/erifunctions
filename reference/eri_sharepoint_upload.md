# Upload a local file to a SharePoint document library

Uploads a file from the local filesystem to a SharePoint document
library folder. The destination folder is created automatically if it
does not exist. Returns the SharePoint item URL invisibly so it can be
pasted into emails or logged.

## Usage

``` r
eri_sharepoint_upload(local_path, site, folder_path, overwrite = TRUE)
```

## Arguments

- local_path:

  `chr` Path to the local file to upload.

- site:

  A `ms_site` object from
  [`eri_sharepoint_connect()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_connect.md).

- folder_path:

  `chr` Destination folder within the document library (e.g.
  `"Shared Documents/Reports/2024"`).

- overwrite:

  `lgl` If `TRUE` (default) an existing file at the destination is
  silently replaced. If `FALSE` the function errors when the destination
  already exists.

## Value

The SharePoint item URL (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
eri_sharepoint_upload("outputs/ht_malaria_summary.xlsx", site,
                       "Shared Documents/Reports/2024")
} # }
```
