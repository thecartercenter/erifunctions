# Resolve the analyst identity for governed actions and audit logs

When a storage connection is supplied, prefers the **verified** identity
from its Azure AD token
([`.eri_token_identity()`](https://thecartercenter.github.io/erifunctions/reference/dot-eri_token_identity.md),
ADR-0003) — the trustworthy approver. Otherwise (or for
service-principal connections with no user claim) returns
`ERI_ANALYST_ID` when set. When it is not, the behaviour depends on
`ERI_REQUIRE_ANALYST_ID`: if that is truthy (`1`/`true`/`yes`/`on`),
governed actions are **refused** (an error). Otherwise it falls back to
`"<os-username> (unverified)"` — the OS account, explicitly **marked**
so the shared audit trail records the attribution as provisional rather
than as a real analyst id — and warns **once per R session** (via
`options(erifunctions.warned_analyst_id)`).

## Usage

``` r
.eri_analyst_id(con = NULL)
```
