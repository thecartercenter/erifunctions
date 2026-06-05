# Connect to a SharePoint site

Returns a SharePoint site object for use with
[`eri_sharepoint_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_list.md),
[`eri_sharepoint_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_read.md),
and
[`eri_sharepoint_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_upload.md).
Authentication uses browser-based interactive login via `Microsoft365R`
– consistent with the rest of the package's Azure auth pattern. The
token is cached by `AzureAuth` so subsequent calls within a session do
not re-prompt.

## Usage

``` r
eri_sharepoint_connect(site_url)
```

## Arguments

- site_url:

  `chr` Full URL of the SharePoint site (e.g.
  `"https://cartercenter.sharepoint.com/sites/ERI"`).

## Value

A `ms_site` object from `Microsoft365R`.

## Examples

``` r
if (FALSE) { # \dontrun{
site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
} # }
```
