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

# Write registry list back to Azure.
#' @keywords internal
.odk_registry_write <- function(reg, data_con) {
  tmp <- tempfile(fileext = ".yaml")
  withr::defer(unlink(tmp))
  yaml::write_yaml(reg, tmp)
  dir_path <- dirname(.ODK_REGISTRY_PATH)
  .eri_create_azure_dir(data_con, dir_path)
  .eri_blob_write(data_con, tmp, .ODK_REGISTRY_PATH)
}

# Return the data/ blob container, either from the passed object or env vars.
#' @keywords internal
.odk_data_con <- function(data_con) {
  if (!is.null(data_con)) return(data_con)
  token <- AzureAuth::get_azure_token(
    resource  = "https://storage.azure.com/",
    tenant    = Sys.getenv("ERIFUNCTIONS_TENANT_ID"),
    app       = Sys.getenv("ERIFUNCTIONS_APP_ID"),
    auth_type = "authorization_code"
  )
  AzureStor::storage_container(
    AzureStor::storage_endpoint(Sys.getenv("ERIFUNCTIONS_RESOURCE_ENDPOINT"), token = token),
    Sys.getenv("ERIFUNCTIONS_DATA_STORAGE_NAME", unset = "data")
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
  analyst   <- .eri_analyst_id()
  reg       <- .odk_registry_read(data_con)

  # Duplicate check: active entry with same (server_url, project_id, form_id)
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

  reg$forms <- c(reg$forms, list(entry))
  .odk_registry_write(reg, data_con)

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
#' @export
eri_odk_deregister <- function(
    project_id,
    form_id,
    server_url = NULL,
    data_con   = NULL
) {
  data_con <- .odk_data_con(data_con)
  analyst  <- .eri_analyst_id()
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

  reg$forms[[idx]]$active <- FALSE
  .odk_registry_write(reg, data_con)

  deregistered <- reg$forms[[idx]]

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
