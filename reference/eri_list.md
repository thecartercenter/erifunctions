# List files in a directory

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for listing directory contents.

## Usage

``` r
eri_list(file_loc = "", full_names = TRUE, azure = TRUE, azcontainer = NULL)
```

## Arguments

- file_loc:

  `str` Path of file.

- full_names:

  `logical` If `io="list"`, include the full reference path. Default
  `TRUE`.

- azure:

  `logical` Whether the function should interact with the TCC Azure
  environment. Defaults to `TRUE`, otherwise, interacts with files
  locally.

- azcontainer:

  `Azure container` A container object returned by
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
