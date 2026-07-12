# Orientation: the data system at a glance

**Desk reference** · ~5 min · needs: n/a · sandbox-safe: n/a

The big picture for a new Data Analyst, the data system, the human-gated
pipeline, and where your tasks live. Read this once before the hands-on
guides; it’s also the basis for a first training session. (For the
step-by-step path, see
[Onboarding](https://thecartercenter.github.io/erifunctions/articles/onboarding.md).)

## What erifunctions is

The ERI team’s R package, the **API to TCC’s Azure data system** across
countries (Haiti, DR, Uganda, OEPA, …) and diseases (malaria, oncho, LF,
SCH, STH). You are a **domain expert**, not a software developer: you
install it and **call functions**, you don’t edit the package. Every
function is built to make *your* work clearer and more reliable.

## The data lives in three layers

    data/{country}/{disease}/{data_source}/{data_type}/
       raw/        as-received from the source
       staged/     DQ-checked, awaiting sign-off
       processed/  analyst-approved, the data the whole team trusts

Data flows **one way**: `raw → staged → processed`. Raw is untouched;
staged is cleaned but provisional; processed is canonical. The direction
never reverses.

## The golden rule

> **Nothing reaches `processed/` without
> [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md),
> the human gate.**

[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
moves staged → processed, writes an approval log, and registers the file
in the catalog. **You are the gate**: nothing is “official” until you
sign off, and the sign-off is stamped with your `ERI_ANALYST_ID`. Never
hand-edit or delete `processed/` data.

## A path has five axes

    data / country / disease / data_source / data_type / layer
            uga      oncho     programmatic  treatment   staged

- **`data_source`** = the **channel** (how it arrives): surveillance ·
  programmatic · research
- **`data_type`** = the **measure** (what it counts): case · aggregate ·
  treatment · mmdp · survey · …

Run
**[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)**
to print the live vocabulary. Channel and measure are **independent**,
the same channel carries different measures, and the same (channel,
disease) differs by country (DR malaria surveillance is `case`; Haiti
malaria surveillance is `aggregate`). A missing combination is *normal*,
it warns, it doesn’t error. The [data-model
card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md)
is the deep reference.

## Which pipeline for which data?

| You received… | Pipeline |
|----|----|
| Monthly CMR Excel | `eri_stage_cmr` → `eri_split_cmr` → `eri_approve` |
| Surveillance extract | `eri_ingest` (or the primitives) → `eri_approve` |
| ODK submissions | `eri_odk_register` → `eri_odk_sync` → clean → `eri_approve` |
| A brand-new space | `eri_onboard_*` first, then one of the above |

Everything ends at
**[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)**
and the catalog. The [cheat
sheet](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.md)
has the full decision tree.

## Your tasks → where they live

- **Load CMR / surveillance** → [CMR
  guide](https://thecartercenter.github.io/erifunctions/articles/da-cmr-guide.md)
  · [ingest
  guide](https://thecartercenter.github.io/erifunctions/articles/da-ingest-guide.md)
- **Process OEPA** → the general pipeline (oncho treatment + prevalence)
- **QC + analytic products + country feedback** → `run_dq_checks` ·
  `dq_report` · `eri_notify_dq`
- **Figures / routine reports** → `eri_table` · `eri_map_*` ·
  `eri_pptx_*` · `eri_report_*`
- **ODK: monitor + pull + backfill** → [ODK
  guide](https://thecartercenter.github.io/erifunctions/articles/da-odk-guide.md)
  · `eri_survey_status` · `eri_odk_upload`
- **Ad-hoc requests** → [ad-hoc
  guide](https://thecartercenter.github.io/erifunctions/articles/da-adhoc-guide.md)
  (`eri_query`)
- **Errors & logs** → [log-triage
  guide](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md)
  (`eri_logs` · `eri_logs_resolve`)

## A boundary worth stating

**Creating ODK forms is *not* an erifunctions task.** Survey **forms are
authored in the ODK Central UI** (XLSForm); erifunctions picks up at
**sync**, it pulls submissions, monitors deployment, and backfills
records. (In R, you don’t *make* a form; you make it in ODK, then the
package takes over.)

## Three golden rules to leave with

1.  **The gate is sacred.** Nothing is real until
    [`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md);
    never touch `processed/` by hand.
2.  **Secrets live only in `.Renviron`**: never in a script, never in
    git. Set `ERI_ANALYST_ID` first.
3.  **Real country data never leaves the system.** Practice on the
    sandbox; protect the real thing.

## Where to learn next

- The [onboarding
  path](https://thecartercenter.github.io/erifunctions/articles/onboarding.md),
  the paced Week-0 → Week-2 track.
- The [cheat
  sheet](https://thecartercenter.github.io/erifunctions/articles/da-cheatsheet.md),
  [data-model
  card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md),
  and [troubleshooting
  card](https://thecartercenter.github.io/erifunctions/articles/troubleshooting.md),
  your desk reference.
- The run-it-live guides in the **Articles** menu, and
  [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)
  as your in-session lookup.
