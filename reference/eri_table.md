# ERI-branded formatted table

Wraps a data frame in a
[`flextable::flextable()`](https://davidgohel.github.io/flextable/reference/flextable.html)
styled with Carter Center branding: navy (`#44546A`) bold header,
alternating row shading, Calibri font, and an optional footnote. The
result is usable directly in Excel (via `openxlsx2`), HTML (via
[`flextable::save_as_html()`](https://davidgohel.github.io/flextable/reference/save_as_html.html)),
and PPTX (via `officer`).

## Usage

``` r
eri_table(
  data,
  title = NULL,
  footnote = NULL,
  highlight_cols = NULL,
  col_widths = NULL
)
```

## Arguments

- data:

  A data frame or tibble.

- title:

  Optional character string; displayed as a bold caption above the
  table.

- footnote:

  Optional character string; displayed as small italic text below the
  table.

- highlight_cols:

  Optional named list mapping column names to hex fill colours for
  conditional highlighting of entire columns. Example:
  `list(pct = "#FFC000")`.

- col_widths:

  Optional named numeric vector mapping column names to widths in
  inches. Unspecified columns are auto-sized.

## Value

A `flextable` object.

## Examples

``` r
df <- tibble::tibble(country = c("DR", "Haiti"), cases = c(120L, 340L))
eri_table(df, title = "Malaria cases by country")


.cl-ce0ec2a2{}.cl-ce0781ae{font-family:'Calibri';font-size:11pt;font-weight:bold;font-style:normal;text-decoration:none;color:rgba(255, 255, 255, 1.00);background-color:transparent;}.cl-ce0781cc{font-family:'Calibri';font-size:10pt;font-weight:normal;font-style:normal;text-decoration:none;color:rgba(0, 0, 0, 1.00);background-color:transparent;}.cl-ce0a832c{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1;background-color:transparent;}.cl-ce0a8340{margin:0;text-align:right;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1;background-color:transparent;}.cl-ce0aa672{width:0.946in;background-color:rgba(68, 84, 106, 1.00);vertical-align: middle;border-bottom: 1.5pt solid rgba(68, 84, 106, 1.00);border-top: 1.5pt solid rgba(68, 84, 106, 1.00);border-left: 1.5pt solid rgba(68, 84, 106, 1.00);border-right: 0.5pt solid rgba(204, 204, 204, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ce0aa67c{width:0.764in;background-color:rgba(68, 84, 106, 1.00);vertical-align: middle;border-bottom: 1.5pt solid rgba(68, 84, 106, 1.00);border-top: 1.5pt solid rgba(68, 84, 106, 1.00);border-left: 0.5pt solid rgba(204, 204, 204, 1.00);border-right: 1.5pt solid rgba(68, 84, 106, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ce0aa686{width:0.946in;background-color:transparent;vertical-align: middle;border-bottom: 0.5pt solid rgba(204, 204, 204, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 1.5pt solid rgba(68, 84, 106, 1.00);border-right: 0.5pt solid rgba(204, 204, 204, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ce0aa687{width:0.764in;background-color:transparent;vertical-align: middle;border-bottom: 0.5pt solid rgba(204, 204, 204, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0.5pt solid rgba(204, 204, 204, 1.00);border-right: 1.5pt solid rgba(68, 84, 106, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ce0aa688{width:0.946in;background-color:rgba(231, 230, 230, 1.00);vertical-align: middle;border-bottom: 1.5pt solid rgba(68, 84, 106, 1.00);border-top: 0.5pt solid rgba(204, 204, 204, 1.00);border-left: 1.5pt solid rgba(68, 84, 106, 1.00);border-right: 0.5pt solid rgba(204, 204, 204, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ce0aa690{width:0.764in;background-color:rgba(231, 230, 230, 1.00);vertical-align: middle;border-bottom: 1.5pt solid rgba(68, 84, 106, 1.00);border-top: 0.5pt solid rgba(204, 204, 204, 1.00);border-left: 0.5pt solid rgba(204, 204, 204, 1.00);border-right: 1.5pt solid rgba(68, 84, 106, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}

Malaria cases by country

country
```
