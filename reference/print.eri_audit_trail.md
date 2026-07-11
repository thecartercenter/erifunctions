# Print method for an `eri_audit_trail`

Renders the timeline as a `cli`-formatted chronological list, grouped by
scope (country/disease/data_source/data_type/period) when that scope is
uniform across the trail. The tibble itself remains the API — this only
affects how it prints.

## Usage

``` r
# S3 method for class 'eri_audit_trail'
print(x, ...)
```

## Arguments

- x:

  An `eri_audit_trail` object from
  [`eri_audit()`](https://thecartercenter.github.io/erifunctions/reference/eri_audit.md).

- ...:

  Unused; included for S3 method compatibility.

## Value

Invisibly, `x`.
