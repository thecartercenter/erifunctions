<img src="man/figures/logo.png" align="right" height="120" alt="erifunctions logo" />

# erifunctions

Standardized data tools for the Epidemiology, Research and Innovation (ERI) team at The Carter
Center's NTD and malaria programs — the way **Data Analysts** and **Epidemiologists** work with
TCC's Azure-centred data system across countries (Haiti, DR, Uganda, OEPA, …) and diseases
(malaria, oncho, LF, SCH, STH). You install it, authenticate through your browser, and call
functions — you don't edit the package.

Not sure where to start? **[What are you trying to do?](articles/task-index.html)** is a generated
index of ~30 common tasks; pick yours and get the call and the guide. Otherwise, read
**[Getting started](articles/getting-started.html)** first — it's the one idea every guide assumes.

## Two roles, two paths

```{=html}
<div class="row row-cols-1 row-cols-md-2 g-4 my-2">
  <div class="col">
    <div class="card h-100">
      <div class="card-header text-bg-secondary">Data Analyst</div>
      <div class="card-body d-flex flex-column">
        <p class="card-text">
          Bring surveillance data, CMR reports, and ODK submissions through the
          raw &rarr; staged &rarr; <strong>approved</strong> pipeline, keep the DQ backlog clean, and
          turn approved data into reports countries and leadership can use.
        </p>
        <ol class="mb-3">
          <li><a href="articles/connections-guide.html">Connect to Azure, ODK, SharePoint &amp; Teams</a></li>
          <li><a href="articles/da-onboard-guide.html">Onboard a country / disease / data type</a></li>
          <li><a href="articles/da-ingest-guide.html">Ingest a surveillance dataset</a></li>
          <li><a href="articles/da-logs-guide.html">Triage the log backlog</a></li>
        </ol>
        <a href="articles/onboarding.html" class="mt-auto btn btn-outline-secondary btn-sm align-self-start">Paced onboarding path &rarr;</a>
      </div>
    </div>
  </div>
  <div class="col">
    <div class="card h-100">
      <div class="card-header text-bg-secondary">Epidemiologist</div>
      <div class="card-body d-flex flex-column">
        <p class="card-text">
          Source approved data for a study, reconcile messy free-text places to admin units,
          QC an extract for epidemiological sense, and compute the programme indicators you need
          for analysis.
        </p>
        <ol class="mb-3">
          <li><a href="articles/connections-guide.html">Connect to Azure, ODK, SharePoint &amp; Teams</a></li>
          <li><a href="articles/epi-research-guide.html">A complete research workflow</a></li>
          <li><a href="articles/epi-reconcile-guide.html">Reconcile localities to admin units</a></li>
          <li><a href="articles/epi-dq-guide.html">Catch anomalies before analysis</a></li>
        </ol>
        <a href="articles/epi-analytics.html" class="mt-auto btn btn-outline-secondary btn-sm align-self-start">Epi analytics helpers &rarr;</a>
      </div>
    </div>
  </div>
</div>
```

## How data moves through the system

Every dataset lives in the `data/` Azure blob under a five-axis path
([ADR-0012](https://github.com/thecartercenter/erifunctions/blob/main/docs/adr/0012-source-measure-data-model.md)):
`data/{country}/{disease}/{data_source}/{data_type}/{layer}/`. Three layers, one human gate —
nothing reaches `processed/` without a call to `eri_approve()`.

```{=html}
<div class="mermaid">
flowchart TD
    A["raw/ - as received"] --> B["run_dq_checks() / eri_dq_review()"]
    B --> C["staged/ - DQ-checked, awaiting approval"]
    C --> D{"eri_approve()"}
    D --> E["processed/ - canonical, catalog-registered"]
</div>
```

Run `eri_data_model()` once to see the full vocabulary — which `data_source` and `data_type`
values are known, so you never have to guess one.

## Install

```r
install.packages("remotes")
remotes::install_github("thecartercenter/erifunctions")

# Pin the version in your analysis project (recommended)
renv::install("thecartercenter/erifunctions")
renv::snapshot()
```

Azure access is zero-config — the first command that needs it opens your browser to sign in. See
the [connections guide](articles/connections-guide.html) for ODK, SharePoint, and Teams setup, and
the [full reference index](reference/index.html) for every function grouped by what you're doing
when you reach for it.

See the [V2 roadmap](https://github.com/thecartercenter/erifunctions/blob/main/docs/roadmap.md) and
[architecture decision records](https://github.com/thecartercenter/erifunctions/tree/main/docs/adr)
for where this is going and the reasoning behind key design choices. For source, issues, and the
full README (installation details, environment variables, contributing), see the
[GitHub repository](https://github.com/thecartercenter/erifunctions).
