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

  `str` Country code, usually the three-letter reporting code (e.g.
  `"uga"`, `"eth"`). A training sandbox schema such as `"atlantis"` — a
  fictional country for exercising the pipeline without touching real
  data — is also accepted.

## Value

A named list with keys `country`, `country_code`, `language`,
`template`, and `sheets`. Each element of `sheets` is itself a named
list with `field_code_prefix` and `required_fields`.

## Examples

``` r
schema <- load_cmr_schema("uga")
names(schema$sheets)  # sheet names present for Uganda
#>  [1] "RB Treatment"                  "SCH Treatment"                
#>  [3] "LF MMDP"                       "VHT Training"                 
#>  [5] "Parish Supervisors Training"   "Local Leaders Training"       
#>  [7] "Subcounty Supervisor Training" "MMDP (surgery) Training"      
#>  [9] "MMDP (patient) Training"       "Field Ento Training"          
#> [11] "Lab Training"                  "LF Surveys"                   
#> [13] "RB Epi Surveys"                "RB Ento Surveys"              
```
