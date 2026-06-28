# Delete a file

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for deleting a file. Note this does **not** touch the data catalog — if
you are tearing down a namespace, use
[`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md),
which also prunes catalog entries under the deleted path.

## Usage

``` r
eri_delete(file_loc, azure = TRUE, azcontainer = NULL)
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
