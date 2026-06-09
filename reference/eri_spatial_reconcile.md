# Reconcile free-text place names to canonical admin units

A thin, opt-in **data-sourcing** helper that maps messy, free-text
locality names in incoming data to the canonical admin units in an
authoritative boundary `sf` object (from
[`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md)).
It does the name-reconciliation step many studies do by hand before
analysis – it is **not** an analysis tool (matching/windowing/modelling
stay in the research repo; see ADR-0006).

## Usage

``` r
eri_spatial_reconcile(
  data,
  loc_cols,
  shapefile,
  admin_cols,
  country_name = NULL,
  method = "osm",
  max_dist = 0L,
  status_col = "reconcile_status",
  coord_cols = c("longitude", "latitude"),
  ...
)
```

## Arguments

- data:

  A data frame or tibble containing the free-text place-name columns.

- loc_cols:

  `chr` vector of free-text column names, ordered **finest to coarsest**
  (e.g. `c("loc", "mun", "prov")`). Used both to match and to build the
  geocoding address (finest first).

- shapefile:

  An admin-boundary `sf` object, e.g. from
  [`eri_spatial_load()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_load.md).

- admin_cols:

  `chr` vector of canonical name columns in `shapefile`, **parallel to
  `loc_cols`** (same length, same finest-to-coarsest order). This
  ordering is load-bearing: passing the columns coarsest-first silently
  produces wrong matches.

- country_name:

  `chr` Country name appended to each geocoding address (e.g.
  `"Dominican Republic"`), improving geocoder accuracy. Optional.

- method:

  `chr` Geocoding service passed to
  [`tidygeocoder::geocode()`](https://jessecambon.github.io/tidygeocoder/reference/geocode.html)
  (e.g. `"osm"`, `"google"`). `NULL` disables geocoding (match-only).
  Default `"osm"`.

- max_dist:

  `int` Maximum edit distance for an approximate match on the finest
  level. `0` (default) requires an exact normalized match.

- status_col:

  `chr` Name of the status column added to the result. Default
  `"reconcile_status"`; values are `"matched"`, `"geocoded"`, or
  `"unresolved"`.

- coord_cols:

  `chr` length-2 names for the longitude and latitude columns added to
  the result. Default `c("longitude", "latitude")`. Populated for any
  row sent to the geocoder, regardless of its final status (so geocoded
  points that fall outside every polygon still record their
  coordinates).

- ...:

  Passed to
  [`tidygeocoder::geocode()`](https://jessecambon.github.io/tidygeocoder/reference/geocode.html)
  (e.g. `min_time`, `api_options`).

## Value

A tibble: `data` with `loc_cols` replaced by their canonical values
where reconciled (originals kept where unresolved), plus the two
`coord_cols` and `status_col`.

## Details

The reconciliation runs in two passes (per issue \#134):

1.  **Match first.** Free-text names are normalized (lower-cased,
    accent- and punctuation-stripped, whitespace-squished) and matched
    against the canonical names. Coarser levels must match exactly; the
    finest level may match approximately when `max_dist > 0`
    (Levenshtein distance via
    [`utils::adist()`](https://rdrr.io/r/utils/adist.html)). Matched
    rows are **not** geocoded.

2.  **Geocode the residual.** Rows that don't match are geocoded from an
    address built from `loc_cols` (+ `country_name`), then assigned a
    canonical admin unit by point-in-polygon via
    [`eri_spatial_join()`](https://thecartercenter.github.io/erifunctions/reference/eri_spatial_join.md).
    Set `method = NULL` to skip geocoding entirely (match-only).

Only the place-name address strings are sent to the geocoder; no data
records leave the machine. The `"google"` method is the most accurate
but requires an API key (`GOOGLEGEOCODE_API_KEY`) and is billed per
call; the default `"osm"` (Nominatim) needs no key. See
[`tidygeocoder::geocode()`](https://jessecambon.github.io/tidygeocoder/reference/geocode.html).

## Examples

``` r
if (FALSE) { # \dontrun{
dr_loc <- eri_spatial_load("dr", level = 4, cache = TRUE)
incidence <- eri_spatial_reconcile(
  incidence,
  loc_cols     = c("loc", "mun", "prov"),
  shapefile    = dr_loc,
  admin_cols   = c("adm4_name", "adm3_name", "adm2_name"),
  country_name = "Dominican Republic",
  method       = "google",  # needs GOOGLEGEOCODE_API_KEY
  max_dist     = 1
)
table(incidence$reconcile_status)
} # }
```
