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
- **The acting identity was never announced**, and that quietly downgrades the approval gate.
  `eri_approve()` is the human gate: it writes an approval log and registers files in the data
  catalog, resolving the actor through `.eri_analyst_id(azcontainer)`. Under ADR-0003 that prefers
  the *verified* identity decoded from the connection's Azure AD token. A client-credentials token
  carries no `upn` / `preferred_username` / `unique_name` / `email` claim, so
  `.eri_token_identity()` returns `NULL` and the resolution falls through to the self-declared
  `ERI_ANALYST_ID`, or to `"<os-user> (unverified)"`.

  So the log does *not* record the service principal — it records whatever the human declared. The
  harm is subtler and still serious: **ADR-0003's verified-token guarantee silently lapses to the
  spoofable fallback path**, with nothing in the session saying so. The approval log then names a
  human while Azure's own access record names the service principal, and the two disagree about who
  performed the write. The same applies to `eri_spatial_upload()` and every other governed write.

Ambient pickup itself is worth keeping: unattended and CI contexts authenticate by setting those
two variables, with no code change and no interactive prompt. The defect is not that ambient
credentials are consulted, it is that they were consulted *unconditionally*.

## Decision

**Arguments beat ambient environment state.** Two arguments are made binding:

- **`auth`** now defaults to `NULL`, meaning *unspecified*. Ambient SP environment credentials
  apply only when `auth` is `NULL`, or is explicitly `"client_credentials"`.
- **`creds_yaml_path`** is binding the same way. It previously lost to the environment variables
  because `use_sp_env` was evaluated first — the same defect class this ADR exists to fix, in the
  branch immediately below it.

Explicitness is a property of the **value**, not of whether the argument was supplied. We
deliberately do *not* use `missing(auth)`: that would make the behaviour depend on the call
syntax, so a wrapper forwarding `auth = auth` would read as explicit even when its own caller said
nothing, and `do.call()` would differ from a direct call. A `NULL` default also matches the
convention already used by `azcontainer`, `data_con` and `creds_yaml_path`, and lets a forwarding
wrapper preserve ambient pickup simply by defaulting its own `auth` to `NULL`.

**The connection announces the identity it authenticated as** — service principal (naming the
client id) or the signed-in user. When SP credentials are present but overridden by an explicit
`auth`, the override is named in that same line rather than applied silently. This goes through
`.eri_say_info()`, so it honours the existing `eri_verbosity("quiet")` control (ADR-0018). We
considered a dedicated `quiet =` argument and rejected it: it would have created two controls with
one name, where `eri_verbosity("quiet")` did *not* silence this line but `quiet = TRUE` did.

**Governed actions warn when the verified-identity guarantee has lapsed.** Announcing at
connection time is necessary but not sufficient: every internal auto-connect wraps
`get_azure_storage_connection()` in `suppressMessages()` — `eri_approve()` itself does, as do
`.eri_catalog_con()`, `.eri_logs_con()`, `.eri_research_con()`, `.eri_spatial_con()`,
`.eri_artifact_con()`, `.eri_cutover_con()`, `.eri_feedback_con()`, `.eri_template_con()` and
`.onboarding_resolve_con()`. On those paths the identity line never reaches the user, which is
exactly the silence this incident was about.

So `.eri_analyst_id(con)` now warns **once per R session** when a connection is supplied but
`.eri_token_identity(con)` returns `NULL`: the attribution about to be written is self-declared,
not verified. It **warns rather than refuses** — refusing would break unattended pipelines that
legitimately approve as a service principal, and the point is to make the lapse visible, not to
forbid it. `ERI_REQUIRE_ANALYST_ID` remains the opt-in strict mode for teams that do want a hard
stop.

## Consequences

- **Easier:** A DA or maintainer on a machine that happens to carry SP credentials can act as
  themselves — `get_azure_storage_connection(auth = "authorization_code")` — without mutating their
  environment. The acting identity is visible at the point of connection rather than discoverable
  only by inspecting the returned object, and a lapsed verification is visible at the point of the
  governed write however the connection was built.
- **Unchanged:** CI and unattended pipelines that set the two environment variables and pass no
  `auth` behave exactly as before. This is deliberately not a breaking change; internal callers
  such as `.eri_spatial_con()` pass no `auth` and continue to pick up ambient credentials. They now
  emit one warning per session, which is the intended signal.
- **Changed:** `auth`'s default is `NULL` rather than the literal `"authorization_code"`. Anything
  reading `formals(get_azure_storage_connection)$auth` sees `NULL`; the documented *effective*
  default is unchanged.
- Callers that parse connection output will see a new informational line; `eri_verbosity("quiet")`
  restores the previous silence.

**Still open, deliberately.** Whether `ERIFUNCTIONS_SP_CLIENT_ID` / `_SECRET` should ever be
present in an analyst's *interactive* environment is an operational question this ADR does not
settle. If the answer is "CI and `eri-ops` only", the durable fix is operational and this API rule
is the belt rather than the braces.

Regression coverage lives in `tests/testthat/test-dal.R` and mocks `AzureAuth::get_azure_token()`,
`AzureStor::storage_endpoint()` and `AzureStor::storage_container()`, so no test in this group can
reach the live tenant.
