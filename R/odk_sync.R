#### eri_odk_sync — analyst-triggered form download to Azure ####

#' Sync an ODK form's submissions to Azure
#'
#' Downloads all submissions for a registered ODK form and writes them as a
#' Parquet file to `data/{country}/{disease}/odk/raw/{form_id}.parquet` in the
#' Azure `data/` container.  The registry entry's `last_synced` timestamp is
#' updated on success.
#'
#' @param project_id `int` ODK Central project ID.
#' @param form_id `str` ODK Central form ID (xmlFormId).
#' @param con `odk_connection` or `NULL` ODK connection from [init_odk_connection()].
#'   If `NULL`, falls back to the `ODK_URL` and `ODK_TOKEN` environment variables.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects
#'   automatically using `ERIFUNCTIONS_*` environment variables.
#' @param overwrite `lgl` Whether to overwrite an existing Parquet file in Azure.
#'   Defaults to `TRUE`.
#' @returns The downloaded tibble (invisibly), or `invisible(NULL)` when zero
#'   submissions are found.
#' @examples
#' \dontrun{
#' con      <- init_odk_connection()
#' data_con <- get_azure_storage_connection()
#' eri_odk_sync(project_id = 7, form_id = "RiverProspection",
#'              con = con, data_con = data_con)
#' }
#' @export
eri_odk_sync <- function(
    project_id,
    form_id,
    con      = NULL,
    data_con = NULL,
    overwrite = TRUE
) {
  data_con <- .odk_data_con(data_con)
  analyst  <- Sys.getenv("ERI_ANALYST_ID", unset = Sys.info()[["user"]])

  reg      <- .odk_registry_read(data_con)
  entry    <- .odk_sync_find_entry(reg, project_id, form_id)

  country  <- entry$country
  disease  <- entry$disease

  cli::cli_inform("Downloading submissions for {.val {form_id}} ({country}/{disease})...")

  submissions <- download_odk_form(
    con        = con,
    project_id = project_id,
    form_id    = form_id,
    data_con   = NULL
  )

  if (nrow(submissions) == 0L) {
    cli::cli_warn(c(
      "No submissions found for {.val {form_id}}.",
      "i" = "Nothing written to Azure."
    ))
    return(invisible(NULL))
  }

  blob_path <- paste0(country, "/", disease, "/odk/raw/", form_id, ".parquet")

  eri_write(
    obj         = submissions,
    file_loc    = blob_path,
    azure       = TRUE,
    azcontainer = data_con
  )

  .odk_sync_update_last_synced(reg, data_con, project_id, form_id)

  op_log <- list(
    operation  = "eri_odk_sync",
    analyst    = analyst,
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(
      project_id = as.integer(project_id),
      form_id    = form_id,
      country    = country,
      disease    = disease,
      n_records  = nrow(submissions),
      blob_path  = blob_path
    ),
    status = "success"
  )
  .eri_write_log(op_log, data_con, paste0(country, "/", disease, "/odk/logs"))

  cli::cli_alert_success(
    "Synced {nrow(submissions)} record{?s} from {.val {form_id}} to {.path {blob_path}}."
  )

  invisible(submissions)
}

# Find a single active registry entry matching project_id + form_id.
# Aborts with a hint to call eri_odk_register() if not found.
#' @keywords internal
.odk_sync_find_entry <- function(reg, project_id, form_id) {
  matches <- Filter(function(f) {
    isTRUE(f$active) &&
      identical(as.integer(f$project_id), as.integer(project_id)) &&
      identical(f$form_id, form_id)
  }, reg$forms)

  if (length(matches) == 0L) {
    cli::cli_abort(c(
      "Form {.val {form_id}} (project {project_id}) is not in the ODK registry.",
      "i" = "Register it first with {.fn eri_odk_register}."
    ))
  }

  matches[[1L]]
}

# Update last_synced for the matching entry and persist the registry.
#' @keywords internal
.odk_sync_update_last_synced <- function(reg, data_con, project_id, form_id) {
  idx <- which(vapply(reg$forms, function(f) {
    isTRUE(f$active) &&
      identical(as.integer(f$project_id), as.integer(project_id)) &&
      identical(f$form_id, form_id)
  }, logical(1L)))

  if (length(idx) == 0L) return(invisible(NULL))

  reg$forms[[idx[1L]]]$last_synced <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  .odk_registry_write(reg, data_con)
  invisible(NULL)
}
