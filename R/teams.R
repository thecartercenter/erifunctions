# Teams - Microsoft Teams messaging via Graph API or incoming webhooks

#### Private helpers ####

.teams_webhook_url <- function() {
  url <- Sys.getenv("ERIFUNCTIONS_TEAMS_WEBHOOK", unset = "")
  if (nzchar(url)) url else NULL
}

.teams_graph_headers <- function(token) {
  httr::add_headers(
    Authorization = paste("Bearer", token),
    `Content-Type` = "application/json"
  )
}

.teams_send_webhook <- function(message, webhook_url) {
  resp <- httr::POST(
    url    = webhook_url,
    body   = list(text = message),
    encode = "json"
  )
  httr::stop_for_status(resp, task = "send Teams message via webhook")
  invisible(resp)
}

.teams_get_me <- function(token) {
  resp <- httr::GET(
    "https://graph.microsoft.com/v1.0/me",
    .teams_graph_headers(token)
  )
  httr::stop_for_status(resp, task = "get own Teams identity")
  httr::content(resp)$id
}

.teams_lookup_user <- function(email, token) {
  resp <- httr::GET(
    paste0("https://graph.microsoft.com/v1.0/users/", email),
    .teams_graph_headers(token)
  )
  httr::stop_for_status(resp, task = paste("look up Teams user:", email))
  httr::content(resp)$id
}

.teams_find_channel <- function(team_name, channel_name, token) {
  resp <- httr::GET(
    "https://graph.microsoft.com/v1.0/me/joinedTeams",
    .teams_graph_headers(token)
  )
  httr::stop_for_status(resp, task = "list joined Teams")
  teams <- httr::content(resp)$value

  matched <- Filter(
    function(t) tolower(t$displayName) == tolower(team_name),
    teams
  )
  if (length(matched) == 0L) stop("Team not found: ", team_name, call. = FALSE)
  team_id <- matched[[1L]]$id

  resp2 <- httr::GET(
    paste0("https://graph.microsoft.com/v1.0/teams/", team_id, "/channels"),
    .teams_graph_headers(token)
  )
  httr::stop_for_status(resp2, task = "list channels")
  channels <- httr::content(resp2)$value

  matched_ch <- Filter(
    function(c) tolower(c$displayName) == tolower(channel_name),
    channels
  )
  if (length(matched_ch) == 0L) {
    stop("Channel not found: ", channel_name, call. = FALSE)
  }

  list(team_id = team_id, channel_id = matched_ch[[1L]]$id)
}

.teams_send_channel <- function(message, team_name, channel_name, token) {
  ids  <- .teams_find_channel(team_name, channel_name, token)
  url  <- sprintf(
    "https://graph.microsoft.com/v1.0/teams/%s/channels/%s/messages",
    ids$team_id, ids$channel_id
  )
  resp <- httr::POST(
    url,
    .teams_graph_headers(token),
    body   = list(body = list(contentType = "text", content = message)),
    encode = "json"
  )
  httr::stop_for_status(resp, task = "send Teams channel message")
  invisible(resp)
}

.teams_send_dm <- function(message, user_id, token) {
  my_id <- .teams_get_me(token)

  me_bind   <- paste0("https://graph.microsoft.com/v1.0/users('", my_id, "')")
  them_bind <- paste0("https://graph.microsoft.com/v1.0/users('", user_id, "')")

  # createOrGet 1:1 chat
  chat_resp <- httr::POST(
    "https://graph.microsoft.com/v1.0/chats",
    .teams_graph_headers(token),
    body = list(
      chatType = "oneOnOne",
      members  = list(
        list(
          `@odata.type`     = "#microsoft.graph.aadUserConversationMember",
          roles             = list("owner"),
          `user@odata.bind` = me_bind
        ),
        list(
          `@odata.type`     = "#microsoft.graph.aadUserConversationMember",
          roles             = list("owner"),
          `user@odata.bind` = them_bind
        )
      )
    ),
    encode = "json"
  )
  httr::stop_for_status(chat_resp, task = "create Teams chat")
  chat_id <- httr::content(chat_resp)$id

  msg_resp <- httr::POST(
    paste0("https://graph.microsoft.com/v1.0/chats/", chat_id, "/messages"),
    .teams_graph_headers(token),
    body   = list(body = list(contentType = "text", content = message)),
    encode = "json"
  )
  httr::stop_for_status(msg_resp, task = "send Teams DM")
  invisible(msg_resp)
}

#### Public functions ####

#' Connect to Microsoft Teams via the Graph API
#'
#' Retrieves a bearer token for sending messages through the Microsoft Graph
#' API. Checks `ERIFUNCTIONS_TEAMS_TOKEN` first; if absent, attempts the OAuth
#' device-code flow using the app registered in `ERIFUNCTIONS_APP_ID`.
#'
#' On machines where conditional access blocks browser or device-code flows,
#' use an incoming webhook instead: set `ERIFUNCTIONS_TEAMS_WEBHOOK` and call
#' `eri_teams_send()` directly without a token.
#'
#' @param token A pre-obtained bearer token string. Returned as-is.
#'
#' @return A bearer token string, or `NULL` with a warning if auth fails.
#' @export
get_teams_connection <- function(token = NULL) {
  if (!is.null(token)) return(token)

  env_tok <- Sys.getenv("ERIFUNCTIONS_TEAMS_TOKEN", unset = "")
  if (nzchar(env_tok)) return(env_tok)

  app_id <- Sys.getenv("ERIFUNCTIONS_APP_ID", unset = "")
  tenant <- Sys.getenv("ERIFUNCTIONS_TENANT_ID", unset = "common")

  if (!nzchar(app_id)) {
    cli::cli_warn(c(
      "No Teams token or app ID found.",
      "i" = "Set {.envvar ERIFUNCTIONS_TEAMS_TOKEN} (pre-obtained token), or",
      "i" = "Set {.envvar ERIFUNCTIONS_APP_ID} + {.envvar ERIFUNCTIONS_TENANT_ID} for device-code flow.",
      "i" = "Or set {.envvar ERIFUNCTIONS_TEAMS_WEBHOOK} to bypass Graph API entirely."
    ))
    return(NULL)
  }

  base_url <- paste0("https://login.microsoftonline.com/", tenant, "/oauth2/v2.0/")
  endpoint <- httr::oauth_endpoint(
    authorize = paste0(base_url, "authorize"),
    access    = paste0(base_url, "token"),
    device    = paste0(base_url, "devicecode")
  )
  app <- httr::oauth_app("erifunctions", key = app_id, secret = NULL)

  tryCatch({
    tok_obj <- httr::oauth2.0_token(
      endpoint = endpoint,
      app      = app,
      scope    = "Chat.ReadWrite ChannelMessage.Send",
      use_oob  = TRUE
    )
    tok_obj$credentials$access_token
  }, error = function(e) {
    cli::cli_warn(c(
      "Teams Graph API authentication failed: {conditionMessage(e)}",
      "i" = "Set {.envvar ERIFUNCTIONS_TEAMS_WEBHOOK} to use an incoming webhook instead."
    ))
    NULL
  })
}

#' Send a message to Microsoft Teams
#'
#' Sends a plain-text message to a Teams channel or individual. Supports two
#' delivery paths: an **incoming webhook** (no auth required, channel only) and
#' the **Graph API** (requires a bearer token, supports DMs and channels).
#'
#' @param message A single character string. The message body.
#' @param to Email or user ID of the recipient for a 1:1 DM. Pass `"self"` or
#'   `NULL` to message yourself (Graph API only).
#' @param team Display name of the Teams team (for channel messages, Graph API).
#' @param channel Display name of the channel within `team` (Graph API), or
#'   ignored when using a webhook (the webhook URL already encodes the channel).
#' @param token A Graph API bearer token. If `NULL`, checks
#'   `ERIFUNCTIONS_TEAMS_TOKEN`; falls back to the incoming webhook if
#'   `ERIFUNCTIONS_TEAMS_WEBHOOK` is set.
#'
#' @details
#' **Delivery routing:**
#' 1. `team` + `channel` supplied, token available \eqn{\rightarrow} Graph API channel message.
#' 2. `to` supplied (or omitted), token available \eqn{\rightarrow} Graph API DM.
#' 3. `ERIFUNCTIONS_TEAMS_WEBHOOK` set, no token \eqn{\rightarrow} incoming webhook.
#' 4. Otherwise an error is raised with setup instructions.
#'
#' @return Invisibly returns the `httr` response object.
#' @export
eri_teams_send <- function(
    message,
    to      = NULL,
    team    = NULL,
    channel = NULL,
    token   = NULL
) {
  stopifnot(is.character(message), length(message) == 1L)

  webhook <- .teams_webhook_url()
  tok     <- if (!is.null(token)) token else {
    e <- Sys.getenv("ERIFUNCTIONS_TEAMS_TOKEN", unset = "")
    if (nzchar(e)) e else NULL
  }

  # Graph API — channel
  if (!is.null(tok) && !is.null(team) && !is.null(channel)) {
    cli::cli_inform("Sending Teams channel message via Graph API.")
    return(invisible(.teams_send_channel(message, team, channel, tok)))
  }

  # Graph API — DM (or self)
  if (!is.null(tok)) {
    target_id <- if (is.null(to) || identical(to, "self")) {
      .teams_get_me(tok)
    } else {
      .teams_lookup_user(to, tok)
    }
    cli::cli_inform("Sending Teams DM via Graph API.")
    return(invisible(.teams_send_dm(message, target_id, tok)))
  }

  # Incoming webhook
  if (!is.null(webhook)) {
    if (!is.null(to)) {
      cli::cli_warn("Incoming webhooks cannot send DMs; {.arg to} is ignored.")
    }
    cli::cli_inform("Sending Teams message via incoming webhook.")
    return(invisible(.teams_send_webhook(message, webhook)))
  }

  stop(
    "No Teams delivery method configured.\n",
    "  Set ERIFUNCTIONS_TEAMS_WEBHOOK for a channel webhook (simplest), or\n",
    "  Set ERIFUNCTIONS_TEAMS_TOKEN for Graph API access.",
    call. = FALSE
  )
}

#' Send a DQ result summary to Microsoft Teams
#'
#' Formats a `dq_result` object into a human-readable summary and sends it
#' to Teams via `eri_teams_send()`.
#'
#' @param result A `dq_result` object from [run_dq_checks()].
#' @param country Country name used in the message header.
#' @param disease Disease name used in the message header.
#' @param to Passed to `eri_teams_send()`.
#' @param team Passed to `eri_teams_send()`.
#' @param channel Passed to `eri_teams_send()`.
#' @param token Passed to `eri_teams_send()`.
#'
#' @return Invisibly returns `result`.
#' @export
eri_notify_dq <- function(
    result,
    country,
    disease,
    to      = NULL,
    team    = NULL,
    channel = NULL,
    token   = NULL
) {
  stopifnot(inherits(result, "dq_result"))

  n_rows  <- nrow(result$data)
  n_corr  <- nrow(result$log)
  n_flags <- nrow(result$flags)

  top_cols <- if (n_flags > 0L) {
    freq <- sort(table(result$flags$column), decreasing = TRUE)
    paste(utils::head(names(freq), 5L), collapse = ", ")
  } else {
    "none"
  }

  msg <- paste0(
    "[DQ Report] ", toupper(country), " - ", toupper(disease), "\n",
    "Rows processed : ", n_rows,   "\n",
    "Corrections    : ", n_corr,   "\n",
    "Flags          : ", n_flags,  "\n",
    "Top flagged    : ", top_cols
  )

  eri_teams_send(msg, to = to, team = team, channel = channel, token = token)
  invisible(result)
}
