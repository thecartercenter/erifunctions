#### eri_odk_sync — analyst-triggered form download to Azure ####

#' Sync an ODK form's submissions to Azure
#'
#' Downloads all submissions for a registered ODK form and writes them as
#' Parquet file(s) into `data/{country}/{disease}/research/raw/` in the Azure
#' `data/` container — ODK is the **research** channel's collection format
#' (`format: odk`) under ADR-0012, not a `data_source` of its own. The measure
#' (`data_type`) is assigned later, when the analyst cleans the form into a final
#' dataset. Forms with **repeat groups** (most real forms) export multiple
#' tables -- the main submission table plus one child table per repeat group --
#' and each is written as its own Parquet (`{form_id}.parquet`,
#' `{form_id}-{repeat}.parquet`, ...); a flat form writes a single
#' `{form_id}.parquet`. The registry entry's `last_synced` timestamp is updated
#' on success.
#'
#' @param project_id `int` ODK Central project ID.
#' @param form_id `str` ODK Central form ID (xmlFormId).
#' @param con `odk_connection` or `NULL` ODK connection from [init_odk_connection()].
#'   If `NULL`, falls back to the `ODK_URL` and `ODK_TOKEN` environment variables.
#' @param data_con Azure container object for the `data/` blob. If `NULL`, connects
#'   automatically using `ERIFUNCTIONS_*` environment variables.
#' @param overwrite `lgl` Whether to overwrite an existing Parquet file in Azure.
#'   Defaults to `TRUE`.
#' @returns Invisibly, the downloaded tibble (single-table forms) or a named list
#'   of tibbles (forms with repeat groups); `invisible(NULL)` when zero
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
  .eri_log_session()
  data_con <- .odk_data_con(data_con)
  analyst  <- .eri_analyst_id()

  reg      <- .odk_registry_read(data_con)
  entry    <- .odk_sync_find_entry(reg, project_id, form_id)

  country  <- entry$country
  disease  <- entry$disease

  cli::cli_inform("Downloading submissions for {.val {form_id}} ({country}/{disease})...")

  tabs <- download_odk_form(
    con        = con,
    project_id = project_id,
    form_id    = form_id,
    data_con   = NULL,
    tables     = TRUE
  )
  main <- tabs[[1L]]

  if (nrow(main) == 0L) {
    cli::cli_warn(c(
      "No submissions found for {.val {form_id}}.",
      "i" = "Nothing written to Azure."
    ))
    return(invisible(NULL))
  }

  # ODK is the research channel's collection format (ADR-0012): submissions land
  # in the `research` source (format: odk), not the retired `odk` source token.
  # The measure is assigned later when the DA cleans the form into a final dataset.
  raw_dir    <- eri_data_path(country, disease, "research", "raw")
  blob_paths <- character(0)
  for (nm in names(tabs)) {
    bp <- paste0(raw_dir, "/", nm, ".parquet")
    eri_write(obj = tabs[[nm]], file_loc = bp, azure = TRUE, azcontainer = data_con)
    blob_paths <- c(blob_paths, bp)
  }

  .odk_sync_update_last_synced(reg, data_con, project_id, form_id)

  op_log <- list(
    operation  = "eri_odk_sync",
    analyst    = analyst,
    timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    parameters = list(
      project_id  = as.integer(project_id),
      form_id     = form_id,
      country     = country,
      disease     = disease,
      data_source = "research",
      format      = "odk",
      n_records   = nrow(main),
      n_tables    = length(tabs),
      blob_paths  = as.list(blob_paths)
    ),
    status = "success"
  )
  .eri_write_log(op_log, data_con, paste0(country, "/", disease, "/research/logs"))

  if (length(tabs) == 1L) {
    cli::cli_alert_success(
      "Synced {nrow(main)} record{?s} from {.val {form_id}} to {.path {blob_paths[[1L]]}}."
    )
  } else {
    n_repeats <- length(tabs) - 1L
    cli::cli_alert_success(
      "Synced {.val {form_id}}: {nrow(main)} submission{?s} + {n_repeats} repeat table{?s} to {.path {raw_dir}/}."
    )
  }

  invisible(if (length(tabs) == 1L) main else tabs)
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
