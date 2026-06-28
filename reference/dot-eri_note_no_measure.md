# Signpost the four-axis (no-measure) approval form

When
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
runs without a `data_type`, the dataset is filed and catalogued at the
channel level with `data_type = NA` (the measure). That is a legitimate
choice for channel-only data (e.g. ODK), but it is indistinguishable
from forgetting the measure, so we say so **once per R session**
(guarded by `options(erifunctions.noted_no_measure)`) rather than on
every call. No-op when a measure is supplied.

## Usage

``` r
.eri_note_no_measure(data_type)
```
