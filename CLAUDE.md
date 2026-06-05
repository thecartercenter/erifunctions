# CLAUDE.md — erifunctions working memory

Project memory for anyone (human or AI) developing this package. Read
this first, then the [V2
roadmap](https://thecartercenter.github.io/erifunctions/docs/roadmap.md)
and the [ADRs](https://thecartercenter.github.io/erifunctions/docs/adr/)
for the *why* behind the design.

## What this is

`erifunctions` is the Carter Center ERI team’s R package — the API
through which **Data Analysts (DAs)** and **Epidemiologists (Epis)**
interact with TCC’s Azure-centred data system across countries (Haiti,
DR, Uganda, OEPA) and diseases (malaria, oncho, LF, SCH, STH). Users are
domain experts, **not software developers**: they install with
`install_github()` / `renv`, authenticate via interactive browser auth,
and call functions — they do not edit the package. Optimise every change
for *their* clarity and reliability.

## Core model

Data lives in the `data/` Azure blob under a canonical path built by
[`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md):

    data/{country}/{disease}/{data_type}/{layer}/
      raw/        as-received from source
      staged/     DQ-checked, awaiting approval
      processed/  analyst-approved, canonical

- **[`eri_approve()`](https://thecartercenter.github.io/erifunctions/reference/eri_approve.md)
  is the human gate.** Nothing reaches `processed/` without it; it
  writes an approval log and registers the file in the data catalog
  (`_catalog/data_catalog.yaml`).
- The `projects/` blob is the legacy contractor (hsp-mal) space; V2 is
  migrating authority to `data/` (see roadmap Phase 3).
- Metadata stores (catalog, ODK registry, artifact registry) are YAML
  blobs — see ADR-0002 for the concurrency rules when touching them.

## Conventions

- **Naming:** exported functions are `eri_*` (or domain verbs like
  `run_dq_checks`); internal helpers are `.eri_*` and
  `@keywords internal`, not exported.
- **Style:** `cli::cli_*` for all user-facing messages; roxygen2 with
  markdown; functions get `@examples` (wrap live Azure/ODK calls in
  `\dontrun{}`).
- **Source layout:** one domain per file in `R/` (`dal.R`, `dq.R`,
  `catalog.R`, `odk*.R`, `research.R`, `reports*.R`, `spatial.R`,
  `epi*.R`, `onboarding.R`, …).
- **Schemas** are bundled YAML under `inst/schemas/`; **templates**
  under `inst/templates/`.
- After changing exports or roxygen, regenerate `NAMESPACE`/`man/` with
  `devtools::document()`.

## Guardrail: global vs local solutions

This codebase grew through project-driven development, which scattered
local fixes for global problems. Before adding a function or pattern:

1.  **Search for an existing helper first** — reuse
    [`azure_io()`](https://thecartercenter.github.io/erifunctions/reference/azure_io.md)
    /
    [`eri_read()`](https://thecartercenter.github.io/erifunctions/reference/eri_read.md)
    /
    [`eri_write()`](https://thecartercenter.github.io/erifunctions/reference/eri_write.md)
    /
    [`eri_data_path()`](https://thecartercenter.github.io/erifunctions/reference/eri_data_path.md)
    and the DQ/catalog/research machinery rather than re-implementing.
2.  If a problem is general (other countries/diseases/users would hit
    it), solve it generally and put the decision in an **ADR** — don’t
    bury a one-off in a single workflow.
3.  Keep the roadmap and ADRs current: if a change alters the plan or a
    decision, update `docs/roadmap.md` / add an ADR in the same PR.

## Before opening a PR

- `devtools::document()` if exports/docs changed; `devtools::check()`
  should pass clean.
- `devtools::test()` — unit tests run offline; live integration tests in
  `tests/testthat/test-smoke.R` run only when
  `Sys.setenv(ERI_SMOKE_TESTS = "true")`.
- Update `NEWS.md` under the current phase heading and bump
  `DESCRIPTION` `Version` if shipping.
- Note: the cloud dev container has **no local R/quarto** —
  `R CMD check` and
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
  are verified in GitHub Actions CI, not locally.
