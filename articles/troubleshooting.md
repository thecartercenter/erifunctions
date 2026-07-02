# Troubleshooting card

*The errors a DA actually hits, what they mean, and the fix. Then: how
to work the shared error/DQ log backlog with
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md).*

## Common messages → fix

| Message (or symptom) | What it means | Fix |
|----|----|----|
| `403 Forbidden` (Azure) | Your account isn’t granted access to that storage (RBAC). **Not** a code bug. | Ask an ERI admin to add you. |
| `ODK username is required` / `password is required` | `ODK_USER` / `ODK_PASS` not set | Add to `.Renviron`; **restart R**. |
| `… is not a known ERI country` | [`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md) checks a fixed list, `dr/ht/eth/nga/sdn/ssd/uga/mad/tcd` (disease is free text). Note: the general pipeline (`eri_ingest`/`eri_approve`) takes free-text country, so `oepa` etc. work there but not for ODK registration. | Use a listed code; sandbox practice uses a real code + a fake disease (e.g. `uga`/`demo`). |
| `Form … is not in the ODK registry` | You called [`eri_odk_sync()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_sync.md) for an unregistered form | [`eri_odk_register()`](https://thecartercenter.github.io/erifunctions/reference/eri_odk_register.md) it first. |
| `No schema found` / [`load_dq_schema()`](https://thecartercenter.github.io/erifunctions/reference/load_dq_schema.md) can’t resolve | The `{country}_{disease}_{source}_{measure}.yaml` schema doesn’t exist | Check the four axes match a bundled schema; if it’s a new space, author one ([onboarding guide](https://thecartercenter.github.io/erifunctions/articles/da-onboard-guide.md)). |
| `File not found: …` | A local path (CMR Excel, upload CSV) is wrong | Check the path; use an absolute path. |
| Warning: *unknown `data_source`/`data_type`* | The axis value isn’t in the registry | Expected for a new space, it **warns, not errors**. Confirm the spelling, or onboard the new value. |
| `data_type will be "NA"` on approve | You approved without the measure (5th arg) | Pass `data_type = "case"` (etc.) to record the measure in the catalog. |
| Output looks stale after editing `.Renviron` | `.Renviron` is read once at startup | **Restart R** after every `.Renviron` edit. |
| A change to exports/docs isn’t reflected | `NAMESPACE`/`man/` out of date | (Maintainers) re-run `devtools::document()`. |

> **First move on any Azure/ODK error:** confirm you’re connected
> (`eri_list(...)`, `list_odk_projects(con)`) and that `.Renviron` is
> loaded (`Sys.getenv("ERI_ANALYST_ID")`). Most “errors” are an expired
> session or an unset variable.

## Working the log backlog (task: review errors & logs)

Every operation leaves a structured log in Azure.
[`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
is the **shared backlog**, any analyst can see what failed or needs
review and close it out.

``` r

eri_logs(status = "error")                 # the open error backlog (across the tree)
eri_logs(status = "needs_review")          # DQ flags awaiting a human
eri_logs(country = "uga", disease = "lf")  # scope to one dataset (faster)

# Inspect one, fix the underlying issue, then mark it handled:
eri_logs_resolve(log_path, note = "re-ran ingest after fixing the date column")

eri_logs(include_handled = TRUE)           # confirm it's closed
```

- [`eri_logs()`](https://thecartercenter.github.io/erifunctions/reference/eri_logs.md)
  hides handled items by default, the open list shrinks as you resolve.
- Persist a DQ result’s flags yourself with
  `eri_dq_log(result, country, disease, data_source, data_type = )`
  (note: `data_source` is the 4th argument, the measure `data_type` the
  5th, mind the source/measure order).
- Full walkthrough: the [log-triage
  guide](https://thecartercenter.github.io/erifunctions/articles/da-logs-guide.md).
