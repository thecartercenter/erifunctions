# Send a DQ result summary to Microsoft Teams

Formats a `dq_result` object into a human-readable summary and sends it
to Teams via
[`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md).

## Usage

``` r
eri_notify_dq(
  result,
  country,
  disease,
  to = NULL,
  team = NULL,
  channel = NULL,
  token = NULL
)
```

## Arguments

- result:

  A `dq_result` object from
  [`run_dq_checks()`](https://thecartercenter.github.io/erifunctions/reference/run_dq_checks.md).

- country:

  Country name used in the message header.

- disease:

  Disease name used in the message header.

- to:

  Passed to
  [`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md).

- team:

  Passed to
  [`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md).

- channel:

  Passed to
  [`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md).

- token:

  Passed to
  [`eri_teams_send()`](https://thecartercenter.github.io/erifunctions/reference/eri_teams_send.md).

## Value

Invisibly returns `result`.
