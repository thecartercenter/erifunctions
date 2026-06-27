# Build a canonical blob path in the data/ container

**\[experimental\]**

Constructs a canonical blob storage path following the erifunctions
five-axis data model (ADR-0012):
`{country}/{disease}/{data_source}/{data_type}/{layer}/`, where
`data_source` is the channel (how the data arrives) and `data_type` is
the measure (what it captures). Use this instead of hard-coding path
strings.

The legacy four-axis form
`eri_data_path(country, disease, data_source, layer[, filename])` is
still accepted during the ADR-0012 migration and builds a measure-less
`{country}/{disease}/{data_source}/{layer}/` path — detected because its
fourth argument is a `layer` keyword (a `data_type` measure never is).

## Usage

``` r
eri_data_path(country, disease, data_source, data_type, layer, filename = NULL)
```

## Arguments

- country:

  `str` Country code (e.g. `"dr"`, `"ht"`, `"uga"`).

- disease:

  `str` Disease name (e.g. `"malaria"`, `"lf"`, `"oncho"`).

- data_source:

  `str` The channel: `"surveillance"`, `"programmatic"`, `"odk"`
  (extensible — see
  [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md);
  unknown values warn).

- data_type:

  `str` The measure: `"case"`, `"aggregate"`, `"treatment"`, `"tas"`,
  ... (extensible; unknown values warn).

- layer:

  `str` Pipeline layer: `"raw"`, `"staged"`, or `"processed"`.

- filename:

  `str` Optional filename to append. If `NULL` (default), returns the
  directory path only.

## Value

A character string with the canonical blob path.

## Examples

``` r
eri_data_path("dr", "malaria", "surveillance", "case", "staged")
#> [1] "dr/malaria/surveillance/case/staged"
#> "dr/malaria/surveillance/case/staged"

eri_data_path("uga", "oncho", "programmatic", "treatment", "raw", "2024_06.parquet")
#> [1] "uga/oncho/programmatic/treatment/raw/2024_06.parquet"
#> "uga/oncho/programmatic/treatment/raw/2024_06.parquet"
```
