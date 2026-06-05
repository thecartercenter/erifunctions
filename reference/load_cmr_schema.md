# Load a CMR country schema

**\[experimental\]**

Reads the bundled CMR YAML schema for a given country code. Schemas live
in `inst/schemas/cmr/` and define which sheets are present for that
country and the required field codes expected in each sheet.

## Usage

``` r
load_cmr_schema(country)
```

## Arguments

- country:

  `str` Three-letter country code (e.g. `"uga"`, `"eth"`).

## Value

A named list with keys `country`, `country_code`, `language`,
`template`, and `sheets`. Each element of `sheets` is itself a named
list with `field_code_prefix` and `required_fields`.

## Examples

``` r
schema <- load_cmr_schema("uga")
names(schema$sheets)  # sheet names present for Uganda
#> [1] "RB Treatment"  "SCH Treatment" "LF MMDP"       "CDD Training" 
#> [5] "CS Training"   "MMDP Training" "Surveys"      
```
