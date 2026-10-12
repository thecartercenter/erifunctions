# Trigger a registered GitHub Actions pipeline

**\[deprecated\]**

**Deprecated, and every call fails.** The only registered pipeline
dispatched a workflow (`data_ingestion.yml`) that does not exist in
`health-hsp-malaria`; the real workflow there takes a different set of
inputs and a different country vocabulary. Triggering the contractor's
pipeline from R is a capability erifunctions is retiring, not repairing:
erifunctions is taking over the Power BI output contract directly (see
[ADR-0027](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0027-erifunctions-owns-bi-output-contract.md)),
after which there is no pipeline left to trigger. Calling this function
now warns and then fails the same way it always did once it reaches
GitHub.

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
# deprecated -- this always errors, see @description
eri_trigger("hsp-mal", "dr", "malaria", phase = "testing")
} # }
```
