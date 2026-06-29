# Verified actor identity from the connection's Azure AD token

Extracts the authenticated user's identity (`upn` /
`preferred_username`) from the AzureAuth token carried by an interactive
storage connection (ADR-0003). This is the trustworthy approver
identity: unlike `ERI_ANALYST_ID`, it cannot be self-declared. Returns
`NULL` when there is no user claim (a service-principal token) or no
decodable token (a mock / SAS-based container) — callers then fall back
to `ERI_ANALYST_ID`.

## Usage

``` r
.eri_token_identity(con)
```
