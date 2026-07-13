#### Bulk ODK app-user management ####

# ODK Central role ID for form-level data collection (App User role)
.ODK_APP_USER_ROLE_ID <- 2L

# Fetch and cache app-user lists per project; returns named list keyed by project_id.
#' @keywords internal
.odk_bulk_fetch_users <- function(project_ids, creds) {
  users <- list()
  for (pid in unique(project_ids)) {
    key <- as.character(pid)
    users[[key]] <- tryCatch(
      list_all_odk_app_users(url = creds$url, auth = creds$auth, project_id = pid),
      error = function(e) tibble::tibble()
    )
  }
  users
}

# Fetch and cache form lists per project; returns named list keyed by project_id.
#' @keywords internal
.odk_bulk_fetch_forms <- function(project_ids, creds) {
  forms <- list()
  for (pid in unique(project_ids)) {
    key <- as.character(pid)
    forms[[key]] <- tryCatch(
      list_odk_forms(url = creds$url, auth = creds$auth, project_id = pid),
      error = function(e) tibble::tibble(xmlFormId = character(), name = character())
    )
  }
  forms
}

# Run all pre-flight checks. Returns character vector of error strings (empty = OK).
#' @keywords internal
.odk_bulk_preflight <- function(csv, forms_cache) {
  errors <- character(0)
  valid_actions <- c("assign", "remove", "create")

  for (i in seq_len(nrow(csv))) {
    row <- csv[i, ]

    if (!row$action %in% valid_actions) {
      errors <- c(errors, sprintf(
        "Row %d: invalid action %s (must be assign, remove, or create)", i, row$action
      ))
    }

    key     <- as.character(row$project_id)
    forms   <- forms_cache[[key]]
    if (!is.null(forms) && nrow(forms) > 0) {
      if (!row$form_id %in% forms$xmlFormId) {
        errors <- c(errors, sprintf(
          "Row %d: form_id '%s' not found in project %s", i, row$form_id, row$project_id
        ))
      }
    }
  }

  # Conflicting actions: same (project_id, form_id, actor_name) with different actions
  key3 <- paste(csv$project_id, csv$form_id, csv$actor_name, sep = "|")
  for (k in unique(key3)) {
    idx <- which(key3 == k)
    if (length(unique(csv$action[idx])) > 1) {
      errors <- c(errors, sprintf(
        "Rows %s: conflicting actions for the same user/form combination",
        paste(idx, collapse = ", ")
      ))
    }
  }

  errors
}

#### eri_odk_bulk_users ####

#' Manage ODK app users in bulk from a validated CSV
#'
#' Reads a CSV of user/form actions, runs pre-flight validation against the live
#' ODK server, then executes all actions. All validation errors are collected and
#' reported together before any API calls are made.
#'
#' @param csv_path `chr` Path to a CSV file with columns
#'   `project_id`, `form_id`, `action`, `actor_name`.
#'   Supported actions: `"assign"`, `"remove"`, `"create"`.
#' @param con `odk_connection` or `NULL` ODK connection from [init_odk_connection()].
#'   Falls back to `ODK_URL` / `ODK_TOKEN` environment variables.
#' @param dry_run `lgl` If `TRUE`, run pre-flight only and print what would happen.
#'   No API mutation calls are made.
#' @returns A tibble with one row per input row and a `result` column (invisibly).
#'   In `dry_run` mode returns `invisible(NULL)`.
#' @details
#' For `"assign"` rows: if the named app user does not yet exist in the project,
#' they are created automatically before the form assignment is made.
#' The assignment uses ODK Central role ID 2 (App User / data collection role).
#'
#' For `"remove"` rows: the form assignment is revoked using role ID 2.
#' The app-user account itself is not deleted.
#'
#' @examples
#' \dontrun{
#' # CSV contents:
#' # project_id,form_id,action,actor_name
#' # 7,RiverProspection,assign,Jane Fieldworker
#' # 7,FlyCollection,remove,Jane Fieldworker
#'
#' eri_odk_bulk_users("users.csv", dry_run = TRUE)
#' eri_odk_bulk_users("users.csv")
#' }
#' @family ODK Central functions
#' @export
eri_odk_bulk_users <- function(csv_path, con = NULL, dry_run = FALSE) {
  if (!file.exists(csv_path))
    cli::cli_abort("CSV file not found: {.path {csv_path}}")

  csv <- readr::read_csv(csv_path, show_col_types = FALSE)

  required_cols <- c("project_id", "form_id", "action", "actor_name")
  missing_cols  <- setdiff(required_cols, names(csv))
  if (length(missing_cols) > 0)
    cli::cli_abort(c(
      "CSV is missing required columns.",
      "x" = "Missing: {.val {missing_cols}}",
      "i" = "Required: {.val {required_cols}}"
    ))

  creds <- .odk_creds(con,
                      url  = Sys.getenv("ODK_URL"),
                      auth = Sys.getenv("ODK_TOKEN"))

  cli::cli_inform("Fetching project/form metadata for pre-flight...")
  forms_cache <- .odk_bulk_fetch_forms(csv$project_id, creds)
  users_cache <- .odk_bulk_fetch_users(csv$project_id, creds)

  errors <- .odk_bulk_preflight(csv, forms_cache)

  if (length(errors) > 0) {
    msg <- c("Pre-flight validation failed.", stats::setNames(errors, rep("x", length(errors))))
    cli::cli_abort(msg)
  }

  cli::cli_alert_success("Pre-flight passed. {nrow(csv)} row{?s} to process.")

  if (dry_run) {
    cli::cli_inform(c("i" = "Dry run -- no changes will be made."))
    for (i in seq_len(nrow(csv))) {
      row <- csv[i, ]
      cli::cli_inform(
        "  [{i}] {row$action} {.val {row$actor_name}} on {row$form_id} (project {row$project_id})"
      )
    }
    return(invisible(NULL))
  }

  results <- vector("character", nrow(csv))

  for (i in cli::cli_progress_along(seq_len(nrow(csv)), "Processing user actions")) {
    row <- csv[i, ]
    pid <- as.integer(row$project_id)
    key <- as.character(pid)

    result <- tryCatch({
      if (row$action == "create") {
        update_odk_app_user_role(
          action     = "create",
          url        = creds$url,
          auth       = creds$auth,
          project_id = pid,
          actor_name = row$actor_name
        )
        users_cache[[key]] <- list_all_odk_app_users(
          url = creds$url, auth = creds$auth, project_id = pid
        )
        "created"
      } else {
        actor_id <- .odk_bulk_resolve_actor(
          row$actor_name, pid, creds, users_cache
        )
        # Refresh cache if actor was just created
        if (is.null(actor_id)) {
          update_odk_app_user_role(
            action     = "create",
            url        = creds$url,
            auth       = creds$auth,
            project_id = pid,
            actor_name = row$actor_name
          )
          users_cache[[key]] <- list_all_odk_app_users(
            url = creds$url, auth = creds$auth, project_id = pid
          )
          actor_id <- .odk_bulk_resolve_actor(
            row$actor_name, pid, creds, users_cache
          )
        }

        api_action <- if (row$action == "assign") "assign" else "revoke"
        update_odk_app_user_role(
          action     = api_action,
          url        = creds$url,
          auth       = creds$auth,
          project_id = pid,
          form_id    = row$form_id,
          role_id    = .ODK_APP_USER_ROLE_ID,
          actor_id   = actor_id
        )
        row$action
      }
    }, error = function(e) {
      paste0("error: ", conditionMessage(e))
    })

    results[i] <- result
  }

  out <- dplyr::mutate(csv, result = results)

  n_ok  <- sum(!grepl("^error:", results))
  n_err <- sum(grepl("^error:", results))
  if (n_err > 0) {
    cli::cli_warn("{n_err} row{?s} failed. Check the {.field result} column.")
  } else {
    cli::cli_alert_success("All {n_ok} action{?s} completed successfully.")
  }

  invisible(out)
}

# Look up actor_id from displayName in the cached user list.
# Returns NULL if not found (caller handles auto-create).
#' @keywords internal
.odk_bulk_resolve_actor <- function(actor_name, project_id, creds, users_cache) {
  key   <- as.character(project_id)
  users <- users_cache[[key]]
  if (is.null(users) || nrow(users) == 0L) return(NULL)
  if (!"displayName" %in% names(users)) return(NULL)
  match_row <- users[users$displayName == actor_name, ]
  if (nrow(match_row) == 0L) return(NULL)
  as.integer(match_row$id[[1]])
}
