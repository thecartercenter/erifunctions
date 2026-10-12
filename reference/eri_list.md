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
  If `NULL` (the default), one is created ambiently from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)'s
  own default – which is *not* necessarily the `data` container
  production data lives in (issue \#331). The verb-named wrappers
  ([`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md),
  [`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md),
  `eri_list()`,
  [`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md),
  [`eri_dir_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_exists.md),
  [`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md),
  [`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md),
  [`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md),
  [`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md))
  resolve this ambient connection through
  [`.eri_dal_verb_connect()`](https://thecartercenter.github.io/erifunctions/reference/dot-eri_dal_verb_connect.md)
  and `cli_warn` when it lands somewhere other than `data`. Calling
  [`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
  directly bypasses that warning; pass `azcontainer` explicitly to
  target a specific container, e.g.
  `get_azure_storage_connection(storage_name = "data")`.
