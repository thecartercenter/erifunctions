# erifunctions

Standardized data tools for the Epidemiology, Research and Innovation
(ERI) team at The Carter Center’s NTD and malaria programs — the way
**Data Analysts** and **Epidemiologists** work with TCC’s Azure-centred
data system across countries (Haiti, DR, Uganda, OEPA, …) and diseases
(malaria, oncho, LF, SCH, STH). You install it, authenticate through
your browser, and call functions — you don’t edit the package.

**Bringing in a monthly country report, a surveillance dataset, or ODK
submissions? Standing up a new country or disease? Run
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md).**
It’s a guided console wizard — pick your country, pick the file (or the
ODK project and form), confirm the month, and it walks the whole
upload/archive → stage → review → approve pipeline for you. It also
scaffolds a brand-new country/disease space (schema template + Azure
folders) when you’re onboarding one for the first time. No function
names to memorize, no Azure path to type by hand.

Not sure where to start otherwise? **[What are you trying to
do?](https://thecartercenter.github.io/erifunctions/articles/task-index.md)**
is a generated index of ~30 common tasks; pick yours and get the call
and the guide. In the console,
[`eri_task_map()`](https://thecartercenter.github.io/erifunctions/reference/eri_task_map.md)
prints the same list. Otherwise, read **[Getting
started](https://thecartercenter.github.io/erifunctions/articles/getting-started.md)**
first — it’s the one idea every guide assumes.

## Two roles, two paths

Data Analyst

Bring surveillance data, CMR reports, and ODK submissions through the
raw → staged → **approved** pipeline, keep the DQ backlog clean, and
turn approved data into reports countries and leadership can use.

1.  [Connect to Azure, ODK, SharePoint &
    Teams](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)
2.  [Onboard a country / disease / data
    type](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md)
3.  [Ingest a surveillance
    dataset](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
4.  [Triage the log
    backlog](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md)

[Paced onboarding path
→](https://thecartercenter.github.io/erifunctions/articles/onboarding.md)

Epidemiologist

Source approved data for a study, reconcile messy free-text places to
admin units, QC an extract for epidemiological sense, and compute the
programme indicators you need for analysis.

1.  [Connect to Azure, ODK, SharePoint &
    Teams](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)
2.  [A complete research
    workflow](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.md)
3.  [Reconcile localities to admin
    units](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.md)
4.  [Catch anomalies before
    analysis](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.md)

[Epi analytics helpers
→](https://thecartercenter.github.io/erifunctions/articles/epi-analytics.md)

## How data moves through the system

Every dataset lives in the `data/` Azure blob under a five-axis path
([ADR-0012](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0012-source-measure-data-model.md)):
`data/{country}/{disease}/{data_source}/{data_type}/{layer}/`. Three
layers, one human gate — nothing reaches `processed/` without a call to
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md).

flowchart TD A\["raw/ - as received"\] --\> B\["run_dq_checks() /
eri_dq_review()"\] B --\> C\["staged/ - DQ-checked, awaiting approval"\]
C --\> D{"eri_approve()"} D --\> E\["processed/ - canonical,
catalog-registered"\]

Run
[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)
once to see the full vocabulary — which `data_source` and `data_type`
values are known, so you never have to guess one.

## Install

``` r

# Install from GitHub
devtools::install_github("thecartercenter/erifunctions")

# Pin the version in your analysis project (recommended)
renv::install("thecartercenter/erifunctions")
renv::snapshot()
```

Azure access is zero-config — the first command that needs it opens your
browser to sign in. See the [connections
guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md)
for ODK, SharePoint, and Teams setup, and the [full reference
index](https://thecartercenter.github.io/erifunctions/reference/index.md)
for every function grouped by what you’re doing when you reach for it.

See the [V2
roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md)
and [architecture decision
records](https://github.com/thecartercenter/erifunctions/tree/main/docs/adr)
for where this is going and the reasoning behind key design choices. For
source, issues, and the full README (installation details, environment
variables, contributing), see the [GitHub
repository](https://github.com/thecartercenter/erifunctions).
