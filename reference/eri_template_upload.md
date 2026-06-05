# Upload a custom template to Azure

Uploads a local `.qmd` or `.R` template file to `templates/` in the
`data/` Azure blob and registers it in `templates/_registry.yaml`. Once
uploaded, the template is available to all team members via
[`eri_template_pull()`](https://thecartercenter.github.io/erifunctions/reference/eri_template_pull.md).

## Usage

``` r
eri_template_upload(local_path, name, description, data_con = NULL)
```

## Arguments

- local_path:

  `chr` Path to the local template file.

- name:

  `chr` Short identifier for the template (without extension, e.g.
  `"eri_research_workflow"`). Must not collide with any bundled template
  name.

- description:

  `chr` Human-readable description of what this template is for.

- data_con:

  Azure container object for the `data/` blob. If `NULL`, connects
  automatically.

## Value

The Azure path the template was uploaded to (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
eri_template_upload(
  "templates/eri_research_workflow.qmd",
  name        = "eri_research_workflow",
  description = "Standard epidemiologist research workflow"
)
} # }
```
