# ERI standard colour schemes

Returns a named character vector of hex colours for a given programme or
purpose. Designed to be passed directly to
`scale_fill_manual(values = ...)`.

## Usage

``` r
eri_color_scheme(type)
```

## Arguments

- type:

  `chr` Scheme name. One of:

  - `"malaria.incidence"` — white / light-green / yellow / red (0, \<1,
    1–10, \>=10 per 1 000)

  - `"lf.status"` — 5-level LF programme status (Non-endemic → PTS
    TAS-3)

  - `"oncho.status"` — 5-level OEPA oncho status (Non-endemic → Verified
    free)

  - `"activities"` — Completed (green) / Not completed (red)

  - `"dq.flag"` — pass (grey) / warning (orange) / fail (red)

## Value

A named character vector of hex colour codes. Names are the category
labels; values are hex colours.

## Examples

``` r
if (FALSE) { # \dontrun{
ggplot(...) +
  geom_sf(aes(fill = incidence_class)) +
  scale_fill_manual(values = eri_color_scheme("malaria.incidence"))
} # }
```
