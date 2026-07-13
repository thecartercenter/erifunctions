# Bring a monthly report into the system, interactively (the guided console front door)

**\[experimental\]**

A menu-driven wizard that carries a Data Analyst through an entire
pipeline run – which country, which file, which reporting period – and
calls the existing scriptable core on their behalf. Never asks for a
function name or an Azure path. `mirror_pipeline` is auto-detected from
[`eri_cutover_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_status.md)
and never asked about. Every mutation is one already-tested function
([`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md),
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md),
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
[`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
[`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md),
[`eri_onboard_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_cmr.md),
[`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)),
and data quality review/approval hands off directly into the same loop
[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
uses (for CMR) or points at the scriptable triage tools directly
([`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md),
[`eri_dq_flag_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_flag_resolve.md),
for surveillance ingest) – nothing here is reimplemented, and every
function this calls stays fully usable directly in a script or CI.

Currently covers bringing in a monthly CMR report, bringing in a
surveillance dataset (CSV/Excel line-list), pulling in ODK survey
submissions, and onboarding a new country, disease, or data type, end to
end. ODK sync stops at `research/raw/` – there is no automated
stage-then-approve path for ODK data yet (the real guide shows a manual
[`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md)
step) – and onboarding stops once the schema template(s) are written
(and, for surveillance/CMR, the Azure folders exist – an NTD disease's
MDA/prevalence schemas are local-only, by
[`eri_onboard_disease()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_disease.md)'s
own design) – filling in the schema's disease-specific columns,
validating it, and submitting it via pull request stay a human,
judgment-driven step (see `vignettes/da-onboard-guide.Rmd`'s "onboarding
scaffolds; it doesn't finish for you"). The wizard is honest about
handing off at both points rather than fabricating steps the underlying
tooling doesn't support or shouldn't automate.

**Interactive only.** In a script or CI, use the scriptable core
directly:
[`eri_upload()`](https://thecartercenter.github.io/erifunctions/reference/eri_upload.md),
[`eri_stage_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_stage_cmr.md),
[`eri_split_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_split_cmr.md),
[`eri_cmr_dq_report()`](https://thecartercenter.github.io/erifunctions/reference/eri_cmr_dq_report.md),
[`eri_approve_cmr()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve_cmr.md),
[`eri_ingest()`](https://thecartercenter.github.io/erifunctions/reference/eri_ingest.md),
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
[`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md),
[`eri_onboard_country()`](https://thecartercenter.github.io/erifunctions/reference/eri_onboard_country.md).

## Usage

``` r
eri_do()
```

## Value

Invisibly, `NULL`. Every effect happens through the scriptable core it
calls.

## See also

[`eri_dq_review()`](https://thecartercenter.github.io/erifunctions/reference/eri_dq_review.md)
for the data-quality review loop this hands off into,
[`eri_cutover_status()`](https://thecartercenter.github.io/erifunctions/reference/eri_cutover_status.md)
for the mirroring criterion this checks automatically.

## Examples

``` r
if (FALSE) { # \dontrun{
eri_do()
} # }
```
