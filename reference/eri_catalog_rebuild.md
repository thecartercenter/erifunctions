# Rebuild the data catalog by scanning the processed layer

Reconstructs `_catalog/data_catalog.yaml` from the actual
processed-layer Parquet files in the `data/` Azure blob, making the
catalog a **derivable cache** rather than an irreplaceable record
(ADR-0002). Every `*/processed/*.parquet` path matching the five-axis
data model (`{country}/{disease}/{data_source}/{data_type}/processed/`)
— or the legacy four-axis form — becomes an entry. `registered_by` is
set to `"rebuilt"` and `row_count` is left `NA` (the file is not
opened). Use it to recover from a lost or corrupted catalog, or to pick
up files written outside
[`eri_catalog_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_register.md).

## Usage

``` r
eri_catalog_rebuild(data_con = NULL)
```

## Arguments

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The rebuilt catalog tibble (invisibly), as from
[`eri_catalog_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_query.md).

## Details

The rebuilt catalog **replaces** the existing one; entries for files
that no longer exist are dropped. Provenance fields that can only come
from the original registration (the real `registered_by`, `row_count`)
are not recovered — re-run
[`eri_catalog_verify()`](https://thecartercenter.github.io/erifunctions/reference/eri_catalog_verify.md)
afterwards if needed.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_catalog_rebuild()
} # }
```
