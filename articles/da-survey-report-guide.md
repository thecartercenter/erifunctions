# Final summaries and reports from an ODK survey

Once a survey has been pulled from ODK, cleaned, and **approved**, the
last step is the deliverable: a summary, a results table, a short
report. This guide takes an approved survey dataset to a final summary
using the disease helpers, then packages it for sharing.

It picks up where the [ODK
guide](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md)
(sync) and the [ingest
guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
(stage → approve) leave off, and uses the [reporting
toolkit](https://thecartercenter.github.io/erifunctions/articles/da-reporting-guide.md)
to package the result. The summary itself is offline.

## The golden rule

> **Report from the approved (`processed/`) dataset, not a working
> copy.** The number in your report should trace to a specific approved
> file in the catalog. Pull it with
> [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
> /
> [`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md),
> summarise, then package, don’t re-summarise an ad-hoc export that
> never went through the gate.

## The survey data

In practice you’d read the approved survey:
`eri_read("ht/lf/research/processed/…")` or an
[`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md)
roll-up. Here is a small individual-level **LF TAS** (Transmission
Assessment Survey) extract, one row per child tested, with FTS and RDT
antigen results:

``` r

tas <- data.frame(
  commune    = c(rep("Saut-d'Eau", 6), rep("Mirebalais", 6)),
  fts_result = c("Negative","Negative","Negative","Negative","Positive","Positive",
                 "Negative","Negative","Negative","Positive","Positive","Positive"),
  rdt_result = c("Negative","Negative","Negative","Negative","Negative","Positive",
                 "Negative","Negative","Negative","Negative","Positive","Positive")
)
```

## Summarise with the disease helper

[`eri_lf_tas_summary()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_tas_summary.md)
cross-tabulates the FTS and RDT results into a tidy per-combination
summary, optionally per survey unit:

``` r

summary <- eri_lf_tas_summary(tas, fts_col = "fts_result", rdt_col = "rdt_result",
                              group_col = "commune")
summary
#> # A tibble: 6 × 5
#>   commune    fts_result rdt_result     n   pct
#>   <chr>      <chr>      <chr>      <int> <dbl>
#> 1 Mirebalais Negative   Negative       3  50
#> 2 Mirebalais Positive   Negative       1  16.7
#> 3 Mirebalais Positive   Positive       2  33.3
#> 4 Saut-d'Eau Negative   Negative       4  66.7
#> 5 Saut-d'Eau Positive   Negative       1  16.7
#> 6 Saut-d'Eau Positive   Positive       1  16.7
```

Read it per commune by summing the `Positive` FTS rows: Saut-d’Eau has
**2 of 6** FTS-positive children, Mirebalais **3 of 6**. In a real TAS
you compare that antigen-positive count against the survey’s **critical
cutoff** to decide pass/fail, the helper gives you the counts the
decision rests on.

Other survey measures have their own helpers:
[`eri_lf_pooled_prev()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_pooled_prev.md)
for entomology/xenomonitoring pooled prevalence, and
[`eri_oncho_program_levels()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_program_levels.md)
/
[`eri_oncho_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_oncho_status_map.md)
for oncho, see [epi
analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md).

## Package it for sharing

The summary is an ordinary tibble, so the [reporting
toolkit](https://thecartercenter.github.io/erifunctions/articles/da-reporting-guide.md)
takes it the rest of the way, a branded table for the report:

``` r

eri_table(
  summary,
  title    = "LF TAS antigen results by commune",
  footnote = "FTS = filariasis test strip; RDT = rapid diagnostic test."
)
```

…a slide for a results meeting:

``` r

deck <- eri_pptx_create()
deck <- eri_pptx_add_title(deck, "LF TAS Results", subtitle = "Centre Department, 2026")
deck <- eri_pptx_add_table(deck, summary, title = "Antigen results by commune")
eri_pptx_save(deck, "lf_tas_results.pptx")
#> ✔ Presentation saved to 'lf_tas_results.pptx'
```

…or a self-contained HTML write-up with
[`eri_report_html()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_html.md),
or an Excel workbook with
[`eri_report_excel()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_excel.md).
For a programme-status **map** by evaluation unit,
[`eri_lf_status_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_lf_status_map.md)
wraps the spatial helpers (see the [spatial
workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md)).

## What’s next

- The [reporting
  guide](https://thecartercenter.github.io/erifunctions/articles/da-reporting-guide.md),
  the full table/figure/deck/Excel toolkit.
- [Epi
  analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md):
  the disease helpers (LF/oncho) and indicators.
- [Working with ODK
  Central](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md):
  pulling the survey in the first place.
- The [guide
  index](https://github.com/thecartercenter/erifunctions/blob/main/docs/guides.md).
  \`\`\`
