# Render an ERI-branded self-contained HTML report

Renders a Quarto template to a single portable `.html` file. No external
files are produced — the output is self-contained and can be emailed or
shared directly.

## Usage

``` r
eri_report_html(
  sections,
  path,
  title = "ERI Report",
  subtitle = NULL,
  author = NULL,
  date = format(Sys.Date(), "%B %d, %Y")
)
```

## Arguments

- sections:

  Named list of section definitions. Each element must be a named list
  with any of:

  - `heading` — character; section heading

  - `text` — character; narrative paragraph (markdown allowed)

  - `table` — data frame to render via
    [`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)

  - `figure` — a `ggplot` object

  - `figure_width`, `figure_height` — numeric inches (defaults: 8, 5)

- path:

  Character; output file path (should end in `.html`).

- title:

  Character; report title displayed in the header.

- subtitle:

  Optional character; subtitle displayed below the title.

- author:

  Optional character; displayed in the report header.

- date:

  Optional character; defaults to today's date.

## Value

`path` invisibly.

## Details

The report is structured as a series of sections, each optionally
containing a heading, free text, a formatted table (via
[`eri_table()`](https://thecartercenter.github.io/erifunctions/reference/eri_table.md)),
and/or a ggplot figure.

Requires the `quarto` package and a working Quarto installation
(<https://quarto.org>).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_report_html(
  sections = list(
    overview = list(
      heading = "Case summary",
      text    = "Cases increased in Q3.",
      table   = summary_df
    ),
    trends = list(
      heading = "Epidemic curve",
      figure  = epicurve_plot
    )
  ),
  path     = "outputs/malaria_report.html",
  title    = "Hispaniola Malaria 2024"
)
} # }
```
