# Copy a template to a local destination

Copies a named template — bundled or Azure-hosted — to `dest`. Bundled
templates are copied directly from the package installation. Azure
templates are downloaded from `templates/{filename}` in the `data/`
blob.

## Usage

``` r
eri_template_pull(name, dest = getwd(), data_con = NULL)
```

## Arguments

- name:

  `chr` Template name as shown by
  [`eri_template_list()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_list.md)
  (without extension).

- dest:

  `chr` Local directory to copy the template into. Defaults to
  [`getwd()`](https://rdrr.io/r/base/getwd.html).

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

Local path to the copied template (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_template_pull("eri_daily_workflow")
eri_template_pull("eri_research_workflow")
} # }
```
