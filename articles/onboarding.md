# Onboarding a new Data Analyst

**Desk reference** · ~10 min · needs: n/a · sandbox-safe: n/a

This is the **starting page** for a new ERI Data Analyst. It strings the
reference and the run-it-live guides into a paced path with checkpoints,
so onboarding is repeatable and self-serve rather than tribal knowledge.
It ships with the package, so when a guide or function changes, this
path changes with it.

> **Who this is for:** a new DA who can run R scripts and edit code but
> isn’t yet fluent. Every step is copy-paste on **safe sandbox data**,
> you cannot harm real country data by following it.

## How the learning is kept safe

You practice in throwaway namespaces that are designed to be created and
deleted:

- **`atlantis`**: a make-believe country for the ingest/onboard guides.
- **`uga/demo`**: a sandbox country/disease for the ODK pipeline (not
  the real `uga/oncho`).
- **`eri_test_river_prospection` / `eri_test_river_repeat`**: practice
  ODK forms in the ODK `testing` project.

Every guide ends with a **Clean up** section that removes what it
created. Real `processed/` data is never deleted casually, the sandbox
is where you make mistakes.

## Week 0, Setup (before day one)

Get the environment standing so day one is learning, not yak-shaving.
Use the [connections
guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md).

Install **R + RStudio**.

Install the package: `renv` +
`remotes::install_github("thecartercenter/erifunctions")`.

**Azure access granted**, your account needs RBAC on the `data` blob (a
ticket to an ERI admin; this is the long-lead item, start it first).

**ODK Central account** with access to the `testing` project.

`.Renviron` set: `ERI_ANALYST_ID`, `ODK_URL/USER/PASS` (see the
connections guide). **Restart R.**

**Verify:**
`eri_list("", azcontainer = get_azure_storage_connection(storage_name = "data"))`
returns a tibble, and `list_odk_projects(con = init_odk_connection())`
lists projects.

✅ **Gate:** you can connect to Azure and ODK.

## Day 1, Orientation

Read [Getting
started](https://thecartercenter.github.io/erifunctions/articles/getting-started.md)
and the
[Orientation](https://thecartercenter.github.io/erifunctions/articles/orientation.md)
overview.

Run
**[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)**
and read the [data-model
card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md)
until the *channel vs. measure* split makes sense. This is the one idea
everything rests on.

Keep the [DA cheat
sheet](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.md)
open from here on.

✅ **Gate:** you can explain what the five path axes mean and why
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
is the gate.

## Days 2–4, The ingestion spine (do it live)

Work these guides in order, on the sandbox, running every chunk. Stop at
each checkpoint.

[Connections
guide](https://thecartercenter.github.io/erifunctions/articles/connections-guide.md),
connect to all four services.

[Onboard a
space](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md),
stand up a new `atlantis` space (schema + dirs). *Checkpoint: you
scaffolded a space and validated its schema.*

[Ingest a surveillance
dataset](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md),
raw → DQ → staged → **approve**. *Checkpoint: you approved a dataset and
saw it in the catalog.*

[Upload & split a
CMR](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md),
upload → split → approve a monthly CMR. *Checkpoint: you split a CMR per
disease.*

[Work with ODK
Central](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md),
connect → monitor → register → sync → approve. *Checkpoint: you synced
submissions into the pipeline.*

[Triage the log
backlog](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md),
triage and resolve a log. *Checkpoint: you closed an item in the
backlog.*

✅ **Gate:** you can take a file from each of the three channels through
to `processed/` on the sandbox.

## Week 2, Downstream work + shadowing

[Answer an ad-hoc
request](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.md)
with
[`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md).
Other downstream guides (QC + country feedback, routine reporting, final
survey reports) ship as they land, check the [Articles
menu](https://thecartercenter.github.io/erifunctions/articles/) for
what’s available.

**Pair** with a senior DA on a real (but sandboxed) task end-to-end.

Take a **first supervised real task**, a real ingest or QC review,
reviewed before you approve.

Make your **first contribution**: fix a typo or unclear line in a guide
via a PR. This teaches the issue → branch → PR workflow and how the docs
are maintained.

✅ **Gate:** you completed one real task under supervision and opened
one PR.

## Competency checklist (DA + mentor sign off)

A DA is “onboarded” when both of you can tick every box from observed
work, not a quiz:

Connects to Azure + ODK; knows where secrets live and why.

Reads a dataset’s five axes and picks the right `data_source` /
`data_type`.

Ingests + approves a **surveillance** extract (case or aggregate).

Uploads, splits, and approves a **CMR**.

Registers, syncs, and approves an **ODK** form.

Runs
[`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md)
and reads the flags.

Triages the log backlog with
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
/
[`eri_logs_resolve()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs_resolve.md).

Answers an ad-hoc request with
[`eri_query()`](https://thecartercenter.github.io/erifunctions/reference/eri_query.md).

Knows the boundaries: never deletes `processed/`; ODK **forms are
authored in the ODK UI**, the package begins at *sync*; real country
data never leaves the system.

## Staying productive after onboarding

- The [DA cheat
  sheet](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.md)
  and the [troubleshooting
  card](https://thecartercenter.github.io/erifunctions/articles/troubleshooting.md)
  are your desk reference.
- The [Articles
  menu](https://thecartercenter.github.io/erifunctions/articles/) is the
  **“how do I do X?”** lookup, start there, not the function reference.
- Keep a **buddy/mentor** for the first month; questions are faster than
  docs at first.
- When you hit something the guides don’t cover, that’s a gap worth
  filing, open an issue.
