#' Create an ERI-branded Excel workbook
#'
#' Initialises an [openxlsx2::wb_workbook()] pre-loaded with the Carter Center
#' brand colour set and a creator field. Use the returned object with
#' `eri_wb_add_sheet()` and `eri_wb_save()` to build up a workbook sheet by
#' sheet before writing to disk.
#'
#' @param title Character; workbook title stored in document properties.
#' @param author Character; author stored in document properties. Defaults to
#'   the current system user.
#'
#' @return An `openxlsx2` workbook object.
#' @export
#'
#' @examples
#' \dontrun{
#' wb <- eri_wb_create("Hispaniola Malaria 2024")
#' wb <- eri_wb_add_sheet(wb, "Summary", summary_df)
#' eri_wb_save(wb, "malaria_report.xlsx")
#' }
eri_wb_create <- function(title = NULL, author = Sys.info()[["user"]]) {
  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg openxlsx2} is required. Install with {.code install.packages('openxlsx2')}.")
  }
  wb <- openxlsx2::wb_workbook(
    creator = author,
    title   = title %||% ""
  )
  wb
}

#' Add a styled data sheet to an ERI workbook
#'
#' Writes a data frame to a new worksheet in the workbook using ERI branding:
#' bold navy header row, alternating body shading, Calibri font, frozen first
#' row, and auto-fitted column widths.
#'
#' @param wb An `openxlsx2` workbook object from [eri_wb_create()].
#' @param sheet_name Character; name of the new worksheet tab.
#' @param data A data frame or tibble to write.
#' @param title Optional character; written as a bold heading in row 1; data
#'   starts in row 2 when provided.
#'
#' @return The updated workbook object (invisibly).
#' @export
#'
#' @examples
#' \dontrun{
#' wb <- eri_wb_create("Report")
#' wb <- eri_wb_add_sheet(wb, "Cases", cases_df, title = "Malaria cases 2024")
#' }
eri_wb_add_sheet <- function(wb, sheet_name, data, title = NULL) {
  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg openxlsx2} is required.")
  }
  navy  <- "#44546A"
  strip <- "#E7E6E6"

  wb <- openxlsx2::wb_add_worksheet(wb, sheet = sheet_name)

  start_row <- 1L

  # Optional title row
  if (!is.null(title)) {
    wb <- openxlsx2::wb_add_data(wb, sheet = sheet_name, x = title,
                                  start_col = 1L, start_row = start_row)
    wb <- openxlsx2::wb_add_font(wb, sheet = sheet_name,
                                  dims = openxlsx2::wb_dims(start_row, 1L),
                                  bold = TRUE, size = 13, name = "Calibri",
                                  color = openxlsx2::wb_color(navy))
    start_row <- start_row + 1L
  }

  n_cols <- ncol(data)
  n_rows <- nrow(data)

  # Write data (with column headers)
  wb <- openxlsx2::wb_add_data(wb, sheet = sheet_name, x = data,
                                start_col = 1L, start_row = start_row,
                                col_names = TRUE)

  header_row <- start_row
  data_start <- start_row + 1L
  data_end   <- start_row + n_rows

  # Header style: navy fill, white bold Calibri
  header_dims <- openxlsx2::wb_dims(header_row, 1L:n_cols)
  wb <- openxlsx2::wb_add_fill(wb, sheet = sheet_name,
                                dims = header_dims, color = openxlsx2::wb_color(navy))
  wb <- openxlsx2::wb_add_font(wb, sheet = sheet_name,
                                dims = header_dims,
                                bold = TRUE, size = 11, name = "Calibri",
                                color = openxlsx2::wb_color("white"))

  # Body font
  if (n_rows > 0L) {
    body_dims <- openxlsx2::wb_dims(data_start:data_end, 1L:n_cols)
    wb <- openxlsx2::wb_add_font(wb, sheet = sheet_name,
                                  dims = body_dims, size = 10, name = "Calibri")

    # Alternating row shading (every other body row starting from row 2 of data)
    even_rows <- if (data_end >= data_start + 1L)
      seq(data_start + 1L, data_end, by = 2L)
    else
      integer(0L)
    if (length(even_rows) > 0L) {
      for (r in even_rows) {
        wb <- openxlsx2::wb_add_fill(wb, sheet = sheet_name,
                                      dims = openxlsx2::wb_dims(r, 1L:n_cols),
                                      color = openxlsx2::wb_color(strip))
      }
    }
  }

  # Outer border
  all_dims <- openxlsx2::wb_dims(header_row:(if (n_rows > 0L) data_end else header_row),
                                  1L:n_cols)
  wb <- openxlsx2::wb_add_border(wb, sheet = sheet_name, dims = all_dims,
                                  inner_hgrid = "thin",
                                  inner_hcolor = openxlsx2::wb_color("grey80"),
                                  outer_border = "thin",
                                  outer_color  = openxlsx2::wb_color(navy))

  # Freeze header
  wb <- openxlsx2::wb_freeze_pane(wb, sheet = sheet_name,
                                   first_active_row = start_row + 1L)

  # Auto-fit columns
  wb <- openxlsx2::wb_set_col_widths(wb, sheet = sheet_name,
                                      cols = 1L:n_cols, widths = "auto")

  invisible(wb)
}

#' Save an ERI workbook to disk
#'
#' Writes the workbook to a `.xlsx` file. Creates parent directories if needed.
#'
#' @param wb An `openxlsx2` workbook object.
#' @param path Character; output file path (should end in `.xlsx`).
#' @param overwrite Logical; overwrite an existing file (default `TRUE`).
#'
#' @return `path` invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_wb_save(wb, "outputs/malaria_report.xlsx")
#' }
eri_wb_save <- function(wb, path, overwrite = TRUE) {
  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg openxlsx2} is required.")
  }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  openxlsx2::wb_save(wb, file = path, overwrite = overwrite)
  cli::cli_alert_success("Workbook saved to {.path {path}}")
  invisible(path)
}

#' Write a multi-sheet ERI-branded Excel report
#'
#' Convenience wrapper around [eri_wb_create()], [eri_wb_add_sheet()], and
#' [eri_wb_save()]. Accepts a named list of data frames and writes each as a
#' separate worksheet in a single `.xlsx` file.
#'
#' @param sheets Named list of data frames; each element becomes one
#'   worksheet. Names are used as sheet tab labels.
#' @param path Character; output file path (should end in `.xlsx`).
#' @param title Optional character; stored as workbook title in document
#'   properties.
#' @param author Optional character; stored as author in document properties.
#'   Defaults to the current system user.
#' @param overwrite Logical; overwrite an existing file (default `TRUE`).
#'
#' @return `path` invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' eri_report_excel(
#'   sheets   = list("Summary" = summary_df, "Cases" = case_df),
#'   path     = "outputs/malaria_report.xlsx",
#'   title    = "Hispaniola Malaria 2024"
#' )
#' }
eri_report_excel <- function(sheets,
                              path,
                              title    = NULL,
                              author   = Sys.info()[["user"]],
                              overwrite = TRUE) {
  if (length(sheets) == 0L) {
    cli::cli_abort("{.arg sheets} must contain at least one data frame.")
  }
  if (!is.list(sheets) || is.null(names(sheets)) || any(names(sheets) == "")) {
    cli::cli_abort("{.arg sheets} must be a named list of data frames.")
  }

  wb <- eri_wb_create(title = title, author = author)
  for (nm in names(sheets)) {
    df <- sheets[[nm]]
    if (!is.data.frame(df)) {
      cli::cli_abort("Element {.val {nm}} in {.arg sheets} is not a data frame.")
    }
    wb <- eri_wb_add_sheet(wb, sheet_name = nm, data = df)
  }
  eri_wb_save(wb, path = path, overwrite = overwrite)
}
