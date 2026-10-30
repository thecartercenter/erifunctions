# Get a user token, signing in again when the cached one has expired

A cached user token stops refreshing once the tenant's
conditional-access sign-in frequency (30 days) has passed: Azure refuses
the refresh (AADSTS70043) and AzureAuth stops instead of signing in
again. For the two interactive flows (`authorization_code`,
`device_code`) this deletes the stale token and retries once, which
opens the browser or shows a sign-in code (#379). Outside an interactive
session it stops instead, so an unattended run fails fast rather than
waiting for a sign-in nobody will do. A missing `httpuv`, which the
browser flow needs, gets a message that says what to do. Any other
error, and any error under another flow, passes through unchanged.

## Usage

``` r
.eri_user_token(tenant_id, app_id, auth, ...)
```

## Arguments

- ...:

  Passed to
  [`AzureAuth::get_azure_token()`](https://rdrr.io/pkg/AzureAuth/man/get_azure_token.html)
  (e.g. `username`, `password` for `resource_owner`).
