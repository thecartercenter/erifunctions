# Trigger a registered GitHub Actions pipeline

**\[experimental\]**

Dispatches a `workflow_dispatch` event to a registered GitHub Actions
pipeline from R. Authenticates with a GitHub Personal Access Token
stored in the `GITHUB_PAT` environment variable (needs `workflow`
scope).

### Registered pipelines

|           |                                    |                    |
|-----------|------------------------------------|--------------------|
| Name      | Repository                         | Workflow           |
| `hsp-mal` | thecartercenter/health-hsp-malaria | data_ingestion.yml |

## Usage

``` r
eri_trigger(
  pipeline,
  country,
  disease,
  year = NULL,
  phase = "prod",
  ref = "main"
)
```

## Arguments

- pipeline:

  `str` Registered pipeline name. Currently `"hsp-mal"`.

- country:

  `str` Country code passed as a workflow input (e.g. `"dr"`).

- disease:

  `str` Disease name passed as a workflow input (e.g. `"malaria"`).

- year:

  `int` or `NULL` Optional year passed as a workflow input. Default
  `NULL`.

- phase:

  `str` Pipeline phase. Default `"prod"`; use `"testing"` for dry runs.

- ref:

  `str` Branch or tag to run the workflow against. Default `"main"`.

## Value

Invisibly, the URL to the workflow's runs page on GitHub.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_trigger("hsp-mal", "dr", "malaria", phase = "testing")
} # }
```
