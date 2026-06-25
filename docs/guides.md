# Task guides — who does what, and where the guide is

> **Status:** living index. Add a row whenever a new task guide ships; flip its status when it lands.

The [grouped function reference](https://thecartercenter.github.io/erifunctions/reference/)
answers *"what does this function do?"*. These **task guides** answer the more useful question for
a domain expert: *"I need to do X — show me the steps for my exact job."*

The framework is one short, worked guide **per user role × task** — a Data Analyst running a
monthly country report, an Epidemiologist running a study, someone onboarding a new country, and
so on. Each guide is a copy-pasteable walkthrough on safe example data that a user can run
end-to-end on their own laptop. They complement (do not replace) the reference and the role
vignettes (ADR-0001).

This page is the **menu and the backlog**: what exists today, and what is still missing.

## Guides

| Role | Task | Guide | Status |
|------|------|-------|--------|
| Epidemiologist | Run a research study end-to-end (start → version → source data → analyse → tag → resume → handle new data → clean up) | [`epi-research-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html) | ✅ Shipped |
| Data Analyst | Run a monthly country report | _planned_ | ⬜ Missing |
| Data Analyst | Ingest → stage → approve a surveillance dataset | [`da-ingest-guide`](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html) | ✅ Shipped |
| Data Analyst | Onboard a new country / disease / data type | _planned_ | ⬜ Missing |
| Data Analyst | Triage the error / DQ log backlog | _planned_ | ⬜ Missing (function gap — Phase 5 `eri_logs()`) |
| Epidemiologist | Reconcile free-text localities to admin units for sourcing | _planned_ (see the [spatial workflow](https://thecartercenter.github.io/erifunctions/articles/spatial-workflow.html) vignette for now) | ⬜ Missing |
| Epidemiologist | Run the DQ pipeline on a new extract | _planned_ (see the [DQ pipeline](https://thecartercenter.github.io/erifunctions/articles/dq-pipeline.html) vignette for now) | ⬜ Missing |
| Either | Authenticate and connect to Azure / ODK / SharePoint | _planned_ | ⬜ Missing |

## Adding a guide

A new guide is a pkgdown article in `vignettes/` (so it appears on the site under **Workflows**),
following the pattern set by [`epi-research-guide.Rmd`](../vignettes/epi-research-guide.Rmd):

1. A **worked example on safe data** (public sample data, or Azure data the user already has) so
   it runs on any laptop.
2. **Copy-paste chunks read and run in order** — not a single sourced script — so the reader
   learns the steps, not just the outcome.
3. A **clean-up section** that removes anything the walkthrough created.
4. Add the article to `_pkgdown.yml` (`articles:` → Workflows) and flip its row here to ✅.
