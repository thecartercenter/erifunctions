# erifunctions i/o handler

**\[experimental\]**

Manages read/write/list/create/delete functions for erifunctions. This
function is adapted from
[tidypolis_io](https://github.com/nish-kishore/tidypolis/blob/4e2f75e5ee3205b84c5b78f4b1776e2270e1f9ec/R/dal.R#L15).

For a more ergonomic interface with tab-completion and per-operation
help pages, consider the verb-named wrappers:
[`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md),
[`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md),
[`eri_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_list.md),
[`eri_file_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_file_exists.md),
[`eri_dir_exists()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_exists.md),
[`eri_dir_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_create.md),
[`eri_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_delete.md),
[`eri_dir_delete()`](https://thecartercenter.github.io/erifunctions/reference/eri_dir_delete.md).

## Usage

``` r
erifunctions_io(
  io,
  file_loc = "",
  obj = NULL,
  azure = TRUE,
  azcontainer = suppressMessages(get_azure_storage_connection()),
  full_names = TRUE,
  ...
)
```

## Arguments

- io:

  `str` The type of operation to use. Valid values include:

  - `"read"`: reads data from the specified `file_path`.

  - `"write"`: writes data to the specified `file_path`.

  - `"list"`: lists the files in the specified `file_path`.

  - `"exists.dir"`: determines whether a directory is present.

  - `"exists.file"`: determines whether a file is present.

  - `"create.dir"`: creates a directory to the specified `file_path`.

  - `"delete"`: deletes a file in the specified `file_path`.

  - `"delete.dir"`: deletes a folder in the specified `file_path.`

- file_loc:

  `str` Path of file.

- obj:

  `str` Object to be loaded into Azure

- azure:

  `logical` Whether the function should interact with the TCC Azure
  environment. Defaults to `TRUE`, otherwise, interacts with files
  locally.

- azcontainer:

  `Azure container` A container object returned by
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- full_names:

  `logical` If `io="list"`, include the full reference path. Default
  `TRUE`.

- ...:

  Optional parameters that work with
  [`readr::read_delim()`](https://readr.tidyverse.org/reference/read_delim.html)
  or
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html).

## Value

Conditional on `io`. If `io` is `"read"`, then it will return a tibble.
If `io` is `"list"`, it will return a list of file names. Otherwise, the
function will return `NULL`. `exists.dir` and `exists.file` will return
a `logical`.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- erifunctions_io("read", file_loc = "df1.csv")
df2 <- erifunctions_io("read", file_loc = "df2.xlsx", sheet = 1, skip = 2)
list_of_df <- list(df_1 = df, df_2 = df)
erifunctions_io("write", file_loc = "Data/test/df.csv", obj = df)
erifunctions_io("write", file_loc = "Data/test/df.xlsx", obj = list_of_df)
erifunctions_io("exists.dir", "Data/nonexistentfolder")
erifunctions_io("exists.file", file_loc = "Data/test/df1.csv")
erifunctions_io("create.dir", "Data/nonexistentfolder")
erifunctions_io("list")
} # }
```
