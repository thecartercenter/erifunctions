# Getting started with erifunctions

**Walkthrough** · ~10 min · needs: nothing · sandbox-safe: n/a
(install + orientation only)

`erifunctions` is the Carter Center ERI team’s R package, the way **Data
Analysts** and **Epidemiologists** work with TCC’s Azure-centred data
system across countries (Haiti, DR, Uganda, OEPA, …) and diseases
(malaria, oncho, LF, SCH, STH). You install it, authenticate through
your browser, and call functions; you don’t edit the package. This page
is the **front door**: learn the one idea every guide assumes, then
follow your role’s path.

## 1. Install and connect

``` r

install.packages("remotes")
remotes::install_github("thecartercenter/erifunctions")
library(erifunctions)
```

Azure access is **zero-config**, the first command that needs it opens
your browser to sign in. ODK, SharePoint, and Teams need a little setup.
The **[Connecting to Azure, ODK, SharePoint &
Teams](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)**
guide walks through each and how to confirm it works, including the one
thing to do **before your first governed action**: set `ERI_ANALYST_ID`
so approvals and logs carry your name, not your OS username.

## 2. Learn the one idea: how data is addressed

Every dataset lives in the `data/` Azure blob under a five-axis path
([ADR-0012](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0012-source-measure-data-model.md)):

    data/{country}/{disease}/{data_source}/{data_type}/{layer}/

The idea that makes the whole system click: **how the data arrives
(`data_source`) is separate from what it measures (`data_type`)**. The
same `surveillance` channel is a `case` line-list in one country and an
`aggregate` weekly count in another; one CMR fans out to `treatment`,
`mmdp`, and survey measures across diseases.

Run
[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)
once, it prints the whole vocabulary, so you never have to guess a
value:

``` r

eri_data_model()
#> ── Data-addressing model (ADR-0012) ──
#> Path: 'data/{country}/{disease}/{data_source}/{data_type}/{layer}/'
#>
#> ── data_source (channel / how the data arrives) ──
#> • surveillance -- Direct disease-output feed (e.g. a MoH surveillance system).
#> • programmatic -- Programmatic activity/coverage data (CMR, MDA feeds); spans diseases.
#> • research     -- Research surveys/studies; DA-managed, flexible measure.
#>   (… plus the measures, formats, and layers, and the transitional cmr/odk tokens.)
```

Everything moves through three **layers**, `raw/` (as received) →
`staged/` (DQ-checked) → `processed/` (the canonical data the whole team
trusts). Nothing reaches `processed/` without a human calling
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

## 3. Follow your role’s path

The guides are short, copy-paste, run-it-live walkthroughs on safe
sandbox data. Do your role’s set **in order**; dip into the rest as your
work needs them.

### New Data Analyst

For the paced version of this with checkpoints, follow the [**onboarding
path**](https://thecartercenter.github.io/erifunctions/articles/onboarding.md),
and keep the [**DA cheat
sheet**](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.md)
and the [data-model
card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md)
open as you work. Once you’re connected,
**[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)**
is a guided console wizard that runs each pipeline below for you,
decisions instead of function names, see the [eri_do()
tour](https://thecartercenter.github.io/erifunctions/articles/da-do-guide.md)
for what its menu looks like.

1.  [Connecting to the
    services](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)
2.  [Onboarding a new country / disease / data
    type](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md):
    stand up the space
3.  [Ingesting a surveillance
    dataset](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md):
    raw → DQ → staged → **approved**
4.  [Triaging the error & DQ log
    backlog](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md):
    find what failed and close it out

Then, as those feeds arrive: [monthly **CMR**
reports](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md)
and [**ODK Central**
forms](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md).

### New Epidemiologist

1.  [Connecting to the
    services](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)
2.  [A complete research
    workflow](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.md):
    source approved data, analyse, tag a version
3.  [Reconciling localities to admin
    units](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.md):
    messy place names → canonical units
4.  [Catching anomalies in a new
    extract](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.md):
    QC for epidemiological sense

Then the [epi analytics
helpers](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md)
for incidence, epiweeks, and curves.

## 4. Going deeper

- **Topic deep-dives** explain the engines behind the role guides: the
  [data-quality
  pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.md),
  the [spatial
  workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.md),
  and [SharePoint &
  Teams](https://thecartercenter.github.io/erifunctions/articles/sharepoint-workflow.md).
- **Extending the package**: [adding a new
  program](https://thecartercenter.github.io/erifunctions/articles/adding-a-program.md):
  contribute a schema and disease analytics for a new country/disease.
- The [function
  reference](https://thecartercenter.github.io/erifunctions/reference/index.md)
  groups every function by purpose, and the
  [roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md)
  tracks where the system is headed.
