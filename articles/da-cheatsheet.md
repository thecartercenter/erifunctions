# Data Analyst cheat sheet

**Desk reference** · ~5 min · needs: n/a · sandbox-safe: n/a

*One page. The functions you actually use, the path model, and which
pipeline to reach for. Pair with [the data-model
card](https://thecartercenter.github.io/erifunctions/articles/data-model-card.md)
for the channel-vs-measure decision, and the role guides when you want
the full walkthrough.*

## The data system in one picture

Everything lives in the Azure **`data/`** blob under a canonical 5-axis
path. Build it with
[`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md):
never hand-type it.

    data/ {country} / {disease} / {data_source} / {data_type} / {layer} / file
            dr         malaria     surveillance    case          raw        as-received
            uga        oncho       programmatic    treatment     staged     DQ-checked, awaiting sign-off
            ht         lf          research        prevalence    processed  approved, the team trusts this

- **`data_source` = the channel** (how the data arrives): `surveillance`
  · `programmatic` · `research`.
- **`data_type` = the measure** (what it counts): `case` · `aggregate` ·
  `treatment` · `mmdp` · `training` · `survey` · `tas` · `prevalence` ·
  `entomology`.
- Run
  **[`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md)**
  once to print the full, current vocabulary. Unknown values *warn, not
  error*, a new country/disease/source/measure is a normal gap, not a
  bug.

> **The golden rule:** nothing reaches **`processed/`** without
> **[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)**,
> the human gate. It moves staged → processed, writes an approval log,
> and registers the file in the catalog. Never hand-edit or delete
> `processed/` data.

## Which pipeline do I use?

**Run
[`eri_do()`](https://thecartercenter.github.io/erifunctions/reference/eri_do.md)**
and pick from its menu (CMR / surveillance ingest / ODK / onboard a new
space / review something staged) – it picks the right functions and
calls them for you, in order, so you don’t have to hold this decision
tree in your head (see the [eri_do()
tour](https://thecartercenter.github.io/erifunctions/articles/da-do-guide.md)).
The table below is for when you’re scripting the steps yourself, not
deciding which pipeline to reach for.

**The general primitive pipeline** (works on any data, incl. the
practice sandbox):

``` r

raw    <- eri_read(eri_data_path(c, d, src, mea, "raw", file), azcontainer = data_con)
schema <- load_dq_schema(c, d, src, mea)            # bundled YAML under inst/schemas/
res    <- run_dq_checks(raw, schema); dq_report(res)
eri_write(res$data, eri_data_path(c, d, src, mea, "staged", file), azcontainer = data_con)
eri_approve(c, d, src, period, data_type = mea, azcontainer = data_con)   # the gate
```

## The ~15 functions a DA actually uses

| Need | Function | Canonical call |
|----|----|----|
| Connect to data | `get_azure_storage_connection` | `get_azure_storage_connection(storage_name = "data")` |
| Connect to ODK | `init_odk_connection` | [`init_odk_connection()`](https://thecartercenter.github.io/erifunctions/reference/init_odk_connection.md) (creds in `.Renviron`) |
| Build a path | `eri_data_path` | `eri_data_path(country, disease, source, measure, layer, file)` |
| See the vocabulary | `eri_data_model` | [`eri_data_model()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_model.md) |
| List / read / write | `eri_list` · `eri_read` · `eri_write` | `eri_read(path, azcontainer = data_con)` |
| Ingest surveillance | `eri_ingest` | `eri_ingest(path, country, disease, data_source, data_type)` |
| Stage a CMR | `eri_stage_cmr` | `eri_stage_cmr(country, period)` |
| Split a CMR per disease | `eri_split_cmr` | `eri_split_cmr(path, country)` |
| DQ a dataset | `load_dq_schema` + `run_dq_checks` + `dq_report` | `run_dq_checks(data, schema)` |
| **Approve (the gate)** | `eri_approve` | `eri_approve(country, disease, data_source, period, data_type =)` |
| Find approved data | `eri_catalog_query` | `eri_catalog_query(country =, disease =)` |
| Query across datasets | `eri_query` | `eri_query(sql, disease =, data_type =)` |
| Register an ODK form | `eri_odk_register` | `eri_odk_register(project_id, form_id, country, disease, server_url, data_con)` |
| Pull ODK submissions | `eri_odk_sync` | `eri_odk_sync(project_id, form_id, con, data_con)` |
| Backfill ODK from a table | `eri_odk_upload` | `eri_odk_upload(data, project_id, form_id, key_col =)` |
| Monitor a survey | `eri_survey_status` | `eri_survey_status(project_id, form_id, con)` |
| Triage errors / DQ backlog | `eri_logs` · `eri_logs_resolve` | `eri_logs(status = "error")` → `eri_logs_resolve(log_path, note =)` |

*Signatures to mind:* `eri_onboard_disease(disease, country, …)` takes
**disease first** (unlike the others);
[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)’s
**5th arg is `data_type`** (the measure), omit it and the catalog
records the measure as `NA`.

## Quick analytics (for initial epi QC products)

``` r

eri_case_summary(data, group_cols, date_col =, count_col =)   # counts by group/period
eri_incidence_rate(cases, pop, multiplier = 1000)             # rate per 1,000
eri_epidemic_curve(data, date_col, count_col =, period = "week")
# disease helpers: eri_lf_tas_summary(), eri_oncho_program_levels(), eri_lf_pooled_prev() …
```

## Don’t reinvent, search first

Before writing new code, reuse
[`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)
/
[`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
/
[`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md)
/
[`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)
and the DQ / catalog / logs machinery. If a problem is general, it
probably already has a helper (and if it truly doesn’t, that’s an
ADR-worthy decision, not a one-off script).
