# ODK survey status - submission metrics per form

#### Private helpers ####

#' Fetch metadata for a single ODK form
#' @param creds Named list with `url` and `auth` from `.odk_creds()`.
#' @param project_id Integer project ID.
#' @param form_id Character form ID.
#' @return Parsed list of form metadata.
#' @keywords internal
.odk_form_meta <- function(creds, project_id, form_id) {
  form_id_enc <- utils::URLencode(form_id, reserved = TRUE)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", form_id_enc),
    config = httr::add_headers(Authorization = paste("Bearer", creds$auth))
  )
  .odk_check_response(resp, paste0("form metadata for ", form_id))
}

#' Fetch submission list for a single ODK form
#' @param creds Named list with `url` and `auth` from `.odk_creds()`.
#' @param project_id Integer project ID.
#' @param form_id Character form ID.
#' @return List of submission objects.
#' @keywords internal
.odk_form_submissions <- function(creds, project_id, form_id) {
  form_id_enc <- utils::URLencode(form_id, reserved = TRUE)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", form_id_enc, "/submissions"),
    config = httr::add_headers(Authorization = paste("Bearer", creds$auth))
  )
  .odk_check_response(resp, paste0("submissions for ", form_id))
}

#' Build one row of survey_status for a known project + form
#' @param creds Named list with `url` and `auth` from `.odk_creds()`.
#' @param project_id Integer project ID.
#' @param project_name Character project display name.
#' @param form_id Character form ID.
#' @keywords internal
.odk_survey_status_row <- function(creds, project_id, project_name, form_id) {
  meta <- .odk_form_meta(creds, project_id, form_id)

  state    <- meta$state
  status   <- if (!is.null(state) && (identical(state, "closing") || identical(state, "closed"))) "closed" else "open"
  form_name <- if (!is.null(meta$name)) meta$name else if (!is.null(meta$xmlFormId)) meta$xmlFormId else form_id
  total     <- as.integer(if (!is.null(meta$submissions)) meta$submissions else 0L)
  last_sub  <- if (!is.null(meta$lastSubmission)) as.character(meta$lastSubmission) else NA_character_

  subs <- .odk_form_submissions(creds, project_id, form_id)

  now      <- Sys.time()
  cutoff7  <- now - 7  * 24 * 3600
  cutoff30 <- now - 30 * 24 * 3600

  sub_dates <- vapply(subs, function(s) {
    d <- s$createdAt
    if (is.null(d) || is.na(d)) NA_character_ else as.character(d)
  }, character(1L))

  parsed_dates <- suppressWarnings(
    as.POSIXct(sub_dates, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  )

  subs_7d  <- as.integer(sum(!is.na(parsed_dates) & parsed_dates >= cutoff7))
  subs_30d <- as.integer(sum(!is.na(parsed_dates) & parsed_dates >= cutoff30))

  tibble::tibble(
    project_id         = as.integer(project_id),
    project_name       = as.character(project_name),
    form_id            = as.character(form_id),
    form_name          = as.character(form_name),
    server_url         = as.character(creds$url),
    status             = as.character(status),
    total_submissions  = as.integer(total),
    last_submission_at = as.character(last_sub),
    submissions_7d     = as.integer(subs_7d),
    submissions_30d    = as.integer(subs_30d)
  )
}

#### Public functions ####

#' ODK form submission metrics
#'
#' Returns submission counts and status metadata for one or more ODK Central
#' forms. The scope is determined by the combination of `project_id` and
#' `form_id` supplied:
#'
#' - Both `NULL`: all forms across every project visible to the connection.
#' - `project_id` only: all forms within that project.
#' - Both supplied: a single form.
#'
#' Submission counts for the 7-day and 30-day windows are derived by fetching
#' the full submission list and filtering by `createdAt`.
#'
#' @param project_id `int` ODK project ID, or `NULL` for all projects.
#' @param form_id `chr` ODK form ID, or `NULL` for all forms in the project.
#' @param con An `odk_connection` object from [init_odk_connection()], or `NULL`
#'   to fall back to the `ODK_URL` and `ODK_TOKEN` environment variables.
#'
#' @return An S3 object of class `c("survey_status", "tbl_df", "tbl", "data.frame")`
#'   with the following columns:
#'   \describe{
#'     \item{project_id}{`int` ODK project ID.}
#'     \item{project_name}{`chr` ODK project display name.}
#'     \item{form_id}{`chr` ODK form ID.}
#'     \item{form_name}{`chr` ODK form display name.}
#'     \item{server_url}{`chr` ODK server URL.}
#'     \item{status}{`chr` `"open"` or `"closed"`.}
#'     \item{total_submissions}{`int` All-time submission count.}
#'     \item{last_submission_at}{`chr` ISO 8601 datetime of most recent submission, or `NA`.}
#'     \item{submissions_7d}{`int` Submissions in the last 7 days.}
#'     \item{submissions_30d}{`int` Submissions in the last 30 days.}
#'   }
#' @export
eri_survey_status <- function(project_id = NULL, form_id = NULL, con = NULL) {
  url  <- Sys.getenv("ODK_URL",   unset = "")
  auth <- Sys.getenv("ODK_TOKEN", unset = "")
  creds <- .odk_creds(con, url, auth)

  if (!is.null(project_id) && !is.null(form_id)) {
    resp <- httr::GET(
      url    = paste0(creds$url, "v1/projects/", project_id),
      config = httr::add_headers(Authorization = paste("Bearer", creds$auth))
    )
    proj_meta    <- .odk_check_response(resp, paste0("project metadata for ", project_id))
    project_name <- if (!is.null(proj_meta$name)) proj_meta$name else as.character(project_id)

    rows <- .odk_survey_status_row(creds, project_id, project_name, form_id)

  } else if (!is.null(project_id)) {
    resp <- httr::GET(
      url    = paste0(creds$url, "v1/projects/", project_id),
      config = httr::add_headers(Authorization = paste("Bearer", creds$auth))
    )
    proj_meta    <- .odk_check_response(resp, paste0("project metadata for ", project_id))
    project_name <- if (!is.null(proj_meta$name)) proj_meta$name else as.character(project_id)

    forms <- list_odk_forms(con = con, url = url, auth = auth, project_id = project_id)

    rows <- lapply(forms$xmlFormId, function(fid) {
      .odk_survey_status_row(creds, project_id, project_name, fid)
    }) |> dplyr::bind_rows()

  } else {
    projects <- list_odk_projects(con = con, url = url, auth = auth)

    rows <- lapply(seq_len(nrow(projects)), function(i) {
      pid   <- projects$project_id[[i]]
      pname <- projects$project[[i]]

      forms <- list_odk_forms(con = con, url = url, auth = auth, project_id = pid)

      lapply(forms$xmlFormId, function(fid) {
        .odk_survey_status_row(creds, pid, pname, fid)
      }) |> dplyr::bind_rows()
    }) |> dplyr::bind_rows()
  }

  structure(rows, class = c("survey_status", class(rows)))
}

#' Print method for survey_status objects
#'
#' Renders a one-line-per-form summary using `cli`.
#'
#' @param x A `survey_status` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @exportS3Method
print.survey_status <- function(x, ...) {
  n <- nrow(x)
  cli::cli_h1("Survey Status ({n} form{?s})")

  for (i in seq_len(n)) {
    row      <- x[i, ]
    status   <- row$status
    last_sub <- if (is.na(row$last_submission_at)) "no submissions" else row$last_submission_at

    cli::cli_bullets(c(
      "*" = "{.strong {row$form_id}} [{status}] - {row$total_submissions} total, last: {last_sub}"
    ))
  }

  invisible(x)
}
