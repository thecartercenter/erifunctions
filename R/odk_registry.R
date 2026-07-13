#### ODK form registry — Azure-backed YAML ####

.KNOWN_COUNTRY_CODES <- c(
  "dr", "ht", "eth", "nga", "sdn", "ssd", "uga", "mad", "tcd"
)

.ODK_REGISTRY_PATH <- "odk/registry.yaml"

# Read registry from Azure; returns list with $forms element (may be empty).
#' @keywords internal
.odk_registry_read <- function(data_con) {
  if (!AzureStor::storage_file_exists(data_con, .ODK_REGISTRY_PATH)) {
    return(list(forms = list()))
  }
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  .eri_blob_read(data_con, .ODK_REGISTRY_PATH, tmp)
  reg <- yaml::read_yaml(tmp)
  if (is.null(reg$forms)) reg$forms <- list()
  reg
}

# All registry writes now go through `.eri_yaml_update()` (ADR-0002); there is no
# unconditional whole-file writer left to reintroduce the lost-update race.

# Return the data/ blob container, either from the passed object or env vars.
#' @keywords internal
.odk_data_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  # Delegate to the shared connector so auto-connect inherits the zero-config
  # interactive-auth defaults (app_id / tenant_id / resource_endpoint). Building
  # the token here from bare `Sys.getenv()` reads — as this once did — sent an
  # empty `client_id` when those vars were unset, failing with AADSTS900144.
  # Mirrors `.eri_research_con()` / `.eri_logs_con()` / `.eri_catalog_con()`.
  suppressMessages(
    get_azure_storage_connection(
      storage_name = Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
    )
  )
}

#### eri_odk_register ####

#' Register an ODK form in the shared Azure registry
#'
#' Appends a new entry to `odk/registry.yaml` in the `data/` Azure blob.
#' Errors if the `(server_url, project_id, form_id)` triple is already active.
#'
#' @param project_id `int` ODK Central project ID.
#' @param form_id `str` ODK Central form ID (xmlFormId).
#' @param country `str` Country code (e.g. `"uga"`). Must be a known ERI country.
#' @param disease `str` Disease name (e.g. `"oncho"`).
#' @param server_url `str` ODK Central server URL (e.g. `"https://odk.example.org"`).
#' @param form_display_name `str` or `NULL` Human-readable form name. Defaults to `form_id`.
#' @param con `odk_connection` or `NULL` ODK connection from [init_odk_connection()].
#'   Not used for registry writes, but included for consistency with other ODK functions.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The new registry entry (invisibly).
#' @examples
#' \dontrun{
#' eri_odk_register(
#'   project_id = 7, form_id = "RiverProspection",
#'   country = "uga", disease = "oncho",
#'   server_url = "https://odk.example.org"
#' )
#' }
#' @family ODK Central functions
#' @export
eri_odk_register <- function(
    project_id,
    form_id,
    country,
    disease,
    server_url,
    form_display_name = NULL,
    con       = NULL,
    data_con  = NULL
) {
  if (!country %in% .KNOWN_COUNTRY_CODES) {
    known <- .KNOWN_COUNTRY_CODES
    cli::cli_abort(c(
      "{.arg country} {.val {country}} is not a known ERI country code.",
      "i" = "Valid codes: {.val {known}}"
    ))
  }

  data_con  <- .odk_data_con(data_con)
  analyst   <- .eri_analyst_id(data_con)
  reg       <- .odk_registry_read(data_con)

  # Advisory pre-read duplicate check: gives a fast, clear error before we build
  # the entry. The *authoritative* check is re-run inside the `.eri_yaml_update()`
  # mutate below against the freshly-read registry (ADR-0002) — keep both.
  is_dup <- vapply(reg$forms, function(f) {
    isTRUE(f$active) &&
      identical(f$server_url, server_url) &&
      identical(as.integer(f$project_id), as.integer(project_id)) &&
      identical(f$form_id, form_id)
  }, logical(1L))

  if (any(is_dup)) {
    cli::cli_abort(c(
      "Form is already registered and active.",
      "i" = "server_url: {.val {server_url}}",
      "i" = "project_id: {.val {project_id}}",
      "i" = "form_id:    {.val {form_id}}"
    ))
  }

  entry <- list(
    server_url        = server_url,
    project_id        = as.integer(project_id),
    form_id           = form_id,
    form_display_name = if (!is.null(form_display_name)) form_display_name else form_id,
    country           = country,
    disease           = disease,
    active            = TRUE,
    added_by          = analyst,
    added_at          = format(Sys.Date(), "%Y-%m-%d"),
    last_synced       = NULL,
    last_cursor       = NULL
  )

  # Concurrency-safe append (ADR-0002): the duplicate check is re-run inside the
  # mutate against the freshly-read registry so a racing registration of the same
  # form can't slip through, and a racing registration of a *different* form
  # isn't clobbered.
  .eri_yaml_update(data_con, .ODK_REGISTRY_PATH, function(reg) {
    if (is.null(reg$forms)) reg$forms <- list()
    dup <- vapply(reg$forms, function(f) {
      isTRUE(f$active) &&
        identical(f$server_url, server_url) &&
        identical(as.integer(f$project_id), as.integer(project_id)) &&
        identical(f$form_id, form_id)
    }, logical(1L))
    if (any(dup)) {
      cli::cli_abort(c(
        "Form is already registered and active.",
        "i" = "server_url: {.val {server_url}}",
        "i" = "project_id: {.val {project_id}}",
        "i" = "form_id:    {.val {form_id}}"
      ))
    }
    reg$forms <- c(reg$forms, list(entry))
    reg
  }, default = list(forms = list()))

  op_log <- list(
    operation    = "eri_odk_register",
    analyst      = analyst,
    timestamp    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters   = list(
      server_url = server_url,
      project_id = as.integer(project_id),
      form_id    = form_id,
      country    = country,
      disease    = disease
    ),
    status = "success"
  )
  .eri_write_log(op_log, data_con, "logs/_access")

  cli::cli_alert_success(
    "Registered {.val {form_id}} ({country}/{disease}) on {.url {server_url}}."
  )
  invisible(entry)
}

#### eri_odk_deregister ####

#' Deregister an ODK form from the shared Azure registry
#'
#' Soft-deletes by setting `active: false` on the matching entry.
#' Sync history (`last_synced`, `last_cursor`) is preserved.
#'
#' @param project_id `int` ODK Central project ID.
#' @param form_id `str` ODK Central form ID (xmlFormId).
#' @param server_url `str` or `NULL` ODK Central server URL. If `NULL`, matches on
#'   `project_id` and `form_id` alone (errors if ambiguous).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns The updated entry (invisibly).
#' @examples
#' \dontrun{
#' eri_odk_deregister(project_id = 7, form_id = "RiverProspection")
#' }
#' @family ODK Central functions
#' @export
eri_odk_deregister <- function(
    project_id,
    form_id,
    server_url = NULL,
    data_con   = NULL
) {
  data_con <- .odk_data_con(data_con)
  analyst  <- .eri_analyst_id(data_con)
  reg      <- .odk_registry_read(data_con)

  idx <- which(vapply(reg$forms, function(f) {
    isTRUE(f$active) &&
      identical(as.integer(f$project_id), as.integer(project_id)) &&
      identical(f$form_id, form_id) &&
      (is.null(server_url) || identical(f$server_url, server_url))
  }, logical(1L)))

  if (length(idx) == 0L) {
    cli::cli_abort(c(
      "No active registered form found.",
      "i" = "project_id: {.val {project_id}}",
      "i" = "form_id:    {.val {form_id}}"
    ))
  }

  if (length(idx) > 1L) {
    urls <- vapply(reg$forms[idx], `[[`, character(1L), "server_url")
    cli::cli_abort(c(
      "Multiple active entries match; supply {.arg server_url} to disambiguate.",
      "i" = "Matching server URLs: {.val {urls}}"
    ))
  }

  # Concurrency-safe soft-delete (ADR-0002): re-find the entry on the freshly-read
  # registry so a concurrent change to another form isn't lost.
  deregistered <- NULL
  .eri_yaml_update(data_con, .ODK_REGISTRY_PATH, function(reg) {
    if (is.null(reg$forms)) reg$forms <- list()
    hit <- which(vapply(reg$forms, function(f) {
      isTRUE(f$active) &&
        identical(as.integer(f$project_id), as.integer(project_id)) &&
        identical(f$form_id, form_id) &&
        (is.null(server_url) || identical(f$server_url, server_url))
    }, logical(1L)))
    if (length(hit) > 0L) {
      reg$forms[[hit[[1L]]]]$active <- FALSE
      deregistered <<- reg$forms[[hit[[1L]]]]
    }
    reg
  }, default = list(forms = list()))

  # If a concurrent writer already deactivated/removed it between our pre-read and
  # the committed mutate, fall back to the pre-read entry but reflect the intended
  # post-state (active = FALSE) so the returned value isn't misleadingly "active".
  if (is.null(deregistered)) {
    deregistered <- reg$forms[[idx]]
    deregistered$active <- FALSE
  }

  op_log <- list(
    operation  = "eri_odk_deregister",
    analyst    = analyst,
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(
      project_id = as.integer(project_id),
      form_id    = form_id,
      server_url = server_url
    ),
    status = "success"
  )
  .eri_write_log(op_log, data_con, "logs/_access")

  cli::cli_alert_success("Deregistered {.val {form_id}} (project {project_id}).")
  invisible(deregistered)
}

#### eri_odk_purge ####

#' Permanently remove an ODK form from the shared Azure registry
#'
#' **Hard-deletes** every matching registry entry — active *or* already
#' soft-deleted — removing it from `odk/registry.yaml` entirely. Unlike
#' [eri_odk_deregister()], which soft-deletes (`active: false`) and preserves the
#' sync history, this leaves no trace. Use it to clean up **practice / sandbox**
#' registrations (which otherwise linger as inactive rows in the shared registry);
#' for a real form prefer `eri_odk_deregister()`, which keeps the audit trail.
#'
#' @param project_id `int` ODK Central project ID.
#' @param form_id `str` ODK Central form ID (xmlFormId).
#' @param server_url `str` or `NULL` ODK Central server URL. If `NULL`, matches on
#'   `project_id` and `form_id` alone (removes every server's matching entry).
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns Invisibly, the number of entries removed.
#' @examples
#' \dontrun{
#' # Tear down a sandbox registration completely
#' eri_odk_purge(project_id = 99999, form_id = "eri_test_river_prospection")
#' }
#' @family ODK Central functions
#' @export
eri_odk_purge <- function(
    project_id,
    form_id,
    server_url = NULL,
    data_con   = NULL
) {
  data_con <- .odk_data_con(data_con)
  analyst  <- .eri_analyst_id(data_con)
  reg      <- .odk_registry_read(data_con)

  # Match active and inactive entries alike, so sandbox rows already
  # soft-deleted by eri_odk_deregister() are cleaned up too.
  match <- vapply(reg$forms, function(f) {
    identical(as.integer(f$project_id), as.integer(project_id)) &&
      identical(f$form_id, form_id) &&
      (is.null(server_url) || identical(f$server_url, server_url))
  }, logical(1L))

  if (sum(match) == 0L) {
    cli::cli_abort(c(
      "No registered form (active or inactive) found to purge.",
      "i" = "project_id: {.val {project_id}}",
      "i" = "form_id:    {.val {form_id}}"
    ))
  }

  # Concurrency-safe hard-delete (ADR-0002): re-match on the freshly-read registry
  # and report the count actually committed (not the possibly-stale pre-read).
  n <- 0L
  .eri_yaml_update(data_con, .ODK_REGISTRY_PATH, function(reg) {
    if (is.null(reg$forms)) reg$forms <- list()
    drop <- vapply(reg$forms, function(f) {
      identical(as.integer(f$project_id), as.integer(project_id)) &&
        identical(f$form_id, form_id) &&
        (is.null(server_url) || identical(f$server_url, server_url))
    }, logical(1L))
    n <<- sum(drop)
    reg$forms <- reg$forms[!drop]
    reg
  }, default = list(forms = list()))

  op_log <- list(
    operation  = "eri_odk_purge",
    analyst    = analyst,
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(
      project_id = as.integer(project_id),
      form_id    = form_id,
      server_url = server_url,
      n_removed  = n
    ),
    status = "success"
  )
  .eri_write_log(op_log, data_con, "logs/_access")

  cli::cli_alert_success(
    "Purged {n} registry entr{?y/ies} for {.val {form_id}} (project {project_id})."
  )
  invisible(n)
}

#### eri_odk_list_registered ####

#' List all actively registered ODK forms
#'
#' Returns a tibble of active entries from `odk/registry.yaml` in the `data/` blob.
#'
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects automatically.
#' @returns A tibble with columns: `server_url`, `project_id`, `form_id`,
#'   `form_display_name`, `country`, `disease`, `added_by`, `added_at`, `last_synced`.
#' @examples
#' \dontrun{
#' eri_odk_list_registered()
#' }
#' @family ODK Central functions
#' @export
eri_odk_list_registered <- function(data_con = NULL) {
  data_con <- .odk_data_con(data_con)
  reg      <- .odk_registry_read(data_con)

  active <- Filter(function(f) isTRUE(f$active), reg$forms)

  if (length(active) == 0L) {
    cli::cli_inform("No forms currently registered.")
    return(tibble::tibble(
      server_url        = character(),
      project_id        = integer(),
      form_id           = character(),
      form_display_name = character(),
      country           = character(),
      disease           = character(),
      added_by          = character(),
      added_at          = character(),
      last_synced       = character()
    ))
  }

  out <- tibble::tibble(
    server_url        = vapply(active, `[[`, character(1L), "server_url"),
    project_id        = vapply(active, function(f) as.integer(f$project_id), integer(1L)),
    form_id           = vapply(active, `[[`, character(1L), "form_id"),
    form_display_name = vapply(active, `[[`, character(1L), "form_display_name"),
    country           = vapply(active, `[[`, character(1L), "country"),
    disease           = vapply(active, `[[`, character(1L), "disease"),
    added_by          = vapply(active, `[[`, character(1L), "added_by"),
    added_at          = vapply(active, `[[`, character(1L), "added_at"),
    last_synced       = vapply(active, function(f) {
      if (is.null(f$last_synced)) NA_character_ else as.character(f$last_synced)
    }, character(1L))
  )

  cli::cli_inform("{nrow(out)} registered form{?s}.")
  out
}
