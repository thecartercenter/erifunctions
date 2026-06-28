# Delete a directory

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for deleting a directory. When deleting from the `data/` blob, it also
**prunes the data catalog**: any
[`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md)
entry whose path falls under `file_loc` is removed, so deleting a
namespace never leaves dangling rows that
[`eri_catalog_verify()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_verify.md)
would later flag.

## Usage

``` r
eri_dir_delete(
  file_loc,
  azure = TRUE,
  azcontainer = NULL,
  prune_catalog = azure
)
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

- prune_catalog:

  `lgl` If `TRUE` (default when `azure`), remove catalog entries under
  `file_loc` after the delete. Fail-silent: a catalog hiccup never
  blocks the delete.
