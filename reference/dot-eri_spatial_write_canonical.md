# Write a validated boundary to the canonical `/spatial` store, guarding overwrites.

Refuses to clobber an existing canonical boundary unless
`overwrite = TRUE`, because `/spatial` is shared cleaned reference data
many users pull for figures (ADR-0009). The escalation message differs
by entry point. Returns a list with the canonical `blob_path`, whether
it `existed`, and where the prior version was `archived_to` (or `NULL`).

## Usage

``` r
.eri_spatial_write_canonical(sf_obj, country, level, con, overwrite, via)
```
