#Helper functions for interaction with ODK Central

# --- Internal helpers -------------------------------------------------------

#' Resolve url/auth from an odk_connection or explicit args
#' @keywords internal
.odk_creds <- function(con, url, auth) {
  creds <- if (!is.null(con)) {
    if (!inherits(con, "odk_connection"))
      cli::cli_abort("{.arg con} must be an {.cls odk_connection} object from {.fn init_odk_connection}.")
    list(url = con$url, auth = con$token)
  } else {
    list(url = url, auth = auth)
  }
  if (is.null(creds$auth) || is.na(creds$auth) || !nzchar(creds$auth))
    cli::cli_abort(c(
      "No ODK credentials resolved -- refusing to call the server.",
      "i" = "Pass {.arg con} from {.fn init_odk_connection}, or set the {.envvar ODK_URL}/{.envvar ODK_TOKEN} environment variables."
    ))
  creds
}

#' Check an httr response and return parsed content, or abort on HTTP error
#' @keywords internal
.odk_check_response <- function(resp, context = "ODK API request") {
  if (httr::http_error(resp))
    cli::cli_abort("{context} failed with HTTP {httr::status_code(resp)}.")
  httr::content(resp)
}

#' Percent-encode an ODK form ID for use as one URL path segment
#'
#' Accepts the raw ID (`"Edo/Ebonyi"`) or one the caller already encoded
#' (`"Edo%2FEbonyi"`): it decodes first, then encodes reserved characters, so
#' `/` becomes `%2F` either way and is never double-encoded. The ID is only
#' decoded when it already contains a `%xx` escape, so a bare `%` is kept. An ID
#' that genuinely contains a literal `%2F` cannot be addressed.
#' @keywords internal
.odk_enc_form_id <- function(form_id) {
  utils::URLencode(.odk_form_id_raw(form_id), reserved = TRUE)
}

#' Undo caller-side percent-encoding of an ODK form ID (only if it has `%xx`)
#' @keywords internal
.odk_form_id_raw <- function(form_id) {
  if (grepl("%[[:xdigit:]]{2}", form_id)) utils::URLdecode(form_id) else form_id
}

#' Name ODK Central gives a form's CSV inside a submissions export zip
#'
#' Central names export files with `sanitize-filename(xmlFormId)`, which drops
#' `/ ? < > \ : * | "` and control characters, and trailing dots/spaces. Mirror
#' that so the main CSV is found for form IDs containing those characters.
#' @keywords internal
.odk_export_name <- function(form_id) {
  x <- gsub(.odk_unsafe_chars, "", .odk_form_id_raw(form_id))
  sub("[. ]+$", "", x)
}

# --- Connection -------------------------------------------------------------

#' Initialize an ODK Central connection
#'
#' Authenticates with ODK Central and returns a connection object that can be
#' passed to other ODK functions via the `con` argument.  As a fallback for
#' backward compatibility, all ODK functions also accept credentials via the
#' `ODK_URL`, `ODK_USER`, and `ODK_PASS` environment variables.
#'
#' @param url `chr` ODK Central server URL
#' @param user `chr` Email address used to authenticate
#' @param pass `chr` Password
#' @return An `odk_connection` object (returned invisibly)
#' @export
init_odk_connection <- function(
    url  = Sys.getenv("ODK_URL",  unset = "https://rblf.tccodk.org/"),
    user = Sys.getenv("ODK_USER", unset = ""),
    pass = Sys.getenv("ODK_PASS", unset = "")
) {
  if (nchar(user) == 0)
    cli::cli_abort("ODK username is required. Set {.envvar ODK_USER} or pass {.arg user}.")
  if (nchar(pass) == 0)
    cli::cli_abort("ODK password is required. Set {.envvar ODK_PASS} or pass {.arg pass}.")

  resp <- httr::POST(
    url    = httr::modify_url(url, path = "v1/sessions"),
    body   = list(email = user, password = pass),
    encode = "json"
  )
  x <- .odk_check_response(resp, "ODK authentication")

  con <- structure(
    list(url = url, token = x$token, expires_at = x$expiresAt, created_at = x$createdAt),
    class = "odk_connection"
  )
  cli::cli_alert_success("Connected to {.url {url}}. Session expires {x$expiresAt}.")
  invisible(con)
}

#' @export
print.odk_connection <- function(x, ...) {
  cli::cli_inform(c(
    "i" = "ODK connection: {.url {x$url}}",
    "i" = "Expires: {x$expires_at}"
  ))
  invisible(x)
}

# --- Listing ----------------------------------------------------------------

#' List ODK projects
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @returns `tibble` with columns `project_id`, `project`, `description`
#' @family ODK Central functions
#' @export
list_odk_projects <- function(
    con  = NULL,
    url  = Sys.getenv("ODK_URL"),
    auth = Sys.getenv("ODK_TOKEN")
) {
  creds <- .odk_creds(con, url, auth)
  resp <- httr::GET(
    url    = httr::modify_url(creds$url, path = "v1/projects"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth), forms = "true")
  )
  x <- .odk_check_response(resp, "list_odk_projects()")
  if (length(x) == 0L)
    return(tibble::tibble(project_id = integer(), project = character(), description = character()))
  lapply(seq_along(x), function(i) {
    tibble::tibble(project_id = x[[i]]$id, project = x[[i]]$name, description = x[[i]]$description)
  }) |> dplyr::bind_rows()
}

#' List ODK forms within a project
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID from [list_odk_projects()]
#' @returns `tibble` with columns `xmlFormId`, `name`
#' @family ODK Central functions
#' @export
list_odk_forms <- function(
    con        = NULL,
    url        = Sys.getenv("ODK_URL"),
    auth       = Sys.getenv("ODK_TOKEN"),
    project_id
) {
  creds <- .odk_creds(con, url, auth)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
  )
  x <- .odk_check_response(resp, "list_odk_forms()")
  if (length(x) == 0L)
    return(tibble::tibble(xmlFormId = character(), name = character()))
  lapply(seq_along(x), function(i) {
    x[[i]] |> unlist() |> t() |> tibble::as_tibble()
  }) |> dplyr::bind_rows() |> dplyr::select("xmlFormId", "name")
}

#' Download all submissions from an ODK form
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID from [list_odk_projects()]
#' @param form_id `chr` Form ID from [list_odk_forms()]
#' @param attachments `lgl` Include attachment metadata columns
#' @param tables `lgl` If `TRUE`, return a **named list** of every table in the
#'   export -- the main submission table first, then one child table per repeat
#'   group (ODK Central exports each repeat as a separate CSV, linked to the
#'   parent by a `PARENT_KEY` column). Child tables follow in alphabetical order
#'   of their CSV name, not the form-defined order. If `FALSE` (default), return
#'   only the main submission table as a single tibble.
#' @param data_con Azure container for operation logging; `NULL` skips logging
#' @returns A `tibble` of submissions, or -- when `tables = TRUE` -- a named list
#'   of tibbles (one per export table, main table first).
#' @importFrom utils URLencode URLdecode unzip
#' @family ODK Central functions
#' @export
download_odk_form <- function(
    con         = NULL,
    url         = Sys.getenv("ODK_URL"),
    auth        = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id,
    attachments = FALSE,
    tables      = FALSE,
    data_con    = NULL
) {
  creds       <- .odk_creds(con, url, auth)
  enc_form_id <- .odk_enc_form_id(form_id)

  send_url <- if (attachments) {
    paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id, "/submissions.csv.zip")
  } else {
    paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id,
           "/submissions.csv.zip?attachments=false")
  }

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  withr::defer(unlink(tmp_dir, recursive = TRUE))
  tmp_zip <- file.path(tmp_dir, "submissions.csv.zip")

  resp <- httr::GET(
    url    = send_url,
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth)),
    httr::write_disk(tmp_zip, overwrite = TRUE)
  )
  .odk_check_response(resp, paste0("download_odk_form(", form_id, ")"))

  unzip(tmp_zip, exdir = tmp_dir)
  form_name <- URLdecode(enc_form_id)
  main_csv  <- file.path(tmp_dir, paste0(.odk_export_name(form_id), ".csv"))
  if (!file.exists(main_csv)) {
    found <- basename(list.files(tmp_dir, pattern = "\\.csv$"))
    cli::cli_abort(c(
      "Could not find the main table {.file {basename(main_csv)}} in the ODK export for {.val {form_name}}.",
      "i" = "Files in the export: {.file {found}}."
    ))
  }

  if (isTRUE(tables)) {
    csvs    <- list.files(tmp_dir, pattern = "\\.csv$", full.names = TRUE)
    is_main <- basename(csvs) == basename(main_csv)
    csvs    <- c(csvs[is_main], sort(csvs[!is_main]))   # main first, repeats after
    out     <- lapply(csvs, function(p)
      suppressWarnings(readr::read_csv(p, show_col_types = FALSE)))
    names(out) <- tools::file_path_sans_ext(basename(csvs))

    if (length(out) == 1L) {
      cli::cli_alert_info("Downloaded {nrow(out[[1L]])} record{?s} from {.val {form_name}}.")
    } else {
      cli::cli_alert_info("Downloaded {length(out)} tables from {.val {form_name}}:")
      for (nm in names(out)) {
        cli::cli_bullets(c("*" = "{.val {nm}}: {nrow(out[[nm]])} record{?s}"))
      }
    }
    main_n <- nrow(out[[1L]])
  } else {
    out    <- suppressWarnings(readr::read_csv(main_csv, show_col_types = FALSE))
    main_n <- nrow(out)
    cli::cli_alert_info("Downloaded {nrow(out)} record{?s} from {.val {form_name}}.")
  }

  if (!is.null(data_con)) {
    .eri_write_log(
      list(
        operation  = "download_odk_form",
        form_id    = form_id,
        project_id = project_id,
        n_records  = main_n,
        analyst    = .eri_analyst_id(data_con),
        timestamp  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      data_con,
      "logs/_access"
    )
  }

  out
}

#' List all app users in an ODK project
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID from [list_odk_projects()]
#' @returns `tibble` of app users
#' @family ODK Central functions
#' @export
list_all_odk_app_users <- function(
    con        = NULL,
    url        = Sys.getenv("ODK_URL"),
    auth       = Sys.getenv("ODK_TOKEN"),
    project_id
) {
  creds <- .odk_creds(con, url, auth)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/app-users/"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
  )
  x <- .odk_check_response(resp, "list_all_odk_app_users()")
  if (length(x) == 0L) return(tibble::tibble())
  lapply(seq_along(x), function(i) {
    x[[i]] |> unlist() |> t() |> tibble::as_tibble()
  }) |> dplyr::bind_rows()
}

#' List users assigned to an ODK form
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID from [list_odk_projects()]
#' @param form_id `chr` Form ID from [list_odk_forms()]
#' @returns `tibble` of assigned users and roles
#' @importFrom utils URLencode URLdecode
#' @export
list_odk_form_users <- function(
    con        = NULL,
    url        = Sys.getenv("ODK_URL"),
    auth       = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id
) {
  creds       <- .odk_creds(con, url, auth)
  enc_form_id <- .odk_enc_form_id(form_id)
  resp <- httr::GET(
    url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id, "/assignments"),
    config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
  )
  x <- .odk_check_response(resp, "list_odk_form_users()")
  if (length(x) == 0L) return(tibble::tibble())
  lapply(seq_along(x), function(i) {
    x[[i]] |> unlist() |> t() |> tibble::as_tibble()
  }) |> dplyr::bind_rows()
}

#' Create, delete, assign, or revoke an ODK app user role
#'
#' @param action `chr` One of `"create"`, `"delete"`, `"assign"`, `"revoke"`
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID
#' @param form_id `chr` Form ID; required for `"assign"` and `"revoke"`
#' @param actor_name `chr` Display name; required for `"create"`
#' @param role_id `int` Role ID; required for `"assign"` and `"revoke"`
#' @param actor_id `int` Actor ID; required for `"delete"`, `"assign"`, `"revoke"`
#' @returns Named list (for `"create"`) or logical (for all others)
#' @importFrom utils URLencode URLdecode
#' @family ODK Central functions
#' @export
update_odk_app_user_role <- function(
    action,
    con        = NULL,
    url        = Sys.getenv("ODK_URL"),
    auth       = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id    = NULL,
    actor_name = NULL,
    role_id    = NULL,
    actor_id   = NULL
) {
  if (!action %in% c("create", "delete", "assign", "revoke"))
    cli::cli_abort("{.arg action} must be one of {.val create}, {.val delete}, {.val assign}, or {.val revoke}.")
  if (action == "create" && is.null(actor_name))
    cli::cli_abort("{.arg actor_name} is required to create an app user.")
  if (action == "delete" && is.null(actor_id))
    cli::cli_abort("{.arg actor_id} is required to delete an app user.")
  if (action %in% c("assign", "revoke") && is.null(form_id))
    cli::cli_abort("{.arg form_id} is required to assign or revoke access.")
  if (action %in% c("assign", "revoke") && is.null(role_id))
    cli::cli_abort("{.arg role_id} is required to assign or revoke access.")
  if (action %in% c("assign", "revoke") && is.null(actor_id))
    cli::cli_abort("{.arg actor_id} is required to assign or revoke access.")

  creds <- .odk_creds(con, url, auth)

  if (action == "create") {
    x <- httr::POST(
      url    = paste0(creds$url, "v1/projects/", project_id, "/app-users"),
      config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth)),
      body   = list(displayName = actor_name),
      encode = "json"
    ) |> .odk_check_response("create app user")
    return(list(actor_name = x$displayName, actor_id = x$id, project_id = x$projectId))
  }

  if (action == "delete") {
    x <- httr::DELETE(
      url    = paste0(creds$url, "v1/projects/", project_id, "/app-users/", actor_id),
      config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
    ) |> .odk_check_response("delete app user")
    return(isTRUE(x$success))
  }

  enc_form_id <- .odk_enc_form_id(form_id)

  if (action == "assign") {
    x <- httr::POST(
      url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id,
                      "/assignments/", role_id, "/", actor_id),
      config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
    ) |> .odk_check_response("assign app user")
    return(isTRUE(x$success))
  }

  if (action == "revoke") {
    x <- httr::DELETE(
      url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id,
                      "/assignments/", role_id, "/", actor_id),
      config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
    ) |> .odk_check_response("revoke app user")
    return(isTRUE(x$success))
  }
}

#' Local file names for downloaded ODK attachments
#'
#' Stem from the label value (a trailing media extension such as `.jpg`
#' dropped; other dots, e.g. `3.5`, kept), extension from the attachment itself
#' (`jpeg` if it has none). The attachment's own stem is appended when its
#' submission has more than one attachment, or when the name would otherwise
#' repeat (compared case-insensitively, as Windows/macOS file systems do). Any
#' name still repeated gets a numeric suffix.
#' @param label `chr` the `image_label` value per attachment row
#' @param att_name `chr` the attachment's ODK file name
#' @param instance_id `chr` the submission each attachment belongs to, or `NULL`
#' @keywords internal
.odk_attachment_file_names <- function(label, att_name, instance_id = NULL) {
  att_stem <- .odk_safe_file_stem(tools::file_path_sans_ext(att_name))
  ext      <- tools::file_ext(att_name)
  ext[!nzchar(ext)] <- "jpeg"
  stem <- .odk_safe_file_stem(sub(.odk_media_ext, "", label, ignore.case = TRUE))
  missing_lab <- is.na(label) | !nzchar(trimws(stem))
  stem[missing_lab] <- att_stem[missing_lab]

  key   <- tolower(paste0(stem, ".", ext))
  multi <- if (is.null(instance_id)) FALSE
           else instance_id %in% instance_id[duplicated(instance_id)]
  add   <- !missing_lab & (multi | key %in% key[duplicated(key)])
  stem[add] <- paste0(stem[add], "_", att_stem[add])

  # Final case-insensitive uniqueness pass. Hashed sets plus a per-name counter
  # keep this linear even when many rows share both label and attachment name.
  out    <- paste0(stem, ".", ext)
  seen   <- new.env(hash = TRUE, parent = emptyenv())
  next_n <- new.env(hash = TRUE, parent = emptyenv())
  for (i in seq_along(out)) {
    base <- tolower(out[i])
    cand <- out[i]
    n    <- next_n[[base]] %||% 0L
    while (!is.null(seen[[tolower(cand)]])) {
      n    <- n + 1L
      cand <- paste0(stem[i], "_", n, ".", ext[i])
    }
    next_n[[base]]        <- n
    seen[[tolower(cand)]] <- TRUE
    out[i] <- cand
  }
  out
}

# Characters Windows rejects in file names (also what Central's
# sanitize-filename strips from export names).
.odk_unsafe_chars <- '[/?<>\\\\:*|"[:cntrl:]]'

# Trailing extensions treated as "already a file name" in an image_label value.
.odk_media_ext <- "\\.(jpe?g|png|gif|heic|webp|bmp|tiff?|mp4|3gp|mov|m4a|amr|mp3|wav|ogg|pdf)$"

#' Make a string safe as a file name stem on Windows
#' @keywords internal
.odk_safe_file_stem <- function(x) {
  x <- sub("[. ]+$", "", gsub(.odk_unsafe_chars, "_", x))
  # Windows reserves device names even with an extension (NUL.txt, con.5.jpg)
  reserved <- grepl("^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\\..*)?$", x, ignore.case = TRUE)
  x[reserved] <- paste0("_", x[reserved])
  x
}

#' Download all media attachments from an ODK form
#'
#' @param con An `odk_connection` from [init_odk_connection()], or `NULL` to use env vars
#' @param url `chr` Server URL (used when `con = NULL`)
#' @param auth `chr` Bearer token (used when `con = NULL`)
#' @param project_id `int` Project ID from [list_odk_projects()]
#' @param form_id `chr` Form ID from [list_odk_forms()], as shown there (an ID
#'   containing `/` is encoded for you)
#' @param folder_loc `chr` Local directory to write downloaded attachments
#' @param image_label `chr` Column whose value names each saved file. A media
#'   extension in the value (`.jpg`, `.png`, ...) is dropped and the
#'   attachment's own extension is used (`1234.jpg` is saved as `1234.jpg`).
#'   When one submission has several attachments, or two rows share a value
#'   (ignoring case), the attachment's ODK file name is appended so no file
#'   overwrites another. Rows with no value use the attachment's ODK file name.
#'   Use the returned `file_name` column to link files back to rows.
#' @param other_vars `chr` Additional columns to include in the returned tibble
#'   (default: none)
#' @param add_condition `lgl` Apply a row filter before downloading
#' @param condition Unquoted `dplyr::filter()` expression; used when `add_condition = TRUE`
#' @returns `tibble` of attachment metadata, with a `file_name` column giving
#'   the name each attachment was saved under in `folder_loc`
#' @importFrom rlang .data
#' @importFrom utils URLencode URLdecode
#' @family ODK Central functions
#' @export
download_form_attachments <- function(
    con           = NULL,
    url           = Sys.getenv("ODK_URL"),
    auth          = Sys.getenv("ODK_TOKEN"),
    project_id,
    form_id,
    folder_loc,
    image_label,
    other_vars    = character(),
    add_condition = FALSE,
    condition     = NULL
) {
  creds       <- .odk_creds(con, url, auth)
  enc_form_id <- .odk_enc_form_id(form_id)

  if (!dir.exists(folder_loc)) {
    cli::cli_process_start("Folder not found, creating {.path {folder_loc}}.")
    dir.create(folder_loc)
    cli::cli_process_done()
  }

  cli::cli_process_start("Downloading ODK form data")
  form_data <- download_odk_form(
    con = con, url = url, auth = auth,
    project_id = project_id, form_id = form_id
  ) |>
    dplyr::filter(.data$AttachmentsExpected != 0) |>
    dplyr::select(dplyr::all_of(image_label), dplyr::all_of(other_vars),
                  "meta-instanceID", "AttachmentsExpected", "AttachmentsPresent")
  cli::cli_process_done()

  if (add_condition) form_data <- dplyr::filter(form_data, {{ condition }})

  cli::cli_alert_info("Identified {nrow(form_data)} form{?s} with attachments.")

  cli::cli_process_start("Downloading form attachments list")
  attachments <- lapply(
    cli::cli_progress_along(seq_len(nrow(form_data)), "Downloading attachment list"),
    function(i) {
      instance_id <- dplyr::slice(form_data, i) |> dplyr::pull("meta-instanceID")
      resp <- httr::GET(
        url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id,
                        "/submissions/", instance_id, "/attachments"),
        config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
      )
      lst <- .odk_check_response(resp, "attachment list")
      if (length(lst) == 0L) return(tibble::tibble())
      lapply(seq_along(lst), function(j) {
        lst[[j]] |> unlist() |> t() |> tibble::as_tibble() |>
          dplyr::mutate(instance_id = instance_id)
      }) |> dplyr::bind_rows()
    }
  ) |> dplyr::bind_rows()
  cli::cli_process_done()

  download_dataset <- dplyr::left_join(
    attachments, form_data, by = c("instance_id" = "meta-instanceID")
  )
  cli::cli_alert_info("Identified {nrow(download_dataset)} attachment{?s} to download.")
  download_dataset$file_name <- if (nrow(download_dataset) > 0L) {
    .odk_attachment_file_names(
      as.character(download_dataset[[image_label]]), download_dataset$name,
      download_dataset$instance_id
    )
  } else character()

  lapply(
    cli::cli_progress_along(seq_len(nrow(download_dataset)), "Downloading attachments"),
    function(i) {
      row         <- dplyr::slice(download_dataset, i)
      instance_id <- dplyr::pull(row, "instance_id")
      filename    <- dplyr::pull(row, "name")
      resp <- httr::GET(
        url    = paste0(creds$url, "v1/projects/", project_id, "/forms/", enc_form_id,
                        "/submissions/", instance_id, "/attachments/",
                        utils::URLencode(filename, reserved = TRUE)),
        config = httr::add_headers(Authorization = paste0("Bearer ", creds$auth))
      )
      out_name <- file.path(folder_loc, dplyr::pull(row, "file_name"))
      fid <- file(out_name, "wb")
      writeBin(resp$content, fid)
      close(fid)
    }
  )

  cli::cli_alert_success("Attachments downloaded to {.path {folder_loc}}.")
  download_dataset
}
