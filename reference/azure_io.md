# Helper function to read and write key data to the Azure environment

The function serves as the primary way to interact with the Azure system
from R. It can read, write, create folders, check whether a file or a
folder exists, upload files, and list all files in a folder.

## Usage

``` r
azure_io(
  io,
  file_loc = NULL,
  obj = NULL,
  azcontainer = suppressMessages(get_azure_storage_connection()),
  force_delete = FALSE,
  local_path = NULL,
  progress = FALSE,
  ...
)
```

## Arguments

- io:

  `str` The type of operation to perform in Azure

  - `"read"` Read a file from Azure, must be an rds, csv, rda, or
    xls/xlsx file.

  - `"write"` Write a file to Azure, must be an rds, csv, rda, or
    xls/xlsx file. To write an Excel file with multiple sheets, pass a
    named list containing the tibbles of interest. See examples.

  - `"exists.dir"` Returns a boolean after checking to see if a folder
    exists.

  - `"exists.file"`Returns a boolean after checking to see if a file
    exists.

  - `"create"` Creates a folder and all preceding folders.

  - `"list"` Returns a tibble with all objects in a folder.

  - `"upload"` Moves a file of any type to Azure

  - `"delete"` Deletes a file.

  - `"delete.dir"` Deletes a folder.

- file_loc:

  `str` Location to "read", "write", "exists.dir", "exists.file",
  "create" or "list".

- obj:

  `robj` Object to be saved, needed for `"write"`. Defaults to `NULL`.

- azcontainer:

  Azure container object returned from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).

- force_delete:

  `logical` Use delete io without confirmation prompt. Default `FALSE`.

- local_path:

  `str` Local file pathway to upload a file to Azure. Default is `NULL`.
  This parameter is only required when passing `"upload"` in the `io`
  parameter.

- progress:

  `logical` Show AzureStor's byte progress bar for the transfer. Default
  `FALSE` (suppressed). Set `TRUE` for a large single read/upload that
  needs visible feedback.

- ...:

  Optional parameters that work with
  [`readr::read_delim()`](https://readr.tidyverse.org/reference/read_delim.html),
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html),
  or
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html).

## Value

Output dependent on argument passed in the `io` parameter.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- azure_io("read", file_loc = "df1.csv")
df2 <- azure_io("read", file_loc = "df2.xlsx", sheet = 1, skip = 2)
list_of_df <- list(df_1 = df, df_2 = df)
azure_io("write", file_loc = "Data/test/df.csv", obj = df)
azure_io("write", file_loc = "Data/test/df.xlsx", obj = list_of_df)
azure_io("exists.dir", "Data/nonexistentfolder")
azure_io("exists.file", file_loc = "Data/test/df1.csv")
azure_io("create", "Data/nonexistentfolder")
azure_io("list")
azure_io("upload", file_loc = "Data/test", local_path = "C:/Users/ABC1/Desktop/df2.csv")
} # }
```
