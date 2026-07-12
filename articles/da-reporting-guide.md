# Branded tables, figures, and decks for outputs

**Walkthrough** · ~10 min · needs: nothing · sandbox-safe: yes (no Azure
touched)

Once data is approved, a lot of the job is turning it into **outputs**,
a table for a memo, a figure for proceedings, a workbook for a partner,
a slide deck for a meeting. `erifunctions` ships a small, consistent
**reporting toolkit** so those come out on-brand without fiddling with
styling each time.

This guide is the general toolkit (it runs on any data frame). Specific
recurring reports get their own templates as they’re defined; the domain
figures, **maps** and **epidemic curves**, live in the [spatial
workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md)
and [epi
analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md)
guides.

## Before you start

``` r

library(erifunctions)
```

In practice you’d pull approved data first,
[`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md)
for a roll-up (see the [ad-hoc
guide](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.md))
or
[`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
for one dataset. Here we use a small frame so every chunk runs as-is:

``` r

dat <- data.frame(
  province   = c("North", "South", "East", "West"),
  cases      = c(420, 180, 260, 95),
  tested     = c(1200, 600, 900, 400)
)
dat$positivity <- round(dat$cases / dat$tested * 100, 1)
```

## A branded table

[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)
turns a data frame into a styled
[`flextable`](https://davidgohel.github.io/flextable/): ERI navy header,
banded rows, an optional title and footnote, ready to drop into an
HTML/Word/PowerPoint output:

``` r

eri_table(
  dat,
  title          = "Malaria cases by province, 2026",
  footnote       = "Source: sandbox data",
  highlight_cols = list(positivity = "#FFC000")
)
```

It returns a `flextable` object; print it in a report, or hand it to the
Word/PowerPoint/HTML helpers. `highlight_cols` is a **named list**
mapping a column to a fill colour (`list(col = "#hex")`), use it to
shade the column you want the eye to land on.

## An on-brand figure

Any `ggplot` becomes on-brand by adding
[`eri_brand_ggplot_theme()`](https://thecartercenter.github.io/erifunctions/reference/eri_brand_ggplot_theme.md):

``` r

library(ggplot2)
p <- ggplot(dat, aes(x = province, y = cases)) +
  geom_col() +
  labs(title = "Cases by province", x = NULL, y = "Cases") +
  eri_brand_ggplot_theme()
p
```

For domain figures there are purpose-built helpers,
`eri_plot_theme("map" | "epicurve")` and
[`eri_color_scheme()`](https://thecartercenter.github.io/erifunctions/reference/eri_color_scheme.md)
(e.g. the standard `"malaria.incidence"` bins), and the `eri_map_*`
family for choropleths and point maps. Those need boundary data; the
[spatial
workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md)
guide covers them end-to-end, and [epi
analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md)
covers
[`eri_epidemic_curve()`](https://thecartercenter.github.io/erifunctions/reference/eri_epidemic_curve.md).

## An Excel workbook

For a partner who wants the numbers,
[`eri_report_excel()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_excel.md)
writes a styled multi-sheet workbook in one call, each named element of
`sheets` becomes a tab:

``` r

eri_report_excel(
  sheets = list(Cases = dat),
  path   = "malaria_summary_2026.xlsx",
  title  = "Malaria summary 2026"
)
#> ✔ Workbook saved to 'malaria_summary_2026.xlsx'
```

Need finer control (multiple sheets, added titles)? Build it up with
[`eri_wb_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_create.md)
→
[`eri_wb_add_sheet()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_add_sheet.md)
→
[`eri_wb_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_wb_save.md).

## A slide deck for proceedings

The `eri_pptx_*` family builds a PowerPoint slide by slide, title,
sections, tables, and plots, so a meeting deck is reproducible code, not
manual copy-paste:

``` r

deck <- eri_pptx_create()
deck <- eri_pptx_add_title(deck, "Malaria Summary 2026", subtitle = "ERI")
deck <- eri_pptx_add_table(deck, dat, title = "Cases by province")
deck <- eri_pptx_add_plot(deck, p, title = "Cases by province")
eri_pptx_save(deck, "malaria_summary_2026.pptx")
#> ✔ Presentation saved to 'malaria_summary_2026.pptx'
```

Each `eri_pptx_add_*` call returns the updated deck, so you pipe or
reassign as you go.
[`eri_pptx_create()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_create.md)
accepts a `template =` to start from a branded master.

## An HTML report

[`eri_report_html()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_html.md)
assembles a self-contained HTML page from `sections` (text, tables, and
plots), for a quick shareable write-up. For a full parameterised report,
[`eri_report_qmd_template()`](https://thecartercenter.github.io/erifunctions/reference/eri_report_qmd_template.md)
scaffolds a Quarto document you fill in.

## What’s next

- **Maps:** the [spatial
  workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md),
  choropleths, incidence maps, insets.
- **Curves & indicators:** [epi
  analytics](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md),
  [`eri_epidemic_curve()`](https://thecartercenter.github.io/erifunctions/reference/eri_epidemic_curve.md),
  incidence, disease helpers.
- **Where the data comes from:** the [ad-hoc
  guide](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.md)
  (`eri_query`) and the [ingest
  guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md).
- The [guide
  index](https://github.com/thecartercenter/erifunctions/blob/main/docs/guides.md).
  \`\`\`
