# Read a file

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for reading files, with a dedicated help page and tab-completable name.

## Usage

``` r
eri_read(file_loc, ..., azure = TRUE, azcontainer = NULL, progress = FALSE)
```

## Arguments

- file_loc:

  `str` Path of file.

- ...:

  Optional parameters that work with
  [`readr::read_delim()`](https://readr.tidyverse.org/reference/read_delim.html)
  or
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html).

- azure:

  `logical` Whether the function should interact with the TCC Azure
  environment. Defaults to `TRUE`, otherwise, interacts with files
  locally.

- azcontainer:

  `Azure container` A container object returned by
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- progress:

  `logical` Show AzureStor's byte progress bar for the transfer. Default
  `FALSE` (suppressed; erifunctions renders its own output). Set `TRUE`
  for a large single read/upload.
