# ADR-0028 — An explicitly supplied `auth` outranks ambient service principal credentials

- **Status:** Accepted
- **Date:** 2026-08-29

## Context

`get_azure_storage_connection()` (`R/dal.R`) resolves the acting identity through three branches,
in order:

1. `ERIFUNCTIONS_SP_CLIENT_ID` + `ERIFUNCTIONS_SP_CLIENT_SECRET` in the environment →
   `client_credentials`
2. an explicit `creds_yaml_path` → `client_credentials`
3. everything else → `auth`, whose documented default is `"authorization_code"`

Branch 1 never consulted `auth`. So whenever those two environment variables were set, passing
`auth = "authorization_code"` explicitly **did nothing** — the caller silently received a service
principal token instead. The only way to authenticate as yourself was to delete the environment
variables, which is not a supported operation on an argument you already passed.

This surfaced in a live session on 2026-08-29: a maintainer with SP credentials set in their R
session called `get_azure_storage_connection(storage_name = "data")` and only discovered they were
acting as the service principal by printing the returned container and reading
`Authentication method: client_credentials`. Nothing in the call announced it.

Two things are wrong here, and they compound:

- **An explicit argument was overridden by ambient environment state.** That inverts the normal
  precedence in this package, where arguments beat environment variables beat baked-in defaults.
- **The acting identity was never announced.** `eri_approve()` is the human gate: it writes an
  approval log and registers files in the data catalog. If the caller is silently the service
  principal rather than the human, the approval gate records the wrong actor and stops being
  attributable — the governance property the gate exists to provide. The same applies to
  `eri_spatial_upload()` and every other write.

Ambient pickup itself is worth keeping: unattended and CI contexts authenticate by setting those
two variables, with no code change and no interactive prompt. The defect is not that ambient
credentials are consulted, it is that they were consulted *unconditionally*.

## Decision

**An explicitly supplied `auth` is binding.** Ambient SP environment credentials are used only when
the caller left `auth` at its default (detected with `missing(auth)`), or explicitly asked for
`"client_credentials"`.

**The connection always announces the identity it authenticated as** — service principal (naming
the client id) or interactive user — via `cli::cli_alert_info()`. A new `quiet = FALSE` argument
suppresses it for callers that connect in a loop.

When SP credentials are present but overridden by an explicit `auth`, the override is stated
rather than applied silently.

## Consequences

- **Easier:** A DA or maintainer on a machine that happens to carry SP credentials can act as
  themselves — `get_azure_storage_connection(auth = "authorization_code")` — without mutating their
  environment. The acting identity is visible at the point of connection rather than discoverable
  only by inspecting the returned object.
- **Unchanged:** CI and unattended pipelines that set the two environment variables and call with no
  `auth` argument behave exactly as before. This is deliberately not a breaking change; internal
  callers such as `.eri_spatial_con()` pass no `auth` and so continue to pick up ambient
  credentials.
- **Harder:** `missing(auth)` makes the behaviour depend on whether an argument was *supplied*, not
  only on its value. A wrapper that forwards `auth = auth` unconditionally will be treated as
  explicit even when its own caller said nothing. Wrappers that want to preserve ambient pickup must
  omit the argument rather than forward a default.
- Callers that parse connection output will see a new informational line; `quiet = TRUE` restores
  the previous silence.

Regression coverage lives in `tests/testthat/test-dal.R` and mocks `AzureAuth::get_azure_token()`,
`AzureStor::storage_endpoint()` and `AzureStor::storage_container()`, so no test in this group can
reach the live tenant.
