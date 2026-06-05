# Read a file from SharePoint into R

Downloads a file from a SharePoint document library to a temporary
location and reads it into R. The format is detected from the file
extension:

- `.xlsx` / `.xls` –
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html)

- `.csv` –
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)

- `.parquet` –
  [`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html)

- `.rds` –
  [`readr::read_rds()`](https://readr.tidyverse.org/reference/read_rds.html)

- Other – returns the local temp path as a character string

## Usage

``` r
eri_sharepoint_read(site, file_path, ...)
```

## Arguments

- site:

  A `ms_site` object from
  [`eri_sharepoint_connect()`](https://thecartercenter.github.io/erifunctions/reference/eri_sharepoint_connect.md).

- file_path:

  `chr` Path to the file within the document library (e.g.
  `"Shared Documents/Malaria/2024/ht_weekly.xlsx"`).

- ...:

  Additional arguments passed to the underlying read function (e.g.
  `sheet` for Excel files).

## Value

A tibble, data frame, or character path depending on file type.

## Examples

``` r
if (FALSE) { # \dontrun{
site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
df <- eri_sharepoint_read(site, "Shared Documents/Malaria/2024/ht_weekly.xlsx")
} # }
```
