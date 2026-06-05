# Connect to Microsoft Teams via the Graph API

Retrieves a bearer token for sending messages through the Microsoft
Graph API. Checks `ERIFUNCTIONS_TEAMS_TOKEN` first; if absent, attempts
the OAuth device-code flow using the app registered in
`ERIFUNCTIONS_APP_ID`.

## Usage

``` r
get_teams_connection(token = NULL)
```

## Arguments

- token:

  A pre-obtained bearer token string. Returned as-is.

## Value

A bearer token string, or `NULL` with a warning if auth fails.

## Details

On machines where conditional access blocks browser or device-code
flows, use an incoming webhook instead: set `ERIFUNCTIONS_TEAMS_WEBHOOK`
and call
[`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md)
directly without a token.
