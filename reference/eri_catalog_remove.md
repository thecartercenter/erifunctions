# Remove a file's entry from the data catalog

Deletes the catalog entry whose `path` matches, from
`_catalog/data_catalog.yaml` in the `data/` Azure blob. This is the
inverse of
[`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md)
— use it when a processed file has been deleted or superseded and should
no longer appear in the catalog. Removing the catalog entry does **not**
delete the underlying blob.

## Usage

``` r
eri_catalog_remove(path, data_con = NULL)
```

## Arguments

- path:

  `chr` Blob path of the entry to remove (e.g.
  `"dr/malaria/surveillance/processed/2024_W01.parquet"`).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

`TRUE` if an entry was removed, `FALSE` if no entry matched (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_catalog_remove("atlantis/malaria/surveillance/processed/2024-W01.parquet")
} # }
```
