# Create an ERI-branded PowerPoint presentation

Loads the Carter Center branded PPTX template bundled with the package
and returns an
[`officer::read_pptx()`](https://davidgohel.github.io/officer/reference/read_pptx.html)
object. Use the returned object with `eri_pptx_add_*()` functions to
build up the presentation slide by slide, then write to disk with
[`eri_pptx_save()`](https://thecartercenter.github.io/erifunctions/reference/eri_pptx_save.md).

## Usage

``` r
eri_pptx_create(template = NULL)
```

## Arguments

- template:

  Optional character path to a custom `.pptx` template. Defaults to the
  bundled Carter Center template (`inst/templates/eri_template.pptx`).

## Value

An `officer` rpptx object.

## Examples

``` r
if (FALSE) { # \dontrun{
pptx <- eri_pptx_create()
pptx <- eri_pptx_add_title(pptx, "Hispaniola Malaria 2024",
                            subtitle = "Annual Programme Report")
pptx <- eri_pptx_add_table(pptx, summary_df, title = "Case summary")
eri_pptx_save(pptx, "outputs/malaria_report.pptx")
} # }
```
