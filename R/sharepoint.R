#' Connect to a SharePoint site
#'
#' Returns a SharePoint site object for use with [eri_sharepoint_list()],
#' [eri_sharepoint_read()], and `eri_sharepoint_upload()`. Authentication
#' uses browser-based interactive login via `Microsoft365R` -- consistent with
#' the rest of the package's Azure auth pattern. The token is cached by
#' `AzureAuth` so subsequent calls within a session do not re-prompt.
#'
#' @param site_url `chr` Full URL of the SharePoint site
#'   (e.g. `"https://cartercenter.sharepoint.com/sites/ERI"`).
#'
#' @return A `ms_site` object from `Microsoft365R`.
#' @export
#'
#' @examples
#' \dontrun{
#' site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
#' }
eri_sharepoint_connect <- function(site_url) {
  if (!requireNamespace("Microsoft365R", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg Microsoft365R} is required. Install with {.code install.packages('Microsoft365R')}."
    )
  }
  tryCatch(
    Microsoft365R::get_sharepoint_site(site_url),
    error = function(e) {
      cli::cli_abort(
        c("Could not connect to SharePoint site {.url {site_url}}.",
          "i" = "{e$message}"),
        call = NULL
      )
    }
  )
}

#' List files in a SharePoint document library folder
#'
#' Returns a tibble of files and folders at the specified path within the
#' site's default document library.
#'
#' @param site A `ms_site` object from [eri_sharepoint_connect()].
#' @param folder_path `chr` Folder path within the document library
#'   (e.g. `"Shared Documents/Malaria/2024"`). Defaults to `"/"` (root).
#'
#' @return A tibble with columns `name`, `size` (bytes), `modified`
#'   (`POSIXct`), `is_folder` (logical), and `path`.
#' @export
#'
#' @examples
#' \dontrun{
#' site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
#' eri_sharepoint_list(site, "Shared Documents/Malaria/2024")
#' }
eri_sharepoint_list <- function(site, folder_path = "/") {
  if (!requireNamespace("Microsoft365R", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg Microsoft365R} is required. Install with {.code install.packages('Microsoft365R')}."
    )
  }

  drive <- tryCatch(
    site$get_drive(),
    error = function(e) {
      cli::cli_abort("Could not access the document library: {e$message}", call = NULL)
    }
  )

  folder <- tryCatch(
    if (folder_path == "/" || !nzchar(folder_path)) {
      drive$get_root()
    } else {
      drive$get_item(folder_path)
    },
    error = function(e) {
      cli::cli_abort("Folder not found: {.path {folder_path}} ({e$message})", call = NULL)
    }
  )

  items <- tryCatch(
    folder$list_items(),
    error = function(e) {
      cli::cli_abort("Could not list items in {.path {folder_path}}: {e$message}", call = NULL)
    }
  )

  if (length(items) == 0L) {
    return(tibble::tibble(
      name      = character(),
      size      = integer(),
      modified  = as.POSIXct(character()),
      is_folder = logical(),
      path      = character()
    ))
  }

  tibble::tibble(
    name      = vapply(items, function(x) x$properties$name %||% NA_character_, character(1L)),
    size      = vapply(items, function(x) {
      sz <- x$properties$size
      if (is.null(sz)) NA_integer_ else as.integer(sz)
    }, integer(1L)),
    modified  = as.POSIXct(vapply(items, function(x) {
      x$properties$lastModifiedDateTime %||% NA_character_
    }, character(1L)), format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"),
    is_folder = vapply(items, function(x) {
      !is.null(x$properties$folder)
    }, logical(1L)),
    path      = file.path(folder_path, vapply(items, function(x) {
      x$properties$name %||% ""
    }, character(1L)))
  )
}

#' Read a file from SharePoint into R
#'
#' Downloads a file from a SharePoint document library to a temporary location
#' and reads it into R. The format is detected from the file extension:
#' - `.xlsx` / `.xls` -- `readxl::read_excel()`
#' - `.csv` -- `readr::read_csv()`
#' - `.parquet` -- `arrow::read_parquet()`
#' - `.rds` -- `readr::read_rds()`
#' - Other -- returns the local temp path as a character string
#'
#' @param site A `ms_site` object from [eri_sharepoint_connect()].
#' @param file_path `chr` Path to the file within the document library
#'   (e.g. `"Shared Documents/Malaria/2024/ht_weekly.xlsx"`).
#' @param ... Additional arguments passed to the underlying read function
#'   (e.g. `sheet` for Excel files).
#'
#' @return A tibble, data frame, or character path depending on file type.
#' @export
#'
#' @examples
#' \dontrun{
#' site <- eri_sharepoint_connect("https://cartercenter.sharepoint.com/sites/ERI")
#' df <- eri_sharepoint_read(site, "Shared Documents/Malaria/2024/ht_weekly.xlsx")
#' }
eri_sharepoint_read <- function(site, file_path, ...) {
  if (!requireNamespace("Microsoft365R", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg Microsoft365R} is required. Install with {.code install.packages('Microsoft365R')}."
    )
  }

  drive <- tryCatch(
    site$get_drive(),
    error = function(e) {
      cli::cli_abort("Could not access the document library: {e$message}", call = NULL)
    }
  )

  item <- tryCatch(
    drive$get_item(file_path),
    error = function(e) {
      cli::cli_abort("File not found: {.path {file_path}} ({e$message})", call = NULL)
    }
  )

  ext     <- tolower(tools::file_ext(file_path))
  tmp     <- tempfile(fileext = paste0(".", ext))
  withr::defer(unlink(tmp))

  tryCatch(
    item$download(tmp, overwrite = TRUE),
    error = function(e) {
      cli::cli_abort("Download failed for {.path {file_path}}: {e$message}", call = NULL)
    }
  )

  cli::cli_alert_success("Downloaded {.path {basename(file_path)}} from SharePoint.")

  switch(ext,
    xlsx = , xls = {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        cli::cli_abort("Package {.pkg readxl} is required to read Excel files.")
      }
      readxl::read_excel(tmp, ...)
    },
    csv = readr::read_csv(tmp, show_col_types = FALSE, ...),
    parquet = {
      if (!requireNamespace("arrow", quietly = TRUE)) {
        cli::cli_abort("Package {.pkg arrow} is required to read parquet files.")
      }
      arrow::read_parquet(tmp, ...)
    },
    rds = readr::read_rds(tmp, ...),
    {
      cli::cli_alert_info(
        "Unknown extension {.val {ext}} -- returning local temp path. Read manually."
      )
      tmp
    }
  )
}

