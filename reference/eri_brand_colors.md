# Carter Center brand colour palette

Returns a named character vector of the Carter Center colour palette
derived from the ERI programme proceedings slide deck. Use these values
for manual colour assignment in ggplot2 scales or table formatting.

## Usage

``` r
eri_brand_colors()
```

## Value

Named character vector of length 7.

## Examples

``` r
eri_brand_colors()
#>       navy       blue     orange       gold      green light_blue       gray 
#>  "#44546A"  "#4472C4"  "#ED7D31"  "#FFC000"  "#70AD47"  "#5B9BD5"  "#A5A5A5" 
eri_brand_colors()[["navy"]]
#> [1] "#44546A"
```
