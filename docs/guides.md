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

## New here? Do these in order

First run `eri_data_model()` once — it prints the data-addressing vocabulary (channel vs. measure)
the guides assume. Then follow your role's path; dip into the rest as your work needs them.

- **Data Analyst:** [`connections-guide`](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html)
  → [`da-onboard-guide`](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.html)
  → [`da-ingest-guide`](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html)
  → [`da-logs-guide`](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.html).
  Add [`da-cmr-guide`](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html) /
  [`da-odk-guide`](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.html) for those feeds.
- **Epidemiologist:** [`connections-guide`](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html)
  → [`epi-research-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html)
  → [`epi-reconcile-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.html)
  → [`epi-dq-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.html).

## Guides

| Role | Task | Guide | Status |
|------|------|-------|--------|
| Epidemiologist | Run a research study end-to-end (start → version → source data → analyse → tag → resume → handle new data → clean up) | [`epi-research-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-research-guide.html) | ✅ Shipped |
| Data Analyst | Upload & process a monthly country report (CMR) | [`da-cmr-guide`](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html) | ✅ Shipped |
| Data Analyst | Ingest → stage → approve a surveillance dataset | [`da-ingest-guide`](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html) | ✅ Shipped |
| Data Analyst | Work with ODK Central (connect → monitor → manage → pull) | [`da-odk-guide`](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.html) | ✅ Shipped |
| Data Analyst | Onboard a new country / disease / data type | [`da-onboard-guide`](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.html) | ✅ Shipped |
| Data Analyst | Triage the error / DQ log backlog | [`da-logs-guide`](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.html) | ✅ Shipped |
| Epidemiologist | Reconcile free-text localities to admin units for sourcing | [`epi-reconcile-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-reconcile-guide.html) | ✅ Shipped |
| Epidemiologist | Run the DQ pipeline on a new extract | [`epi-dq-guide`](https://thecartercenter.github.io/erifunctions/articles/epi-dq-guide.html) | ✅ Shipped |
| Either | Authenticate and connect to Azure / ODK / SharePoint / Teams | [`connections-guide`](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html) | ✅ Shipped |

## Adding a guide

A new guide is a pkgdown article in `vignettes/` (so it appears on the site under **Workflows**),
following the pattern set by [`epi-research-guide.Rmd`](../vignettes/epi-research-guide.Rmd):

1. A **worked example on safe data** (public sample data, or Azure data the user already has) so
   it runs on any laptop.
2. **Copy-paste chunks read and run in order** — not a single sourced script — so the reader
   learns the steps, not just the outcome.
3. A **clean-up section** that removes anything the walkthrough created.
4. Add the article to `_pkgdown.yml` (`articles:` → Workflows) and flip its row here to ✅.
