# Upload any local file to Azure

**\[experimental\]**

Thin wrapper around
[`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)
for uploading arbitrary local files to Azure, including binary formats
(shapefiles, images, etc.) not handled by
[`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md).

## Usage

``` r
eri_upload(local_path, file_loc, azcontainer = NULL)
```

## Arguments

- local_path:

  `str` Local path to the file to upload.

- file_loc:

  `str` Destination path in Azure (including filename).

- azcontainer:

  Azure container object from
  [`get_azure_storage_connection()`](https://thecartercenter.github.io/erifunctions/reference/get_azure_storage_connection.md).
