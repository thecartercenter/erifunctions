# Check whether a directory exists

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for checking directory existence.

## Usage

``` r
eri_dir_exists(file_loc, azure = TRUE, azcontainer = NULL)
```

## Arguments

- file_loc:

  `str` Path of file.

- azure:

  `logical` Whether the function should interact with the TCC Azure
  environment. Defaults to `TRUE`, otherwise, interacts with files
  locally.

- azcontainer:

  `Azure container` A container object returned by
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
