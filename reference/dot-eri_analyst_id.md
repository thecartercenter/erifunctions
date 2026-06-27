# Resolve the analyst identity for governed actions and audit logs

Returns `ERI_ANALYST_ID` when set. When it is not, falls back to the
operating system username and warns **once per R session** (via
`options(erifunctions.warned_analyst_id)`) so the analyst knows the
shared audit trail will be stamped with that fallback rather than their
identity.

## Usage

``` r
.eri_analyst_id()
```
