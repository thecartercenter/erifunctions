# Build a canonical blob path in the data/ container

**\[experimental\]**

Constructs a canonical blob storage path following the erifunctions
three-layer data model: `{country}/{disease}/{data_type}/{layer}/`. Use
this instead of hard-coding path strings to ensure consistency across
all pipeline steps.

## Usage

``` r
eri_data_path(country, disease, data_type, layer, filename = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`, `"ug"`).

- disease:

  `str` Disease name (e.g. `"malaria"`, `"lf"`, `"oncho"`).

- data_type:

  `str` Data input type: `"surveillance"`, `"cmr"`, or `"odk"`.

- layer:

  `str` Pipeline layer: `"raw"`, `"staged"`, or `"processed"`.

- filename:

  `str` Optional filename to append. If `NULL` (default), returns the
  directory path only.

## Value

A character string with the canonical blob path.

## Examples

``` r
eri_data_path("dr", "malaria", "surveillance", "staged")
#> [1] "dr/malaria/surveillance/staged"
#> "dr/malaria/surveillance/staged"

eri_data_path("dr", "malaria", "surveillance", "raw", "2024_dr_malaria.parquet")
#> [1] "dr/malaria/surveillance/raw/2024_dr_malaria.parquet"
#> "dr/malaria/surveillance/raw/2024_dr_malaria.parquet"
```
