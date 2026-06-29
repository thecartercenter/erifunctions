# Onboarding a new Data Analyst

This is the **starting URL** for a new ERI Data Analyst. It strings the reference and the run-it-live
guides into a paced path with checkpoints, so onboarding is repeatable and self-serve rather than
tribal knowledge. It lives in the repo so it versions with the package — when a guide or function
changes, this path changes with it.

> **Who this is for:** a new DA who can run R scripts and edit code but isn't yet fluent. Every step is
> copy-paste on **safe sandbox data** — you cannot harm real country data by following it.

## How the learning is kept safe

You practice in throwaway namespaces that are designed to be created and deleted:

- **`atlantis`** — a make-believe country for the ingest/onboard guides.
- **`uga/demo`** — a sandbox country/disease for the ODK pipeline (not the real `uga/oncho`).
- **`eri_test_river_prospection` / `eri_test_river_repeat`** — practice ODK forms in the ODK `testing`
  project.

Every guide ends with a **Clean up** section that removes what it created. Real `processed/` data is
never deleted casually — the sandbox is where you make mistakes.

---

## Week 0 — Setup (before day one)

Get the environment standing so day one is learning, not yak-shaving. Use the
[connections card](training/connections-card.md).

- [ ] Install **R + RStudio**.
- [ ] Install the package: `renv` + `remotes::install_github("thecartercenter/erifunctions")`.
- [ ] **Azure access granted** — your account needs RBAC on the `data` blob (a ticket to an ERI admin;
      this is the long-lead item — start it first).
- [ ] **ODK Central account** with access to the `testing` project.
- [ ] `.Renviron` set: `ERI_ANALYST_ID`, `ODK_URL/USER/PASS` (see the connections card). **Restart R.**
- [ ] **Verify:** `eri_list("", azcontainer = get_azure_storage_connection("data"))` returns a tibble,
      and `list_odk_projects(con = init_odk_connection())` lists projects.

✅ **Gate:** you can connect to Azure and ODK.

## Day 1 — Orientation

- [ ] Read [`getting-started`](https://thecartercenter.github.io/erifunctions/articles/getting-started.html).
- [ ] Run **`eri_data_model()`** and read the [data-model card](training/data-model-card.md) until the
      *channel vs. measure* split makes sense. This is the one idea everything rests on.
- [ ] Skim the orientation deck (`training/orientation-deck.qmd`) for the big picture: the Azure
      three-layer + 5-axis system, the human-gated pipeline, and where your 11 tasks live.
- [ ] Keep the [DA cheat sheet](training/da-cheatsheet.md) open from here on.

✅ **Gate:** you can explain what the five path axes mean and why `eri_approve()` is the gate.

## Days 2–4 — The ingestion spine (do it live)

Work these guides in order, on the sandbox, running every chunk. Stop at each checkpoint.

- [ ] [`connections-guide`](https://thecartercenter.github.io/erifunctions/articles/connections-guide.html)
      — connect to all four services.
- [ ] [`da-onboard-guide`](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.html)
      — stand up a new `atlantis` space (schema + dirs). *Checkpoint: you scaffolded a space and
      validated its schema.*
- [ ] [`da-ingest-guide`](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.html)
      — raw → DQ → staged → **approve** a surveillance extract. *Checkpoint: you approved a dataset and
      saw it in the catalog.*
- [ ] [`da-cmr-guide`](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.html)
      — upload → split → approve a monthly CMR. *Checkpoint: you split a CMR per disease.*
- [ ] [`da-odk-guide`](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.html)
      — connect → monitor → register → sync → approve an ODK form. *Checkpoint: you synced submissions
      into the pipeline.*
- [ ] [`da-logs-guide`](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.html)
      — triage and resolve a log. *Checkpoint: you closed an item in the backlog.*

✅ **Gate:** you can take a file from each of the three channels through to `processed/` on the sandbox.

## Week 2 — Downstream work + shadowing

The downstream guides (QC + country feedback, routine reporting, final survey reports, ad-hoc requests)
ship as they land — check the [guide index](guides.md) for what's available. Then:

- [ ] **Pair** with a senior DA on a real (but sandboxed) task end-to-end.
- [ ] Take a **first supervised real task** — a real ingest or QC review, reviewed before you approve.
- [ ] Make your **first contribution**: fix a typo or unclear line in a guide via a PR. This teaches the
      issue → branch → PR workflow and how the docs are maintained.

✅ **Gate:** you completed one real task under supervision and opened one PR.

---

## Competency checklist (DA + mentor sign off)

A DA is "onboarded" when both of you can tick every box from observed work, not a quiz:

- [ ] Connects to Azure + ODK; knows where secrets live and why.
- [ ] Reads a dataset's five axes and picks the right `data_source` / `data_type`.
- [ ] Ingests + approves a **surveillance** extract (case or aggregate).
- [ ] Uploads, splits, and approves a **CMR**.
- [ ] Registers, syncs, and approves an **ODK** form.
- [ ] Runs `run_dq_checks()` and reads the flags.
- [ ] Triages the log backlog with `eri_logs()` / `eri_logs_resolve()`.
- [ ] Produces one routine figure/table for an output.
- [ ] Knows the boundaries: never deletes `processed/`; ODK **forms are authored in the ODK UI**, the
      package begins at *sync*; real country data never leaves the system.

## Staying productive after onboarding

- The [DA cheat sheet](training/da-cheatsheet.md) and the cards are your desk reference.
- The [guide index](guides.md) is the **"how do I do X?"** lookup — start there, not the function
  reference.
- Keep a **buddy/mentor** for the first month; questions are faster than docs at first.
- When you hit something the guides don't cover, that's a gap worth filing — open an issue.
