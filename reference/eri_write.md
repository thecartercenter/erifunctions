# Write an object to a file

**\[experimental\]**

Thin wrapper around
[`erifunctions_io()`](https://thecartercenter.github.io/erifunctions/reference/erifunctions_io.md)
for writing files.

## Usage

``` r
eri_write(obj, file_loc, ..., azure = TRUE, azcontainer = NULL)
```

## Arguments

- obj:

  `str` Object to be loaded into Azure

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
  If `NULL` (the default), one is created ambiently from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md)'s
  own default – which is *not* necessarily the `data` container
  production data lives in (issue \#331). The verb-named wrappers
  ([`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md),
  `eri_write()`,
  [`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md),
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
