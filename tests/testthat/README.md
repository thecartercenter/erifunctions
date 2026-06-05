# Test suite

## Unit tests

Run automatically in CI and locally via `devtools::test()`. All Azure and ODK
calls are mocked — no real infrastructure required.

## Smoke tests (`test-smoke.R`)

Live integration tests against real Azure and ODK Central infrastructure.
**Skipped in CI** and in any session where `ERI_SMOKE_TESTS` is not set.

### How to run

1. Ensure all environment variables are set in your project `.Renviron`:

   ```
   ERIFUNCTIONS_TENANT_ID=...
   ERIFUNCTIONS_APP_ID=...
   ERIFUNCTIONS_RESOURCE_ENDPOINT=...
   ERIFUNCTIONS_DATA_STORAGE_NAME=data
   ERI_ANALYST_ID=firstname.lastname
   ODK_URL=...
   ODK_USER=...
   ODK_PASS=...
   ```

2. Enable smoke tests and run:

   ```r
   Sys.setenv(ERI_SMOKE_TESTS = "true")
   devtools::test(filter = "smoke")
   ```

### What they cover

| Block | User type | What is tested |
|---|---|---|
| 1 | **Data analyst (primary)** | Azure connection, path building, file listing, DQ schema + checks, CMR schema, anomaly detection, catalog query, ODK connection, survey status, form register/deregister |
| 2 | **Data analyst — spatial** | `eri_spatial_load`, `eri_spatial_join` |
| 3 | **Data analyst — epi analytics** | `eri_incidence_rate`, `eri_epidemic_curve` |
| 4 | **Data analyst — reporting** | `eri_table`, `eri_report_excel`, `eri_pptx_create`/`save` |
| 5 | Epidemiologist (secondary) | Artifact upload → list → pull → archive; research project init, log, list in Azure |

### Cleanup

All write operations use timestamped names or a `_smoke_test/` prefix.
Each block registers a `withr::defer` cleanup so artifacts are removed even if
the test fails.
