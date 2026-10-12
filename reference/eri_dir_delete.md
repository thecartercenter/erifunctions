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
  If `NULL` (the default), one is created ambiently from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)'s
  own default – which is *not* necessarily the `data` container
  production data lives in (issue \#331). The verb-named wrappers
  ([`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md),
  [`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md),
  [`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md),
  [`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md),
  [`eri_dir_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_exists.md),
  [`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md),
  [`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md),
  `eri_dir_delete()`,
  [`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md))
  resolve this ambient connection through
  [`.eri_dal_verb_connect()`](https://thecartercenter.github.io/erifunctions/reference/dot-eri_dal_verb_connect.md)
  and `cli_warn` when it lands somewhere other than `data`. Calling
  [`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
  directly bypasses that warning; pass `azcontainer` explicitly to
  target a specific container, e.g.
  `get_azure_storage_connection(storage_name = "data")`.

- prune_catalog:

  `lgl` If `TRUE` (default when `azure`), remove catalog entries under
  `file_loc` after the delete. Fail-silent: a catalog hiccup never
  blocks the delete.
