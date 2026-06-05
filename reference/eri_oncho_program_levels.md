# OEPA onchocerciasis program status levels

Returns the ordered vector of OEPA oncho program status levels used for
plotting and data validation. Levels are ordered from no endemicity to
verified elimination.

## Usage

``` r
eri_oncho_program_levels()
```

## Value

Character vector of length 5.

## Examples

``` r
eri_oncho_program_levels()
#> [1] "Non-endemic"                      "Under surveillance"              
#> [3] "MDA ongoing"                      "MDA stopped - under surveillance"
#> [5] "Verified free of transmission"   
```
