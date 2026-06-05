# Send a message to Microsoft Teams

Sends a plain-text message to a Teams channel or individual. Supports
two delivery paths: an **incoming webhook** (no auth required, channel
only) and the **Graph API** (requires a bearer token, supports DMs and
channels).

## Usage

``` r
eri_teams_send(message, to = NULL, team = NULL, channel = NULL, token = NULL)
```

## Arguments

- message:

  A single character string. The message body.

- to:

  Email or user ID of the recipient for a 1:1 DM. Pass `"self"` or
  `NULL` to message yourself (Graph API only).

- team:

  Display name of the Teams team (for channel messages, Graph API).

- channel:

  Display name of the channel within `team` (Graph API), or ignored when
  using a webhook (the webhook URL already encodes the channel).

- token:

  A Graph API bearer token. If `NULL`, checks
  `ERIFUNCTIONS_TEAMS_TOKEN`; falls back to the incoming webhook if
  `ERIFUNCTIONS_TEAMS_WEBHOOK` is set.

## Value

Invisibly returns the `httr` response object.

## Details

**Delivery routing:**

1.  `team` + `channel` supplied, token available \\\rightarrow\\ Graph
    API channel message.

2.  `to` supplied (or omitted), token available \\\rightarrow\\ Graph
    API DM.

3.  `ERIFUNCTIONS_TEAMS_WEBHOOK` set, no token \\\rightarrow\\ incoming
    webhook.

4.  Otherwise an error is raised with setup instructions.
